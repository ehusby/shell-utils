#!/usr/bin/env python

import json
import logging
import math
import pyproj
from enum import Enum
from contextlib import suppress
from pathlib import Path
from typing import Any

import geopandas as gpd
import numpy as np
import rasterio as rio
import shapely.geometry
from pydantic import BaseModel, ConfigDict, field_validator
from shapely import get_coordinates

from typer import run

logger = logging.getLogger(__name__)


UNIT_IN_METERS = {
    "meter": 1,
    "centimeter": 0.01,
    "foot": 0.3048,
    "us_survey_foot": 0.3048006096,
}


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


class RasterTindexMetadata(BaseModel):
    model_config: ConfigDict = ConfigDict(use_enum_values=True, extra="allow")  # type: ignore [misc]

    filename: str
    file_ext: str
    filesize: int
    crs: str
    band_count: int
    driver: str
    dtype: str
    nodata: float | int | None
    width: int
    height: int
    transform: str | None = None
    crs_unit: HorizontalUnit | None = None
    center_lat: float | None = None
    center_lon: float | None = None
    origin_x: float | int | None = None
    origin_y: float | int | None = None
    pixel_dx: float | int | None = None
    pixel_dy: float | int | None = None
    pixel_dx_approx_meters: float | int | None = None
    pixel_dy_approx_meters: float | int | None = None
    blockxsize: int | None = None
    blockysize: int | None = None
    tiled: bool | None = None
    compress: str | None = None
    interleave: str | None = None
    LAYOUT: str | None = None
    PREDICTOR: int | bool | None = None
    BIGTIFF: bool
    AREA_OR_POINT: str | None = None
    LAYER_TYPE: str | None = None
    STATISTICS_MINIMUM: float | int | None = None
    STATISTICS_MAXIMUM: float | int | None = None
    STATISTICS_MEAN: float | int | None = None
    STATISTICS_STDDEV: float | int | None = None
    STATISTICS_VALID_PERCENT: float | int | None = None
    STATISTICS_APPROXIMATE: bool

    @field_validator("*", mode="before")
    @classmethod
    def change_str_to_bool(cls, v: Any) -> Any:
        if isinstance(v, str) and v.lower() in ("true", "false", "yes", "no"):
            return v.lower() in ("true", "yes")
        return v


class AllowAnythingModel(BaseModel):
    model_config: ConfigDict = ConfigDict(extra="allow")  # type: ignore [misc]


def get_stats_metadata_dict(ds: rio.DatasetReader, approx_stats: bool = False) -> dict[str, Any]:
    # Calculate GDAL statistics.
    # Suppress `StatisticsError`, which can be caused by raster pixels being all
    # (or nearly all, if `approx_stats=True`) NoData values.
    with suppress(rio.errors.StatisticsError):
        ds.statistics(bidx=1, approx=approx_stats, clear_cache=True)

    # Get GDAL band 1 info, which should contain only the stats info we just calculated.
    # It won't exist if stats calculation failed with suppressed error.
    try:
        stats = ds.tags(1)
    except IndexError:
        return {
            "STATISTICS_APPROXIMATE": approx_stats,
            "STATISTICS_MINIMUM": None,
            "STATISTICS_MAXIMUM": None,
            "STATISTICS_MEAN": None,
            "STATISTICS_STDDEV": None,
            "STATISTICS_VALID_PERCENT": None,
        }

    stats_approximate = str(stats.pop("STATISTICS_APPROXIMATE", approx_stats)).lower() in (
        "yes",
        "true",
    )

    dtype_cast_func = int if np.issubdtype(np.dtype(ds.dtypes[0]), np.integer) else float
    stats_min = dtype_cast_func(stats.pop("STATISTICS_MINIMUM"))
    stats_max = dtype_cast_func(stats.pop("STATISTICS_MAXIMUM"))

    return {
        "STATISTICS_APPROXIMATE": stats_approximate,
        "STATISTICS_MINIMUM": stats_min,
        "STATISTICS_MAXIMUM": stats_max,
        **{key: float(value) for key, value in stats.items()},
    }


