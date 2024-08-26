#!/usr/bin/env python

import os
import subprocess
from pathlib import Path

import numpy as np
import pandas as pd

from clize import run


def xyz2tif(
    xyz_path,
    epsg_code,
    *,
    tif_path=None,
    src_nodata_values=None,
    dst_nodata_value=-9999,
    src_column_order="xyz",
    src_delimiter=r"\s+",
    drop_nodata_height_values=False,
    round_1_128_space_saving=False,
    # tif_path: str | Path | None = None,
    # src_nodata_values: list[int | float] | None = None,
    # dst_nodata_value: float = -9999,
    # src_column_order: str = "xyz",
    # src_delimiter: str = r"\s+",
    # drop_nodata_height_values: bool = False,
    # round_1_128_space_saving: bool = False,
) -> Path:
    xyz_path = Path(xyz_path)
    tif_path = xyz_path.with_suffix(".tif") if tif_path is None else Path(tif_path)

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

        # Prepare gdalwarp command to convert sanitized XYZ file to final TIF
        cmd = rf"""
gdalwarp -overwrite \
    -of GTiff \
    -ot Float32 \
    -s_srs "EPSG:{epsg_code}" \
    -dstnodata "{dst_nodata_value}" \
    -oo COLUMN_ORDER=XYZ \
    -co COMPRESS=LZW -co TILED=YES -co BIGTIFF=YES \
    '/vsistdin?buffer_limit=10000000000/' \
    "{tif_path}"
"""

        # Pipe sanitized XYZ file as CSV to gdalwarp command
        proc = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE)
        df.to_csv(
            path_or_buf=proc.stdin,
            columns=["x", "y", "z"],
            sep=" ",
            header=False,
            index=False,
        )
        proc.communicate()

        return tif_path

    except Exception:
        if os.path.isfile(tif_path):
            os.remove(tif_path)
        raise


if __name__ == "__main__":
    run(xyz2tif)
