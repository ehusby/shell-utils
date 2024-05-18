#!/bin/bash


tif_is_bigtiff() {
    local resp=$(head -c 3 "$1")
    if [ "$resp" = "II+" ]; then
        echo true
        return 0
    elif [ "$resp" = "II*" ]; then
        echo false
        return 1
    else
        echo >&2 "Unhandled response from 'head -c 3 FILE': '${resp}', should be 'II+' or 'II*'"
        echo false
        return 1
    fi
}


gdalinfo_filelist_to_vrt() {
    perl -pe 's|^(.*?)([^/]+?)(:?\..*)?$|    <OGRVRTLayer name="wgs84Extent">\n        <SrcDataSource>\1\2\3</SrcDataSource>\n    </OGRVRTLayer>|;' | \
    sed -e '1s|^|<OGRVRTDataSource>\n|' -e '$a</OGRVRTDataSource>'
}


ogrinfo_centroid_wgs84() {
    local geojson_path="$1"
    local ogrinfo_temp="$2"
    local remove_ogrinfo_temp=''
    if [ -z "$ogrinfo_temp" ]; then
        ogrinfo_temp="$(mktemp).json"
        remove_ogrinfo_temp=true
    else
        remove_ogrinfo_temp=false
    fi
    if [ ! -s "$ogrinfo_temp" ]; then
        local geojson_temp="$(mktemp).json"
        ogr2ogr -f GeoJSON -t_srs "EPSG:4326" "$geojson_temp" "$geojson_path"
        local geojson_filename=$(basename "$geojson_path")
        ogrinfo "$geojson_temp" "${geojson_filename%.*}" > "$ogrinfo_temp"
        rm "$geojson_temp"
    fi
    local coords=$(grep "POLYGON ((" "$ogrinfo_temp" | tr ',' '\n' | grep -Eo "\-?[0-9].*[0-9]")
    local coords_count=$(echo "$coords" | wc -l)
    local coords_sum=$(echo "$coords" | sum_cols)
    echo $(echo "scale=10; $(echo "$coords_sum" | cut -d' ' -f1) / ${coords_count}" | bc) $(echo "scale=3; $(echo "$coords_sum" | cut -d' ' -f2) / ${coords_count}" | bc)
    if [ "$remove_ogrinfo_temp" = true ]; then
        rm "$ogrinfo_temp"
    fi
}
gdalinfo_centroid_wgs84() {
    local raster_path="$1"
    local gdalinfo_tmp="$2"
    local remove_gdalinfo_tmp=''
    if [ -z "$gdalinfo_tmp" ]; then
        gdalinfo_tmp="$(mktemp).json"
        remove_gdalinfo_tmp=true
    else
        remove_gdalinfo_tmp=false
    fi
    if [ ! -s "$gdalinfo_tmp" ]; then
        gdalinfo -json -nogcp -nomd -norat -noct -nofl "$raster_path" > "$gdalinfo_tmp"
    fi
    local coords=$(awk '/"wgs84Extent":{/,/},/' "$gdalinfo_tmp" | awk '/"coordinates":\[/,/},/' | grep '[0-9]' | sed -r 's|\s+||g' | tr '\n' '%' | sed 's|,%| |g' | tr '%' '\n')
    local coords_count=$(echo "$coords" | wc -l)
    local coords_sum=$(echo "$coords" | sum_cols)
    echo $(echo "scale=10; $(echo "$coords_sum" | cut -d' ' -f1) / ${coords_count}" | bc) $(echo "scale=3; $(echo "$coords_sum" | cut -d' ' -f2) / ${coords_count}" | bc)
    if [ "$remove_gdalinfo_tmp" = true ]; then
        rm "$gdalinfo_tmp"
    fi
}


gdalinfo_closest_utm_zone() {
    local ds_path="$1"
    local gdalinfo_tmp="$2"
    local degrees_lon degrees_lat
    local centroid_fn
    if [[ $ds_path =~ .*\.tif$ ]]; then
        centroid_fn='gdalinfo_centroid_wgs84'
    else
        centroid_fn='ogrinfo_centroid_wgs84'
    fi
    read -r degrees_lon degrees_lat <<<$($centroid_fn "$ds_path" "$gdalinfo_tmp")
    local utm_zone_num=$(echo "scale=10; (${degrees_lon} - (-180)) / 6 + 0.5" | bc | xargs printf "%.0f")
    local utm_epsg
    if (( utm_zone_num == 0 )); then
        utm_zone_num=1
    fi
    if (( $(printf "%.0f" "$degrees_lat") >= 0 )); then
        utm_name=$(printf "utm%02dn" "$utm_zone_num")
        utm_epsg=$(( 32600 + utm_zone_num ))
    else
        utm_name=$(printf "utm%02ds" "$utm_zone_num")
        utm_epsg=$(( 32700 + utm_zone_num ))
    fi
    echo ${utm_name} ${utm_epsg}
}


