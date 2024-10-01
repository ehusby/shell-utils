#!/usr/bin/env python

import math
from enum import Enum
from pathlib import Path
from typing import Literal, Tuple

import numpy as np
import pandas as pd
import pyproj
import rasterio as rio
import shapely.geometry
from numpy.typing import NDArray
from scipy.interpolate import RegularGridInterpolator, griddata
from scipy.ndimage import binary_erosion, binary_fill_holes, binary_opening
from shapely.coordinates import get_coordinates
from rasterio.coords import BoundingBox

from typer import run


class HorizontalUnit(str, Enum):
    ARCSEC = "arcsec"
    DEGREE = "degree"
    FOOT = "foot"
    METER = "meter"


class VerticalUnit(str, Enum):
    FOOT = "foot"
    US_SURVEY_FOOT = "us_survey_foot"
    METER = "meter"
    CENTIMETER = "centimeter"


UNIT_IN_METERS = {
    "meter": 1,
    "centimeter": 0.01,
    "foot": 0.3048,
    "us_survey_foot": 0.3048006096,
}


def validate_epsg_code(v: int | None) -> int | None:
    if v is None:
        return None
    try:
        crs = pyproj.CRS.from_epsg(v)
        if crs is None:
            raise ValueError("Invalid EPSG code; 'pyproj.CRS.from_epsg' returns None")
    except pyproj.exceptions.CRSError as exc:
        raise ValueError(
            f"Invalid EPSG code; 'pyproj.CRS.from_epsg' throws error: {exc}"
        ) from exc
    return v


def get_pyproj_crs_and_epsg_code(
    epsg_code_or_pyproj_crs: int | pyproj.CRS,
) -> tuple[pyproj.CRS, int | None]:
    if epsg_code_or_pyproj_crs is None:
        raise ValueError("Argument 'epsg_code_or_pyproj_crs' is None")

    epsg_code: int | None
    if isinstance(epsg_code_or_pyproj_crs, int):
        epsg_code = epsg_code_or_pyproj_crs
        validate_epsg_code(epsg_code)
        crs = pyproj.CRS.from_epsg(epsg_code)
    else:
        crs = epsg_code_or_pyproj_crs
        epsg_code = epsg_code_or_pyproj_crs.to_epsg()

    return crs, epsg_code


def get_crs_horizontal_unit(
    epsg_code_or_pyproj_crs: int | pyproj.CRS,
) -> HorizontalUnit:
    crs, epsg_code = get_pyproj_crs_and_epsg_code(epsg_code_or_pyproj_crs)

    horiz_axis_list = [
        axis
        for axis in crs.axis_info
        if axis.abbrev.lower() in ("x", "y", "lat", "lon")
        or axis.direction.lower() in ("north", "south", "east", "west")
    ]
    if len(horiz_axis_list) == 0:
        raise ValueError(
            " ".join(
                [
                    "Could not find horizontal axis in pyproj.CRS.axis_info list for",
                    f"EPSG code: {epsg_code}"
                    if epsg_code is not None
                    else f"CRS: {crs}",
                ]
            )
        )

    horiz_axis = horiz_axis_list[0]

    unit_raw = horiz_axis.unit_name.lower().replace(" ", "_").replace("metre", "meter")
    try:
        return HorizontalUnit(unit_raw)
    except ValueError as e:
        raise ValueError(
            " ".join(
                [
                    f"Unhandled horizontal unit name '{unit_raw}' from",
                    f"EPSG code: {epsg_code}"
                    if epsg_code is not None
                    else f"CRS: {crs}",
                ]
            )
        ) from e


