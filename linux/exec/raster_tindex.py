import math
from contextlib import suppress
from pathlib import Path
from typing import Any

import geopandas as gpd
import rasterio as rio
from pyproj import CRS
from shapely import box, get_coordinates

from typer import run


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


def write_raster_tindex_geojson(
    raster_path: Path,
    *,
    geojson_path: Path = None,
    approx_stats: bool = True,
    extra_data: dict[str, Any] | None = None,
    missing_crs_epsg_code: int | None = None,
    set_missing_crs_in_meta: bool = False,
    add_fieldname_prefix: str | None = None,
    add_fieldname_prefix_to_extra_data: bool = False,
) -> Path:
    """
    Create a GeoJSON tile index ("tindex") file representation of the
    input raster containing a single feature, with the raster bounding box
    as geometry and extracted raster metadata as attribute fields.
    """
    raster_path = Path(raster_path)
    geojson_path = (
        raster_path.with_suffix(".geojson")
        if geojson_path is None
        else Path(geojson_path)
    )
    if geojson_path.is_file() and geojson_path.samefile(raster_path):
        raise ValueError(
            "Default path for output GeoJSON is the same as input raster path"
        )

    with open(raster_path, "rb") as fo:
        is_bigtiff = fo.read(3) == b"II+"

    with rio.open(raster_path) as ds:
        # Get raster full extent bounding box
        bbox = box(*ds.bounds)

        # Get CRS to use for calculations
        use_crs = ds.crs or (
            rio.CRS.from_epsg(missing_crs_epsg_code) if missing_crs_epsg_code else None
        )

        # Calculate statistics
        with suppress(rio.errors.StatisticsError):
            ds.statistics(bidx=1, approx=approx_stats, clear_cache=True)

        # Get some base GDAL meta info
        try:
            gdal_meta_tag0 = ds.tags(0)
        except IndexError:
            gdal_meta_tag0 = {}

        # Get GDAL band 1 stats info, standardize STATISTICS_APPROXIMATE value and location in dict
        try:
            stats = ds.tags(1)
        except IndexError:
            stats = {}
        stats["STATISTICS_APPROXIMATE"] = str(
            stats.get("STATISTICS_APPROXIMATE", approx_stats)
        ).lower() in (
            "yes",
            "true",
        )
        stats["STATISTICS_APPROXIMATE"] = stats.pop("STATISTICS_APPROXIMATE")

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
            crs_unit = (
                CRS(use_crs).axis_info[0].unit_name.lower().replace("metre", "meter")
            )
            if crs_unit == "degree":
                center_lon, center_lat = get_coordinates(bbox.centroid).flatten()
                pixel_dx_meters = round(
                    distance_between_coordinates_meters(
                        center_lat,
                        center_lon - pixel_dx,
                        center_lat,
                        center_lon + pixel_dx,
                    )
                    / 2,
                    4,
                )
                pixel_dy_meters = round(
                    distance_between_coordinates_meters(
                        center_lat - pixel_dy,
                        center_lon,
                        center_lat + pixel_dy,
                        center_lon,
                    )
                    / 2,
                    4,
                )

        # Assemble metadata to be exported to the table
        # For metadata accessed through `ds.tags(ns="NAME")`, see background info:
        # https://gdal.org/user/raster_data_model.html
        export_meta = {
            "filename": raster_path.name,
            "file_ext": "".join(raster_path.suffixes),
            "crs": ds.meta.get(
                "crs", None
            ),  # Populate this field in case source raster has no "crs" meta tag
            "band_count": ds.meta.get("count", None),
            **ds.meta,
            "crs_unit": crs_unit,
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
        if export_meta["crs"] is None and set_missing_crs_in_meta:
            export_meta["crs"] = use_crs

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
        if "compress" in export_meta:
            export_meta.pop("COMPRESSION", None)
        else:
            export_meta["compress"] = export_meta.pop("COMPRESSION", None)

        # Rename fields
        export_meta.pop(
            "count", None
        )  # Already set "band_count" in `export_meta` above

        added_extra_data = False

        # Add prefix to standard fields if desired
        if add_fieldname_prefix:
            if extra_data and add_fieldname_prefix_to_extra_data:
                export_meta = {**export_meta, **extra_data}
                added_extra_data = True
            export_meta = {
                f"{add_fieldname_prefix}{k}": v for k, v in export_meta.items()
            }

        # Add extra data
        if extra_data and not added_extra_data:
            export_meta = {**export_meta, **extra_data}

        def _parse_meta_value(_token: Any) -> str | float | bool | None:
            if _token is None:
                return None
            _token_str = str(_token)
            try:
                return float(_token_str)
            except (TypeError, ValueError):
                if _token_str.lower() in ("true", "false", "yes", "no"):
                    return _token_str.lower() in ("true", "yes")
                return _token_str

        # Assemble data frame with raster bounding box and metadata,
        # then write out to GeoJSON file.
        gdf = gpd.GeoDataFrame.from_dict(
            data={
                **{k: [_parse_meta_value(v)] for k, v in export_meta.items()},
                # Set geometry in the `data` arg dict because there may be a bug in
                # setting through the `geometry` arg when `crs` is None.
                "geometry": bbox,
            },
            crs=use_crs,
        )
        if gdf.crs:
            gdf.to_crs(crs=rio.CRS.from_epsg(4326), inplace=True)
        gdf.reset_index(drop=True, inplace=True)
        try:
            gdf.to_file(str(geojson_path), driver="GeoJSON")
        except Exception:
            geojson_path.unlink(missing_ok=True)
            raise

        return geojson_path


if __name__ == "__main__":
    run(write_raster_tindex_geojson)
