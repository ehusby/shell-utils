#!/usr/bin/env python

from pathlib import Path

import numpy as np
import rasterio as rio

from dem_scraping.rasterio_utils import (
    get_valid_data_mask,
    round_float_values_for_compression,
)

from typer import run


def grid2tif(
    grid_path: Path,
    epsg_code: int | None = None,
    *,
    tif_path: Path | None = None,
    src_nodata_values: list[float] | None = None,
    dst_nodata_value: float = -9999,
    force_float32: bool = False,
    erode_valid_area_pixels: int = 0,
    erode_valid_ignore_holes: bool = True,
    round_1_128_space_saving: bool = False,
) -> Path:
    grid_path = Path(grid_path)
    tif_path = grid_path.with_suffix(".tif") if tif_path is None else Path(tif_path)
    if tif_path.is_file() and tif_path.samefile(grid_path):
        raise ValueError(
            "Default path for output GeoTIFF is the same as input grid path"
        )

    if not isinstance(src_nodata_values, list):
        src_nodata_values = [src_nodata_values]

    # We have to force float32 output if the dst nodata value isn't an integer
    force_float32 |= dst_nodata_value != int(dst_nodata_value)

    with rio.open(grid_path, "r") as ds_src:
        dst_profile = ds_src.profile.copy()

        # Handle source nodata values, add +/-inf
        src_nodata_values_arr = np.array(
            list({ds_src.nodata, np.inf, -np.inf, *src_nodata_values} - {None}),
            dtype=float,
        )

        dst_profile.update(
            driver="GTiff",
            nodata=dst_nodata_value,
            compress="lzw",
            tiled="yes",
            bigtiff="yes",
        )
        if force_float32:
            dst_profile.update(dtype="float32")

        # Add/overwrite existing CRS with argument EPSG code
        if epsg_code:
            dst_profile.update(crs=rio.CRS.from_epsg(epsg_code))

        # Read array data
        data_array = ds_src.read(indexes=1)

        # Identify no-data pixels
        nodata_mask = np.logical_or(
            np.isnan(data_array), np.isin(data_array, src_nodata_values_arr)
        )

        if force_float32:
            data_array = data_array.astype(np.float32, copy=False)

        # Set no-data pixels to dst nodata value
        data_array[nodata_mask] = dst_nodata_value

        if erode_valid_area_pixels > 0:
            # Erode edge pixels as often the data there is poor quality
            data_array[
                ~get_valid_data_mask(
                    arr=data_array,
                    nodata_value=dst_nodata_value,
                    erode_pixels=erode_valid_area_pixels,
                    erode_ignores_holes=erode_valid_ignore_holes,
                )
            ] = dst_nodata_value

        if round_1_128_space_saving and np.issubdtype(data_array.dtype, np.floating):
            # Round float DEM values to 1/128 to greatly improve compression effectiveness
            if erode_valid_area_pixels > 0:
                nodata_mask = data_array == dst_nodata_value
            round_float_values_for_compression(data_array, inplace=True)
            data_array[nodata_mask] = dst_nodata_value

        with rio.open(tif_path, "w", **dst_profile) as ds_dst:
            ds_dst.write(data_array, indexes=1)

    return tif_path


if __name__ == "__main__":
    run(grid2tif)
