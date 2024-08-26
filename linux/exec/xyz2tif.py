#!/usr/bin/env python

from pathlib import Path
from typing import Any, Literal, Tuple

import numpy as np
import pandas as pd
import rasterio as rio
from numpy.typing import NDArray
from scipy.ndimage import binary_erosion, binary_fill_holes

from typer import run


def get_valid_data_mask(
    arr: NDArray[Any],
    nodata_value: int | float = np.nan,
    erode_pixels: int = 0,
    erode_ignores_holes: bool = False,
    fill_holes: bool = False,
) -> NDArray[np.bool_]:
    mask = ~np.isnan(arr) if np.isnan(nodata_value) else arr != nodata_value

    if fill_holes:
        mask = binary_fill_holes(mask)

    if erode_pixels > 0:
        erode_kernel_size = erode_pixels * 2 + 1
        holes: NDArray | None = None

        if erode_ignores_holes and not fill_holes:
            mask_no_holes = binary_fill_holes(mask)
            holes = np.logical_xor(mask, mask_no_holes)
            mask = mask_no_holes

        mask = binary_erosion(
            input=mask,
            structure=np.ones((erode_kernel_size, erode_kernel_size), dtype=bool),
        )
        if holes is not None:
            mask[holes] = False

    return mask


def get_slices_to_crop_nodata_border(
    nodata_mask: NDArray[np.bool_],
) -> Tuple[slice, slice]:
    if nodata_mask.all():
        return slice(0, nodata_mask.shape[0]), slice(0, nodata_mask.shape[1])
    row_idx_ends = np.flatnonzero(~np.all(nodata_mask, axis=1))[[0, -1]].tolist()
    col_idx_ends = np.flatnonzero(~np.all(nodata_mask, axis=0))[[0, -1]].tolist()
    return slice(row_idx_ends[0], row_idx_ends[1] + 1), slice(col_idx_ends[0], col_idx_ends[1] + 1)


def round_float_values_for_compression(
    arr: NDArray[np.floating],
    inplace: bool = False,
) -> NDArray[np.floating]:
    """
    Optimize compression factor when writing floating point raster data
    by rounding the array values to the nearest 1/128 of the pixel value unit.
    """
    out = np.multiply(arr, 128.0, out=arr if inplace else None)
    np.round(arr, decimals=0, out=out)
    np.divide(arr, 128.0, out=out)
    return out


def _fill_missing_xyz_dataframe_rowcol(
    df: pd.DataFrame,
    axis: Literal["x", "y"],
) -> tuple[pd.DataFrame, float, float, float]:
    """
    Determine if XYZ dataframe column/row spacing is regular or irregular.
    If regular, identify x/y coordinate spacing and min/max x/y coordinate values.
    Identify missing columns/rows and add a dummy value to the dataframe for those
    missing columns/rows such that a pandas `df.pivot_table()` would result in a
    2D array that represents the full raster grid.
    """

    c_unique_sorted = np.unique(df[axis].values)  # Values are in sorted order
    c_min = c_unique_sorted[0]
    c_max = c_unique_sorted[-1]

    # Calculate the grid spacing for every interval between adjacent coordinate values
    c_diff = abs(np.diff(c_unique_sorted))

    # Take the smallest interval in coordinate spacing to be the grid spacing for this axis
    c_spacing = min(c_diff)

    # If there is a larger interval in coordinate spacing, we must check that the grid spacing
    # is regular, and fill in values on this axis for missing rows/columns.
    if max(c_diff) != c_spacing:
        # Check if all larger spacings are perfect multiples of the smallest spacing
        if not np.allclose(np.mod(c_diff, c_spacing), 0):
            raise ValueError(f"XYZ file {axis}-coordinate spacing is irregular")
        del c_diff

        # Axis coordinate spacing is regular, but we need to add one dummy value to the XYZ dataframe
        # for every missing grid row/column so these rows/cols are present when we make a pivot table later.
        coords_missing = np.setdiff1d(
            np.arange(c_min, c_max + c_spacing, c_spacing),
            c_unique_sorted,
        )
        del c_unique_sorted

        example_other_axis_value = df.iloc[0][{"x", "y"}.difference(axis).pop()]
        df = pd.concat(
            [
                df,
                pd.DataFrame(
                    [
                        [c, example_other_axis_value, np.nan]
                        if axis == "x"
                        else [example_other_axis_value, c, np.nan]
                        for c in coords_missing
                    ],
                    columns=["x", "y", "z"],
                ),
            ],
            axis=0,
        )

    return df, c_spacing, c_min, c_max


