#!/usr/bin/env python

import argparse
import numpy as np
import pandas as pd
import re
import xml.etree.ElementTree as ET

import geopandas as gpd
from pyproj import CRS
from shapely.geometry import Polygon


def make_source_geom(vrt_geotrans, src_DstRect):
    vrt_ul_x = vrt_geotrans[0]
    vrt_ul_y = vrt_geotrans[3]
    dx = vrt_geotrans[1]
    dy = vrt_geotrans[5]
    ul_x = vrt_ul_x + src_DstRect.xOff * dx
    ul_y = vrt_ul_y + src_DstRect.yOff * dy
    polygon = Polygon(
        (
            (ul_x, ul_y),
            (ul_x, ul_y + src_DstRect.ySize * dy),
            (ul_x + src_DstRect.xSize * dx, ul_y + src_DstRect.ySize * dy),
            (ul_x + src_DstRect.xSize * dx, ul_y),
            (ul_x, ul_y),
        )
    )
    return polygon


def main():
    arg_parser = argparse.ArgumentParser(
        description=(
            "Take a GDAL VRT file of `<ComplexSource>` raster source files and"
            " output a geodataset containing polygon feature outlines representing"
            " the source raster extents."
        )
    )
    arg_parser.add_argument(
        "-i", "--input-vrt",
        type=str,
        help="Input VRT file"
    )
    arg_parser.add_argument(
        "-o", "--output-file",
        type=str,
        help="Output file for extracted source raster features"
    )
    args = arg_parser.parse_args()

    print(f"Reading input VRT file: {args.input_vrt}")
    tree = ET.parse(args.input_vrt)
    root = tree.getroot()

    proj_wkt = root.find("SRS").text
    vrt_geotrans = re.sub(r"\s+", "", root.find("GeoTransform").text)
    vrt_geotrans = np.fromstring(vrt_geotrans, dtype=float, sep=",")

    num_sources = len(list(root.iter("ComplexSource")))
    sourceFilename_list = []
    dataType_list = []
    numerical_info_arr = np.full((num_sources, 7), np.nan, dtype=np.float32)

    for row_index, complexSource in enumerate(root.iter("ComplexSource")):
        sourceFilename_list.append(complexSource.find("SourceFilename").text)
        sourceProperties = complexSource.find("SourceProperties")
        dataType_list.append(sourceProperties.attrib["DataType"])
        dstRect = complexSource.find("DstRect")
        nodata = complexSource.find("NODATA")
        nodata_val = float(nodata.text) if nodata is not None else np.nan
        numerical_info_arr[row_index] = np.array(
            [
                int(sourceProperties.attrib["RasterXSize"]),
                int(sourceProperties.attrib["RasterYSize"]),
                float(dstRect.attrib["xOff"]),
                float(dstRect.attrib["yOff"]),
                float(dstRect.attrib["xSize"]),
                float(dstRect.attrib["ySize"]),
                nodata_val,
            ],
            dtype=np.float32,
        )

    df = pd.DataFrame.from_records(
        numerical_info_arr,
        columns=[
            "NODATA",
            "RasterXSize",
            "RasterYSize",
            "xOff",
            "yOff",
            "xSize",
            "ySize",
        ]
    )
    df.insert(0, "dataType", dataType_list)
    df.insert(0, "sourceFilename", sourceFilename_list)
    df["geometry"] = df.apply(lambda row: make_source_geom(vrt_geotrans, row), axis=1)
    df.drop(columns=["xOff", "yOff", "xSize", "ySize"], inplace=True)

    gdf = gpd.GeoDataFrame(df, geometry=df.geometry)
    del df
    gdf.set_crs(crs=CRS.from_wkt(proj_wkt), inplace=True)

    print(f"Writing {num_sources} output features to file: {args.output_file}")
    if args.output_file.endswith(".parquet"):
        output_driver = "Parquet"
    else:
        output_driver = None
    gdf.to_file(args.output_file, driver=output_driver)

    print("Done")


if __name__ == "__main__":
    main()
