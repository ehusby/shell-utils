#!/usr/bin/env python

import json
import os
import urllib.request
from itertools import count
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import box

from typer import run


def mapserver_layer_download(
    layer_url: str,
    output_path: Path = os.getcwd(),
    output_path_default_ext: str = ".parquet",
    epsg_code: int | None = None,
    records_chunk_size: int | None = None,
    xmin_ymin_xmax_ymax_fields: tuple[str, str, str, str] | None = None,
) -> Path:
    layer_url = layer_url.rstrip("/")
    output_path = Path(output_path)

    with urllib.request.urlopen(f"{layer_url}?f=pjson") as req:  # noqa: S310
        layer_data = json.load(req)

        if output_path.is_dir():
            output_path = output_path / f"{layer_data['name']}{output_path_default_ext}"

        try:
            if epsg_code is None:
                epsg_code = int(layer_data["sourceSpatialReference"]["latestWkid"])
        except KeyError:
            pass

        if records_chunk_size is None and "maxRecordCount" in layer_data:
            records_chunk_size = int(layer_data["maxRecordCount"])

    if records_chunk_size is None:
        records_chunk_size = 1000

    gdf_list = []
    for record_offset_idx in count(0, records_chunk_size):
        get_features_url = f"{layer_url}/query?f=geojson&resultOffset={record_offset_idx}&resultRecordCount={records_chunk_size}&where=1%3D1&orderByFields=&outFields=*&returnGeometry=false&spatialRel=esriSpatialRelIntersects"
        gdf = gpd.read_file(urllib.request.urlopen(get_features_url))  # noqa: S310
        if gdf.empty:
            break
        gdf_list.append(gdf)

    gdf = pd.concat(gdf_list).pipe(gpd.GeoDataFrame)
    if epsg_code is not None:
        gdf.set_crs(epsg=epsg_code, inplace=True, allow_override=True)

    if xmin_ymin_xmax_ymax_fields:
        gdf["geometry"] = gdf.apply(
            lambda row: box(*row[list(xmin_ymin_xmax_ymax_fields)]), axis=1
        )

    if str(output_path).lower().endswith((".parquet", ".geoparquet")):
        gdf.to_parquet(str(output_path))
    else:
        gdf.to_file(str(output_path))

    return output_path


if __name__ == "__main__":
    run(mapserver_layer_download)