def _convert_xyz_dataframe_to_array(
    df: pd.DataFrame,
    crop_nodata_border: bool = False,
    erode_valid_area_pixels: int = 0,
    erode_valid_ignore_holes: bool = True,
) -> tuple[NDArray[np.float32], float, float, float, float]:
    """
    Convert an XYZ dataframe to a 2D NumPy array and return the x/y min/max coordinate extents.
    """

    df, cellsize_x, x_min, x_max = _fill_missing_xyz_dataframe_rowcol(df=df, axis="x")
    df, cellsize_y, y_min, y_max = _fill_missing_xyz_dataframe_rowcol(df=df, axis="y")

    # Convert XYZ table into a y-x (row-column) matrix of z values.
    # Missing values (including those for missing rows and columns that we patched earlier)
    # will be filled with nan.
    mat = df.pivot_table(columns="x", index="y", values="z", fill_value=np.nan, dropna=False)
    mat.sort_index(axis="index", ascending=False, inplace=True)
    mat.sort_index(axis="columns", ascending=True, inplace=True)

    # Extract the 2D array from the matrix, and don't make an unnecessary copy if we can help it
    arr = mat.values.astype(dtype=np.float32, copy=False)

    if erode_valid_area_pixels > 0:
        # Erode edge pixels as often the data there is poor quality
        arr[
            ~get_valid_data_mask(
                arr=arr,
                nodata_value=np.nan,
                erode_pixels=erode_valid_area_pixels,
                erode_ignores_holes=erode_valid_ignore_holes,
            )
        ] = np.nan

    if crop_nodata_border:
        row_slice, col_slice = get_slices_to_crop_nodata_border(nodata_mask=np.isnan(arr))
        if row_slice != slice(0, arr.shape[0]) or col_slice != slice(0, arr.shape[1]):
            y_max, y_min = mat.index.values[[row_slice.start, row_slice.stop - 1]]
            x_min, x_max = mat.columns.values[[col_slice.start, col_slice.stop - 1]]
            arr = arr[row_slice, col_slice]

    # Determine the x/y min/max coordinate extents, assuming the XYZ
    # values are point values so the true coordinate extents are half a pixel size larger
    # than the min/max coordinates from the XYZ values.
    south = y_min - cellsize_y / 2
    north = y_max + cellsize_y / 2
    west = x_min - cellsize_x / 2
    east = x_max + cellsize_x / 2

    # Check that the final array shape and grid spacing are consistent
    if north != (south + arr.shape[0] * cellsize_y) or east != (west + arr.shape[1] * cellsize_x):
        raise ValueError(
            "Converted array from XYZ file has a shape that does not match the original coordinate grid"
        )

    return arr, west, south, east, north