gdalinfo_approx_resolution() {
    local raster_path="$1"
    local gdalinfo_tmp="$2"

    local remove_gdalinfo_tmp=''
    if [ -z "$gdalinfo_tmp" ]; then
        gdalinfo_tmp="$(mktemp).json"
        remove_gdalinfo_tmp=true
    else
        remove_gdalinfo_tmp=false
    fi
    local gdalinfo_utm_tmp="$(mktemp).json"

    local utm_name utm_epsg
    read -r utm_name utm_epsg <<<$(gdalinfo_closest_utm_zone "$raster_path" "$gdalinfo_tmp")
    ogr2ogr -f GeoJSON -t_srs "EPSG:${utm_epsg}" "$gdalinfo_utm_tmp" "$gdalinfo_tmp"
    echo "$gdalinfo_tmp"
    if [ ! -f "$gdalinfo_utm_tmp" ]; then
        echo "0 0"
        if [ "$remove_gdalinfo_tmp" = true ]; then
            rm "$gdalinfo_tmp"
        fi
        return
    fi

    local utm_coords=$(grep '"type": "Polygon", "coordinates"' "$gdalinfo_utm_tmp" | sed -r -e 's|^.*"coordinates":||' -e 's|\],|%|g' | tr '%' '\n' | sed -r -e 's|\[||g' -e 's|\]||g' -e 's|[{}]||g' -e 's|\s+||g')
    local utm_coords_by_line
    IFS=$'\n' read -d '' -r -a utm_coords_by_line < <(echo "$utm_coords")
    local ul_x=$(echo "${utm_coords_by_line[0]}" | cut -d',' -f1)
    local ul_y=$(echo "${utm_coords_by_line[0]}" | cut -d',' -f2)
    local ll_x=$(echo "${utm_coords_by_line[1]}" | cut -d',' -f1)
    local ll_y=$(echo "${utm_coords_by_line[1]}" | cut -d',' -f2)
    local lr_x=$(echo "${utm_coords_by_line[2]}" | cut -d',' -f1)
    local lr_y=$(echo "${utm_coords_by_line[2]}" | cut -d',' -f2)
#    local ur_x=$(echo "${utm_coords_by_line[3]}" | cut -d',' -f1)
#    local ur_y=$(echo "${utm_coords_by_line[3]}" | cut -d',' -f2)
    local extent_x=$(echo "scale=10; sqrt((${lr_x}-${ll_x})^2 + (${lr_y}-${ll_y})^2)" | bc)
    local extent_y=$(echo "scale=10; sqrt((${ul_y}-${ll_y})^2 + (${ul_x}-${ll_x})^2)" | bc)

    local raster_size=$(awk '/^  "size":\[/,/\],/' "$gdalinfo_tmp" | grep '[0-9]' | sed -r 's|\s+||g' | tr -d '\n')
    local size_x=$(echo "$raster_size" | cut -d',' -f1)
    local size_y=$(echo "$raster_size" | cut -d',' -f2)

    local res_x=$(echo "scale=3; ${extent_x} / ${size_x}" | bc)
    local res_y=$(echo "scale=3; ${extent_y} / ${size_y}" | bc)

    echo ${res_x} ${res_y}

#    rm "$gdalinfo_utm_tmp"
#    if [ "$remove_gdalinfo_tmp" = true ]; then
#        rm "$gdalinfo_tmp"
#    fi
}


gdalinfo_cog_overview_preview_level() {
    local raster_path="$1"
    local preview_max_res="$2"
    local size_at_level="${3:-}"

    local gdalinfo_tmp="$(mktemp).json"

    local level size
    if [ -n "$size_at_level" ]; then
        gdalinfo -json -nogcp -nomd -norat -noct -nofl "$raster_path" > "$gdalinfo_tmp"
        level="$size_at_level"
    else
        local approx_res_x approx_res_y
        read -r approx_res_x approx_res_y <<<$(gdalinfo_approx_resolution "$raster_path" "$gdalinfo_tmp")
        local res_max=$(echo "if(${approx_res_x}>${approx_res_y}) ${approx_res_x} else ${approx_res_y}" | bc)
        local level=$(echo "scale=10; l(${preview_max_res}/${res_max})/l(2) - 0.5" | bc -l | xargs printf '%.0f')
        if (( level < 1 )); then
            level=0
        else
            local nlevels=$(awk '/"overviews":\[/,/\],/' "$gdalinfo_tmp" | grep -E '"size":\[' | wc -l)
            if (( level > nlevels )); then
                level="$nlevels"
            fi
            # Overview levels beyond 3 sometimes can't be trusted
            if (( level > 3 )); then
                level=3
            fi
        fi
    fi

    if (( level == 0 )); then
        size=$(grep -E -m1 -A2 '"size":\[' "$gdalinfo_tmp" | tail -n2 | sed -r -e 's|\s+||g' -e 's|,| |' | tr -d '\n')
    else
        size=$(awk '/"overviews":\[/,/\],/' "$gdalinfo_tmp" | grep -E -m${level} -A2 '"size":\[' | tail -n2 | sed -r -e 's|\s+||g' -e 's|,| |' | tr -d '\n')
    fi

    echo "${level} ${size}"

    rm "$gdalinfo_tmp"
}