def distance_between_coordinates_meters(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    # https://stackoverflow.com/a/19412565

    # Approximate radius of earth in km
    r = 6373.0

    lat1 = math.radians(lat1)
    lon1 = math.radians(lon1)
    lat2 = math.radians(lat2)
    lon2 = math.radians(lon2)

    dlon = lon2 - lon1
    dlat = lat2 - lat1

    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    distance_km = r * c

    return distance_km * 1000


def get_approx_spacing_from_degrees_to_meters(
    bbox_deg: shapely.geometry.box, dx_deg: float, dy_deg: float
) -> tuple[float, float]:
    center_lon, center_lat = get_coordinates(bbox_deg.centroid).flatten()
    dx_meters = round(
        distance_between_coordinates_meters(
            center_lat, center_lon - dx_deg, center_lat, center_lon + dx_deg
        )
        / 2,
        4,
    )
    dy_meters = round(
        distance_between_coordinates_meters(
            center_lat - dy_deg, center_lon, center_lat + dy_deg, center_lon
        )
        / 2,
        4,
    )
    return dx_meters, dy_meters


def get_grid_spacing_meters(
    crs_horiz_unit: str,
    cellsize_x: float,
    cellsize_y: float,
    bounds: BoundingBox,
) -> tuple[float, float]:
    if crs_horiz_unit not in ["degree", *UNIT_IN_METERS.keys()]:
        raise ValueError(f"{crs_horiz_unit=} not handled")

    if crs_horiz_unit == "degree":
        return get_approx_spacing_from_degrees_to_meters(
            bbox_deg=shapely.geometry.box(
                minx=bounds.left,
                miny=bounds.bottom,
                maxx=bounds.right,
                maxy=bounds.top,
            ),
            dx_deg=cellsize_x,
            dy_deg=cellsize_y,
        )

    return (
        cellsize_x * UNIT_IN_METERS[crs_horiz_unit],
        cellsize_y * UNIT_IN_METERS[crs_horiz_unit],
    )


def get_grid_factor(
    cellsize_x_m: float,
    target_grid_spacing_meters: float,
    buffer_fraction: float = 0.02,
) -> int:
    return int(
        math.floor(target_grid_spacing_meters / (cellsize_x_m * (1 - buffer_fraction)))
    )


def downsample_array_to_target_grid(
    array: NDArray,
    x_coords: NDArray,
    y_coords: NDArray,
    cellsize_x_meters: float,
    cellsize_y_meters: float,
    target_grid_spacing_meters: float,
    grid_factor_buffer_faction: float = 0.02,
) -> tuple[NDArray, NDArray, NDArray]:
    grid_factor_x = get_grid_factor(
        cellsize_x_meters, target_grid_spacing_meters, grid_factor_buffer_faction
    )
    grid_factor_y = get_grid_factor(
        cellsize_y_meters, target_grid_spacing_meters, grid_factor_buffer_faction
    )

    grid_factor_x_raw = target_grid_spacing_meters / cellsize_x_meters
    grid_factor_y_raw = target_grid_spacing_meters / cellsize_y_meters

    target_res_x = abs(x_coords[1] - x_coords[0]) * (
        grid_factor_x
        if abs(grid_factor_x - grid_factor_x_raw) < grid_factor_buffer_faction
        else grid_factor_x_raw
    )
    target_res_y = abs(y_coords[1] - y_coords[0]) * (
        grid_factor_y
        if abs(grid_factor_y - grid_factor_y_raw) < grid_factor_buffer_faction
        else grid_factor_y_raw
    )

    return resample_array_to_resolution(
        array=array,
        x_coords=x_coords,
        y_coords=y_coords,
        target_res_x=target_res_x,
        target_res_y=target_res_y,
    )


def resample_array_to_resolution(
    array: NDArray,
    x_coords: NDArray,
    y_coords: NDArray,
    target_res_x: float,
    target_res_y: float,
) -> tuple[NDArray, NDArray, NDArray]:
    xi = np.arange(*x_coords[[0, -1]].tolist(), target_res_x, dtype=np.float64)  # type: ignore [call-overload]
    yi = np.arange(*y_coords[[0, -1]].tolist(), -target_res_y, dtype=np.float64)  # type: ignore [call-overload]

    interp = RegularGridInterpolator(
        points=(y_coords, x_coords),
        values=array,
        bounds_error=True,
        fill_value=np.nan,
    )

    xxi, yyi = np.meshgrid(xi, yi, indexing="xy")

    return interp((yyi, xxi)).astype(np.float32, copy=False), xi, yi


def fill_array_nodata(
    array: NDArray,
    keep_nodata_kernel: NDArray[np.bool_] | None = None,
    x_coords: NDArray | None = None,
    y_coords: NDArray | None = None,
) -> None:
    nodata_mask = np.isnan(array)
    data_points_loc = np.nonzero(~nodata_mask)

    if keep_nodata_kernel is not None:
        nodata_mask_keep = binary_opening(
            input=nodata_mask,
            structure=keep_nodata_kernel,
        )
        interp_area = np.logical_xor(nodata_mask, nodata_mask_keep)
        del nodata_mask_keep
    else:
        interp_area = nodata_mask

    del nodata_mask

    interp_area_loc = np.nonzero(interp_area)

    if x_coords is None and y_coords is None:
        y_coords = np.arange(array.shape[0], dtype=int)
        x_coords = np.arange(array.shape[1], dtype=int)
    elif x_coords is None or y_coords is None:
        raise ValueError(
            "Either both 'x_coords' and 'y_coords' must be provided, or both left None"
        )

    array[interp_area] = griddata(
        points=(y_coords[data_points_loc[0]], x_coords[data_points_loc[1]]),
        values=array[data_points_loc],
        xi=(y_coords[interp_area_loc[0]], x_coords[interp_area_loc[1]]),
        method="linear",
        fill_value=np.nan,
    )


def get_valid_data_mask(
    arr: NDArray[np.floating],
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
    return slice(row_idx_ends[0], row_idx_ends[1] + 1), slice(
        col_idx_ends[0], col_idx_ends[1] + 1
    )


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
    max_interval_factor: float | None = 100,
) -> tuple[pd.DataFrame, float, float, float]:
    """
    Determine if XYZ dataframe column/row spacing is regular or irregular.
    If regular, identify x/y coordinate spacing and min/max x/y coordinate values.
    Identify missing columns/rows and add a dummy NaN value to the dataframe for those
    missing columns/rows such that a pandas `df.pivot_table()` would result in a
    2D array that represents the full raster grid.
    """

    # Values are in sorted order
    c_unique_sorted = np.unique(df[axis].values)  # type: ignore [arg-type]
    c_min = c_unique_sorted[0]
    c_max = c_unique_sorted[-1]

    # Calculate the grid spacing for every interval between adjacent coordinate values
    c_diff = abs(np.diff(c_unique_sorted))

    # Take the smallest interval in coordinate spacing to be the grid spacing for this axis
    c_spacing = min(c_diff)

    # If there is a larger interval in coordinate spacing, we must check that the grid spacing
    # is regular, and fill in values on this axis for missing rows/columns.
    max_interval = max(c_diff)
    if max_interval != c_spacing:
        # Check if all larger spacings are perfect multiples of the smallest spacing
        if not np.allclose(np.mod(c_diff, c_spacing), 0):
            raise ValueError(f"XYZ file {axis}-coordinate spacing is irregular")
        if max_interval_factor and (max_interval / c_spacing) > max_interval_factor:
            raise ValueError(
                f"XYZ file {axis}-coordinate spacing detected interval spread of (int_min={c_spacing}, int_max={max_interval})"
                f" units, with int_max being a multiple of int_min greater than maximum allowed factor of {max_interval_factor}"
            )
        del c_diff

        # Axis coordinate spacing is regular, but we need to add one dummy NaN value to the XYZ dataframe
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
    crs_horiz_unit: str | None = None,
    target_grid_spacing_meters: float | None = None,
    min_grid_spacing_meters: float | None = None,
    interp_fill_smaller_than_target_grid: bool = False,
    downsample_to_target_grid: bool = False,
    grid_factor_buffer_fraction: float = 0.02,
) -> tuple[NDArray[np.float32], BoundingBox]:
    """
    Convert an XYZ dataframe to a 2D NumPy array and return the x/y min/max coordinate extents.
    """
    if min_grid_spacing_meters is None and target_grid_spacing_meters is not None:
        min_grid_spacing_meters = target_grid_spacing_meters / 4

    if crs_horiz_unit is not None:
        crs_horiz_unit = crs_horiz_unit.lower().replace("metre", "meter")

    df, cellsize_x, x_min, x_max = _fill_missing_xyz_dataframe_rowcol(df=df, axis="x")
    df, cellsize_y, y_min, y_max = _fill_missing_xyz_dataframe_rowcol(df=df, axis="y")

    # Convert XYZ table into a y-x (row-column) matrix of z values.
    # Missing values (including those for missing rows and columns that we patched earlier)
    # will be filled with nan.
    mat = df.pivot_table(
        index="y", columns="x", values="z", fill_value=np.nan, dropna=False
    )
    mat.sort_index(axis="index", ascending=False, inplace=True)
    mat.sort_index(axis="columns", ascending=True, inplace=True)

    # Extract the 2D array from the matrix, and don't make an unnecessary copy if we can help it
    arr = mat.values.astype(dtype=np.float32, copy=False)

    x_coords = np.asarray(mat.columns.values, dtype=np.float64)
    y_coords = np.asarray(mat.index.values, dtype=np.float64)
    del mat

    test_x_coords_dx = abs(x_coords[1] - x_coords[0])
    if cellsize_x != test_x_coords_dx:
        raise ValueError(
            f"x-axis coordinate spacing is incorrectly handled: {cellsize_x=} != {test_x_coords_dx=}"
        )

    test_y_coords_dy = abs(y_coords[1] - y_coords[0])
    if cellsize_y != test_y_coords_dy:
        raise ValueError(
            f"y-axis coordinate spacing is incorrectly handled: {cellsize_y=} != {test_y_coords_dy=}"
        )

    if interp_fill_smaller_than_target_grid or downsample_to_target_grid:
        if not (target_grid_spacing_meters and crs_horiz_unit):
            raise ValueError(
                "'target_grid_spacing_meters' and 'crs_horiz_unit' must be provided to check for smaller than target grid"
            )

        if min_grid_spacing_meters is None:
            min_grid_spacing_meters = target_grid_spacing_meters / 4

        (
            cellsize_x_m,
            cellsize_y_m,
        ) = get_grid_spacing_meters(
            crs_horiz_unit=crs_horiz_unit,
            cellsize_x=cellsize_x,
            cellsize_y=cellsize_y,
            bounds=BoundingBox(
                left=x_min,
                bottom=y_min,
                right=x_max,
                top=y_max,
            ),
        )

        grid_factor_x = get_grid_factor(
            cellsize_x_m, target_grid_spacing_meters, grid_factor_buffer_fraction
        )
        grid_factor_y = get_grid_factor(
            cellsize_y_m, target_grid_spacing_meters, grid_factor_buffer_fraction
        )

        grid_spacing_meters = min(cellsize_x_m, cellsize_y_m)
        grid_factor = min(grid_factor_x, grid_factor_y)

        if (
            min_grid_spacing_meters > 0
            and grid_spacing_meters * (1 - grid_factor_buffer_fraction)
            < min_grid_spacing_meters
        ):
            raise ValueError(
                f"Grid spacing is smaller than allowed minimum: {grid_spacing_meters:.4f} m < {min_grid_spacing_meters:.4f} m"
            )

        if grid_factor > 1:
            if interp_fill_smaller_than_target_grid:
                # Kernel size for kept nodata areas is the next largest odd factor
                keep_nodata_kernel = np.ones(
                    shape=(
                        grid_factor_y + (1 if grid_factor_y % 2 == 0 else 2),
                        grid_factor_x + (1 if grid_factor_x % 2 == 0 else 2),
                    ),
                    dtype=bool,
                )
                fill_array_nodata(
                    array=arr,
                    keep_nodata_kernel=keep_nodata_kernel,
                    x_coords=x_coords,
                    y_coords=y_coords,
                )

            if downsample_to_target_grid:
                arr, x_coords, y_coords = downsample_array_to_target_grid(
                    array=arr,
                    x_coords=x_coords,
                    y_coords=y_coords,
                    cellsize_x_meters=cellsize_x_m,
                    cellsize_y_meters=cellsize_y_m,
                    target_grid_spacing_meters=target_grid_spacing_meters,
                    grid_factor_buffer_faction=grid_factor_buffer_fraction,
                )
                cellsize_x = abs(x_coords[1] - x_coords[0])
                cellsize_y = abs(y_coords[1] - y_coords[0])
                x_min, x_max = x_coords[[0, -1]]
                y_max, y_min = y_coords[[0, -1]]

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
        row_slice, col_slice = get_slices_to_crop_nodata_border(
            nodata_mask=np.isnan(arr)
        )
        if row_slice != slice(0, arr.shape[0]) or col_slice != slice(0, arr.shape[1]):
            y_max, y_min = y_coords[[row_slice.start, row_slice.stop - 1]]
            x_min, x_max = x_coords[[col_slice.start, col_slice.stop - 1]]
            arr = arr[row_slice, col_slice]

    # Determine the x/y min/max coordinate extents, assuming the XYZ
    # values are point values so the true coordinate extents are half a pixel size larger
    # than the min/max coordinates from the XYZ values.
    bounds = BoundingBox(
        left=x_min - cellsize_x / 2,
        bottom=y_min - cellsize_y / 2,
        right=x_max + cellsize_x / 2,
        top=y_max + cellsize_y / 2,
    )

    # Check that the final array shape and grid spacing are consistent
    if bounds.right != (bounds.left + arr.shape[1] * cellsize_x) or bounds.top != (
        bounds.bottom + arr.shape[0] * cellsize_y
    ):
        raise ValueError(
            "Converted array from XYZ file has a shape that does not match the original coordinate grid"
        )

    return arr, bounds


