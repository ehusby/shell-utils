#!/usr/bin/env python

import os
from pathlib import Path

import numpy as np
import pandas as pd
import rasterio as rio

from typer import run


def xyz2tif(
    xyz_path,
    epsg_code,
    *,
    tif_path: Path | None = None,
    src_nodata_values: list[float] | None = None,
    dst_nodata_value: float = -9999,
    src_column_order: str = "xyz",
    src_delimiter: str = r"\s+",
    drop_nodata_height_values: bool = False,
    round_1_128_space_saving: bool = False,
) -> Path:
    xyz_path = Path(xyz_path)
    tif_path = xyz_path.with_suffix(".tif") if tif_path is None else Path(tif_path)
    xyz_temp_path = tif_path.with_suffix(".tif.tmp.xyz")

    try:
        src_column_order = src_column_order.lower().replace(",", "").replace(" ", "")
        if len(src_column_order) == 3 and all(c in src_column_order for c in "xyz"):
            pass
        else:
            raise ValueError(f"Source column order '{src_column_order}' not valid")

        def parse_float_real_else_nan(token: str) -> float:
            try:
                v = float(token)
                return v if v not in (np.inf, -np.inf) else np.nan
            except (TypeError, ValueError):
                return np.nan

        # Accept many common column separators in the XYZ file,
        # and only consider the first three identified columns.
        df = pd.read_table(
            filepath_or_buffer=xyz_path,
            sep=src_delimiter,
            usecols=list(range(3)),
            names=list(src_column_order),
            converters={i: parse_float_real_else_nan for i in range(3)},
            header=None,
            index_col=False,
        )

        # Convert any input src nodata float values to nan
        if src_nodata_values is not None:
            # df.loc[df.index[np.where(np.isin(df["z"], src_nodata_values))[0]], "z"] = np.nan
            df["z"][np.isin(df["z"], src_nodata_values)] = np.nan

        if drop_nodata_height_values:
            # Drop rows with nan in either x/y coordinate column or z value
            df.dropna(axis=0, how="any", inplace=True)
        else:
            # Drop all-nan rows, such as header row(s)
            df.dropna(axis=0, how="all", inplace=True)
            # Drop malformed rows with nan in either x or y coordinate column
            df.dropna(axis=0, how="any", subset=["x", "y"], inplace=True)

        if round_1_128_space_saving:
            # Round DEM values to 1/128 to greatly improve compression effectiveness
            np.multiply(df["z"], 128.0, out=df["z"])
            df["z"] = np.round(df["z"], decimals=0)
            np.divide(df["z"], 128.0, out=df["z"])

        # Replace remaining nan values in z column with dst nodata value
        if not drop_nodata_height_values:
            df.fillna(value=dst_nodata_value, inplace=True)

        # GDAL's XYZ driver expects the x/y coordinate values to be in a
        # particular sorted order.
        df = df.sort_values(by=["y", "x"], ascending=[False, True], ignore_index=True)

        # Write intermediate sanitized XYZ file
        df.to_csv(
            path_or_buf=xyz_temp_path,
            columns=["x", "y", "z"],
            sep=" ",
            header=False,
            index=False,
        )

        # Read sanitized XYZ and capture needed metadata for conversion to TIF
        with rio.open(xyz_temp_path, mode="r", driver="XYZ") as ds_xyz:
            xyz_internal_nodata = ds_xyz.profile.get("nodata", None)

            # Prepare output TIF dataset write options
            tif_profile = ds_xyz.profile.copy()
            tif_profile.update(
                driver="GTiff",
                dtype="float32",
                crs=rio.CRS.from_epsg(epsg_code),
                nodata=dst_nodata_value,
                compress="lzw",
                tiled=True,
                bigtiff=True,
            )

            # Write out TIF by block to minimize memory usage
            with rio.open(tif_path, mode="w", **tif_profile) as ds_tif:
                for _, window in ds_xyz.block_windows(1):
                    if xyz_internal_nodata is None:
                        ds_tif.write(ds_xyz.read(indexes=1, window=window).astype(np.float32), indexes=1, window=window)
                    else:
                        chunk = ds_xyz.read(indexes=1, window=window).astype(np.float32)
                        chunk[chunk == xyz_internal_nodata] = dst_nodata_value
                        ds_tif.write(chunk, indexes=1, window=window)

        return tif_path

    except Exception:
        if os.path.isfile(tif_path):
            os.remove(tif_path)
        raise

    finally:
        if os.path.isfile(xyz_temp_path):
            os.remove(xyz_temp_path)


if __name__ == "__main__":
    run(xyz2tif)