def get_geoseries_centroid(geoseries: gpd.GeoSeries) -> gpd.GeoSeries:
    source_crs = geoseries.crs
    try:
        geoseries_equal_area = geoseries.to_crs("+proj=cea")
        if not geoseries_equal_area.values[0].is_valid:
            raise ValueError(
                "Failed to reproject geometry to Equal Area Cylindrical projection ('+proj=cea')"
            )
        return geoseries_equal_area.centroid.to_crs(source_crs)
    except Exception:
        logger.exception(
            "Hit the follwing error when reprojecting geometry to equal area for centroid calculation, falling back to regular centroid calculation"
        )
        return geoseries.centroid


def write_raster_tindex_geojson(
    raster_path: Path,
    *,
    output_path: Path | None = None,
    approx_stats: bool = True,
    extra_data_str: str | None = None,
    missing_crs_epsg_code: int | None = None,
    set_missing_crs_in_meta: bool = False,
    add_fieldname_prefix: str | None = "_",
    add_fieldname_prefix_to_extra_data: bool = False,
) -> Path:
    """
    Create a GeoJSON tile index ("tindex") file representation of the
    input raster containing a single feature, with the raster bounding box
    as geometry and extracted raster metadata as attribute fields.
    """
    extra_data = json.loads(extra_data_str) if extra_data_str else None

    raster_path = Path(raster_path)
    output_path = raster_path.with_suffix(".geojson") if output_path is None else Path(output_path)
    if output_path.is_file() and output_path.samefile(raster_path):
        raise ValueError("Default path for output file is the same as input raster path")

    if add_fieldname_prefix is None:
        add_fieldname_prefix = ""

    with open(raster_path, "rb") as fo:
        is_bigtiff = fo.read(3) == b"II+"

    with rio.open(raster_path) as ds:
        # Get raster full extent bounding box
        bbox = shapely.geometry.box(*ds.bounds)

        # Get CRS to use for calculations
        use_crs = ds.crs or (rio.CRS.from_epsg(missing_crs_epsg_code) if missing_crs_epsg_code else None)

        # Calculate statistics and get GDAL stats metadata
        stats = get_stats_metadata_dict(ds, approx_stats=approx_stats)

        # Get some base GDAL meta info
        try:
            gdal_meta_tag0 = ds.tags(0)
        except IndexError:
            gdal_meta_tag0 = {}

        # Get raster origin coords and pixel resolution
        # https://gdal.org/tutorials/geotransforms_tut.html
        if ds.transform:
            gdal_gt = ds.transform.to_gdal()
            origin_x = gdal_gt[0]
            origin_y = gdal_gt[3]
            pixel_dx = abs(gdal_gt[1])
            pixel_dy = abs(gdal_gt[5])
        else:
            origin_x = None
            origin_y = None
            pixel_dx = None
            pixel_dy = None

        # Get CRS and pixel spacing information
        crs_unit = None
        pixel_dx_meters = None
        pixel_dy_meters = None
        if use_crs and pixel_dx and pixel_dy:
            crs_unit = get_crs_horizontal_unit(pyproj.CRS(use_crs))
            if crs_unit == "degree":
                pixel_dx_meters, pixel_dy_meters = get_approx_spacing_from_degrees_to_meters(
                    bbox_deg=bbox,
                    dx_deg=pixel_dx,
                    dy_deg=pixel_dy,
                )
            elif crs_unit in UNIT_IN_METERS:
                pixel_dx_meters = pixel_dx * UNIT_IN_METERS[crs_unit]
                pixel_dy_meters = pixel_dy * UNIT_IN_METERS[crs_unit]

        # Assemble metadata to be exported to the table
        # For metadata accessed through `ds.tags(ns="NAME")`, see background info:
        # https://gdal.org/user/raster_data_model.html
        export_meta = {
            "filename": raster_path.name,
            "file_ext": "".join(raster_path.suffixes),
            "filesize": raster_path.stat().st_size,
            "band_count": ds.meta.get("count", None),
            "crs": str(ds.crs) if ds.crs else None,
            "compress": None,  # Overridden by `ds.meta` item if it exists, or gdal 'COMPRESSION' metadata
            **ds.meta,
            "crs_unit": crs_unit,
            "center_lat": None,  # Set after bbox reprojection to WGS84
            "center_lon": None,  # Set after bbox reprojection to WGS84
            "origin_x": origin_x,
            "origin_y": origin_y,
            "pixel_dx": pixel_dx,
            "pixel_dy": pixel_dy,
            "pixel_dx_approx_meters": pixel_dx_meters,
            "pixel_dy_approx_meters": pixel_dy_meters,
            **ds.profile,
            **ds.tags(ns="IMAGE_STRUCTURE"),
            **ds.tags(ns="IMAGERY"),
            "BIGTIFF": is_bigtiff,
            **gdal_meta_tag0,
            **stats,
        }

        # Set CRS if missing and setting the meta is desired
        # Ensure the CRS is converted to a string representation (e.g. "EPSG:4326")
        if export_meta["crs"] is None:
            if set_missing_crs_in_meta:
                export_meta["crs"] = str(use_crs)
        else:
            export_meta["crs"] = str(export_meta["crs"])

        # Remove/modify unnecessary items (especially if the values are long strings)
        if not ds.transform:
            export_meta["transform"] = "absent"
        elif ds.transform[1] == 0 and ds.transform[3] == 0:
            # This should be true of all standard "north up" images, and
            # we already record the other geotransform items in other fields.
            # https://gdal.org/tutorials/geotransforms_tut.html
            export_meta["transform"] = "present"

        # Remove UPPERCASE keys duplicated in GDAL meta
        export_meta_keys = list(export_meta.keys())
        for key in export_meta_keys:
            if key != key.lower() and key.lower() in export_meta:
                export_meta.pop(key)
        if export_meta["compress"] is None:
            export_meta["compress"] = export_meta.pop("COMPRESSION", None)
        else:
            export_meta.pop("COMPRESSION", None)

        # Rename fields
        export_meta.pop("count", None)  # Already set "band_count" in `export_meta` above

        added_extra_data = False

        # Add prefix to standard fields if desired
        if add_fieldname_prefix:
            if extra_data and add_fieldname_prefix_to_extra_data:
                export_meta = {**export_meta, **extra_data}
                added_extra_data = True
            export_meta = {f"{add_fieldname_prefix}{k}": v for k, v in export_meta.items()}

        # Add extra data
        if extra_data and not added_extra_data:
            export_meta = {**export_meta, **extra_data}

        # Run the metadata through a pydantic model for some sanitizing
        export_meta_model = (
            AllowAnythingModel(**export_meta) if add_fieldname_prefix else RasterTindexMetadata(**export_meta)
        )

        # Assemble data frame with raster bounding box and metadata,
        # then write out to GeoJSON file.
        gdf = gpd.GeoDataFrame.from_dict(
            data={
                **{k: [v] for k, v in export_meta_model.model_dump().items()},
                **(
                    {k: [v] for k, v in export_meta_model.model_extra.items()}
                    if export_meta_model.model_extra is not None
                    else {}
                ),
                # Set geometry in the `data` arg dict because there may be a bug in
                # setting through the `geometry` arg when `crs` is None.
                "geometry": bbox,
            },
            crs=use_crs,
        )

        # If the raster has a CRS, convert the bbox geometry to WGS84 and set derived metadata values
        if gdf.crs:
            gdf.to_crs(crs=rio.CRS.from_epsg(4326), inplace=True)
            gdf[f"{add_fieldname_prefix}center_lon"], gdf[f"{add_fieldname_prefix}center_lat"] = (
                get_coordinates(get_geoseries_centroid(gdf.geometry).values[0]).flatten()
            )

        # Write out the geodataframe to file
        gdf.reset_index(drop=True, inplace=True)
        try:
            if output_path.suffix.lower() in (".parquet", ".geoparquet"):
                gdf.to_parquet(str(output_path))
            else:
                gdf.to_file(
                    str(output_path),
                    driver="GeoJSON" if output_path.suffix.lower() in (".json", ".geojson") else None,
                )
        except Exception:
            output_path.unlink(missing_ok=True)
            raise

        return output_path


if __name__ == "__main__":
    run(write_raster_tindex_geojson)
