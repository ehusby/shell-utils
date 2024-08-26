#!/usr/bin/env python

from typing import Sequence
from pathlib import Path

import geopandas as gpd
import pandas as pd

from typer import run


def merge_vector_files(
    in_vector_paths: Sequence[Path],
    out_vector_path: Path,
) -> Path:
    gdf = pd.concat([gpd.read_file(fp) for fp in in_vector_paths]).pipe(
        gpd.GeoDataFrame
    )
    if Path(out_vector_path).suffix.lower() in (".parquet", ".geoparquet"):
        gdf.to_parquet(str(out_vector_path))
    else:
        gdf.to_file(str(out_vector_path))
    return Path(out_vector_path)


if __name__ == "__main__":
    run(merge_vector_files)