def xyz2tif(
    src_path_: Path,
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
    target_grid_spacing_meters: float | None = None,
    min_grid_spacing_meters: float | None = None,
    interp_fill_smaller_than_target_grid: bool = False,
    downsample_to_target_grid: bool = False,
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
    src_path = Path(src_path_)
    tif_path = src_path.with_suffix(".tif") if tif_path is None else Path(tif_path)
    if tif_path.is_file() and tif_path.samefile(src_path):
        raise ValueError(
            "Default path for output GeoTIFF is the same as input XYZ file path"
        )

    # Handle source nodata values, add +/-inf
    if not isinstance(src_nodata_values, list):
        src_nodata_values = [src_nodata_values]  # type: ignore [list-item]
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

    informed_crs = rio.CRS.from_epsg(epsg_code) if epsg_code else None

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
    df.loc[np.where(np.isin(df["z"], src_nodata_values_arr))[0], "z"] = np.nan  # type: ignore [index]

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
        raise ValueError(
            "XYZ file has no valid values or contains unexpected formatting"
        )

    # Convert the XYZ dataframe to a 2D numpy array
    # and retrieve the x/y min/max coordinate extents of the raster.
    crs_horiz_unit = (
        get_crs_horizontal_unit(pyproj.CRS(informed_crs))
        if informed_crs is not None
        else None
    )
    arr, bounds = _convert_xyz_dataframe_to_array(
        df=df,
        target_grid_spacing_meters=target_grid_spacing_meters,
        min_grid_spacing_meters=min_grid_spacing_meters,
        interp_fill_smaller_than_target_grid=interp_fill_smaller_than_target_grid,
        downsample_to_target_grid=downsample_to_target_grid,
        crs_horiz_unit=crs_horiz_unit,
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
    out_transform = rio.transform.from_bounds(
        west=bounds.left,
        south=bounds.bottom,
        east=bounds.right,
        north=bounds.top,
        width=arr.shape[1],
        height=arr.shape[0],
    )
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
            transform=out_transform,
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