def xyz2tif(
    src_path: Path,
    epsg_code: int | None = None,
    *,
    tif_path: Path | None = None,
    src_column_order: str = "xyz",
    src_delimiter: str = r"\s+",
    src_nodata_values: list[float] | None = None,
    dst_nodata_value: float = -9999,
    crop_nodata_border: bool = False,
    erode_valid_area_pixels: int = 0,
    erode_valid_ignore_holes: bool = True,
    round_1_128_space_saving: bool = False,
) -> Path:
    """
    Convert ASCII format XYZ (CSV-like) grid file to a raster GeoTIFF file.
    - Integer EPSG code for raster horizontal CRS must be provided.
    - Optional one or more source NoData values are accepted.
    - If the order of the columns in the XYZ file are not standard (X, Y, Z),
      provide the correct column order using `src_column_order`. For example,
      if order of columns in the XYZ file are (Y, X, Z), provide
      `src_column_order="yxz".
    """
    src_path = Path(src_path)
    tif_path = src_path.with_suffix(".tif") if tif_path is None else Path(tif_path)
    if tif_path.is_file() and tif_path.samefile(src_path):
        raise ValueError("Default path for output GeoTIFF is the same as input XYZ file path")

    # Handle source nodata values, add +/-inf
    if not isinstance(src_nodata_values, list):
        src_nodata_values = [src_nodata_values]
    src_nodata_values_arr = np.array(
        list({np.inf, -np.inf, *src_nodata_values} - {None}),
        dtype=float,
    )

    # Validate source (XYZ file) column order specification
    src_column_order = src_column_order.lower().replace(",", "").replace(" ", "")
    if len(src_column_order) == 3 and all(c in src_column_order for c in "xyz"):
        pass
    else:
        raise ValueError(f"Source column order '{src_column_order}' not valid")

    def _parse_float_real_else_nan(_token: str) -> float:
        try:
            return float(_token)
        except (TypeError, ValueError):
            return np.nan

    # Accept many common column separators in the XYZ file,
    # and only consider the first three identified columns.
    df = pd.read_table(
        filepath_or_buffer=src_path,
        sep=src_delimiter,
        usecols=list(range(3)),
        names=list(src_column_order),
        converters={i: _parse_float_real_else_nan for i in range(3)},
        header=None,
        index_col=False,
    )

    # Convert any input src nodata z values to nan
    df.loc[np.where(np.isin(df["z"], src_nodata_values_arr))[0], "z"] = np.nan

    if crop_nodata_border:
        # Drop rows with nan in either x/y coordinate column or z value
        # The crop check will happen again in `_convert_xyz_dataframe_to_array`
        # after possible erosion, but by nan z values here we potentially save
        # a lot of memory usage if we were to turn the entire grid into an array.
        df.dropna(axis=0, how="any", inplace=True)
    else:
        # Drop malformed or header rows with nan in either x or y coordinate column
        df.dropna(axis=0, how="any", subset=["x", "y"], inplace=True)

    if df.empty:
        raise ValueError("XYZ file has no valid values or contains unexpected formatting")

    # Convert the XYZ dataframe to a 2D numpy array
    # and retrieve the x/y min/max coordinate extents of the raster.
    arr, west, south, east, north = _convert_xyz_dataframe_to_array(
        df=df,
        crop_nodata_border=crop_nodata_border,
        erode_valid_area_pixels=erode_valid_area_pixels,
        erode_valid_ignore_holes=erode_valid_ignore_holes,
    )
    del df

    # Ensure array data type is float32, don't make an unnecessary copy if we can help it
    arr = arr.astype(dtype=np.float32, copy=False)

    if round_1_128_space_saving:
        # Round DEM values to 1/128 to greatly improve compression effectiveness
        round_float_values_for_compression(arr, inplace=True)

    # Replace nan values with dst nodata value
    arr[np.isnan(arr)] = dst_nodata_value

    # Write output geotiff raster file
    try:
        with rio.open(
            tif_path,
            mode="w",
            driver="GTiff",
            dtype=str(arr.dtype),
            height=arr.shape[0],
            width=arr.shape[1],
            count=1,
            crs=rio.CRS.from_epsg(epsg_code) if epsg_code else None,
            transform=rio.transform.from_bounds(
                west=west, south=south, east=east, north=north, width=arr.shape[1], height=arr.shape[0]
            ),
            nodata=dst_nodata_value,
            compress="lzw",
            tiled="yes",
            bigtiff="yes",
        ) as ds:
            ds.write(arr, 1)
    except Exception:
        tif_path.unlink(missing_ok=True)
        raise

    return tif_path


if __name__ == "__main__":
    run(xyz2tif)
