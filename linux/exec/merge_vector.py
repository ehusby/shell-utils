#!/usr/bin/env python

from pathlib import Path
from typing import Sequence

import geopandas as gpd
import numpy as np
import pandas as pd

from typer import run

import asyncio


async def async_read_file_to_gdf(path: Path | str) -> gpd.GeoDataFrame:
    path = Path(path)
    if path.suffix.lower() in (".parquet", ".geoparquet"):
        return gpd.read_parquet(str(path))
    return gpd.read_file(
        str(path),
        driver="GeoJSON" if path.suffix.lower() in (".json", ".geojson") else None,
    )


async def async_read_files(paths: Sequence[Path | str]) -> list[gpd.GeoDataFrame]:
    return await asyncio.gather(*(async_read_file_to_gdf(p) for p in paths))


def merge_vector_files(
    out_vector_path: Path,
    in_vector_paths: Sequence[Path],
    convert_obj_to_str: bool = False,
    convert_all_dtypes: bool = False,
    cast_numeric_cols: bool = False,
) -> Path:
    out_vector_path = Path(out_vector_path)

    gdf = pd.concat(
        asyncio.run(async_read_files(in_vector_paths)),
        ignore_index=True,
        copy=False,
    )
    gdf.reset_index(drop=True, inplace=True)

    if convert_all_dtypes:
        gdf = gdf.convert_dtypes()

    if convert_obj_to_str:
        for col in gdf.columns:
            if gdf[col].dtype == np.dtype("O"):
                gdf[col] = gdf[col].astype(str)

    if cast_numeric_cols:
        for col in gdf.columns:
            gdf[col] = pd.to_numeric(
                arg=gdf[col],
                errors="ignore",
            )

    if out_vector_path.suffix.lower() in (".parquet", ".geoparquet"):
        gdf.to_parquet(str(out_vector_path))
    else:
        gdf.to_file(
            str(out_vector_path),
            driver="GeoJSON"
            if out_vector_path.suffix.lower() in (".json", ".geojson")
            else None,
        )

    return out_vector_path


if __name__ == "__main__":
    run(merge_vector_files)
