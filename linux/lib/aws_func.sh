#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


#aws_cmd() {
#    aws s3 "$@"
#}
#aws_cmd() {
#    aws s3 --profile Developer "$@"
#}


aws_lsh() {
    aws_cmd ls --human-readable "$@"
}
aws_ls1() {
    aws_cmd ls "$@" | rev | cut -d' ' -f1 | rev
}

aws_glob() {
    local rootdir="$(echo "$1" | cut -d"*" -f1 | rev | cut -d"/" -f2- | rev)/"
    local pattern="^${1//\*/'[^/]+'}"
    aws_cmd cp "$rootdir" ./. --recursive --dryrun  | cut -d" " -f3 | grep -Eo "$pattern" | sort -u
}
aws_find() {
    aws_cmd cp "$1" ./. --recursive --dryrun --exclude "*" --include "$2" | cut -d" " -f3
}


aws_cpr() {
    aws_cmd cp --recursive "$@"
}
aws_cpre() {
    aws_cmd cp --recursive --exclude "*" "$@"
}
aws_cpr_flat_helper() {
    local srcdir="$1"; shift
    local dstdir="$1"; shift
    local tmpdir="./tmp_aws_cpr_flat/"
    aws_cmd cp "$srcdir" "$tmpdir" "$@"
    local status="$?"
    if (( status != 0 )); then
        echo >/dev/stderr "Non-zero exit code from 'aws s3 cp' command (${status}), returning early"
        return
    fi
    mkdir -p "$dstdir"
    find "$tmpdir" -type f -exec mv -t "${dstdir}/" {} +
    find "$tmpdir" -type d -empty -delete
}
aws_cpr_flat() {
    local srcdir="$1"; shift
    local dstdir="$1"; shift
    aws_cpr_flat_helper "$srcdir" "$dstdir" --recursive "$@"
}
aws_cpre_flat() {
    local srcdir="$1"; shift
    local dstdir="$1"; shift
    aws_cpr_flat_helper "$srcdir" "$dstdir" --recursive --exclude "*" "$@"
}


aws_ls_s3() {
    local s3_path="$1"
    local s3_dir_uri=''
    if [ "$(string_endswith "$s3_path" '/')" = true ]; then
        s3_dir_uri="$s3_path"
    else
        s3_dir_uri="$(echo "$s3_path" | rev | cut -d'/' -f2- | rev)/"
    fi
    aws_cmd ls "$s3_path" | rev | cut -d' ' -f1 | rev | grep -Ev '^[[:space:]]*$' | sed -r "s|^|${s3_dir_uri}|"
}
aws_ls_vsis3() {
    local s3_path="$1"
    aws_ls_s3 "$s3_path" | sed -r "s|s3://|/vsis3/|" | grep -Ei "\.tif$"
}


aws_make_vrt() {
    local s3_dir_uri="${1%/}/"; shift
    local output_vrt="$1"; shift

    s3_dir_uri=$(echo "$s3_dir_uri" | sed -r -e 's|^s3@|s3://|' -e 's|@|/|g')
    if [ -z "$output_vrt" ]; then
        output_vrt=$(echo "$s3_dir_uri" | sed -r -e 's|^s3://|s3@|' -e 's|/|@|g' -e 's|@+$||' -e 's|$|\.vrt|')
    fi

    local total=$(aws_ls_vsis3 "$s3_dir_uri" | wc -l)
    if (( total == 0 )); then
        echo "No tiles found"
        return
    fi

    echo "Building VRT for ${total} tiles"
    aws_ls_vsis3 "$s3_dir_uri" | xargs gdalbuildvrt "$@" "$output_vrt"
    if [ -f "$output_vrt" ]; then
        echo "Built VRT: ${output_vrt}"
    else
        echo >/dev/stderr "ERROR: Failed to build VRT"
    fi
}


aws_make_vrt_plus_index() {
    local s3_dir_uri="${1%/}/"; shift
    local output_vrt=$(abspath "$1"); shift

    local s3_dir_vsis3="${s3_dir_uri/'s3://'//vsis3/}"
    local output_shp="${output_vrt/.vrt/.shp}"

    local temp_dir="${output_vrt/.vrt/_tile_vrt}"
    local temp_vrt=''
    if [ ! -d "$temp_dir" ]; then
        mkdir "$temp_dir"
    fi

    local total=$(aws_ls_s3 "$s3_dir_uri" | wc -l)
    echo "Building VRT for ${total} tiles"
    aws_ls_vsis3 "$s3_dir_uri" | while IFS= read -r s3_tif_uri; do
        s3_tif_fname=$(basename "$s3_tif_uri")
        temp_vrt="${temp_dir}/${s3_tif_fname/.tif/.vrt}"
        gdalbuildvrt "$@" "$temp_vrt" "$s3_tif_uri"
    done | tqdm --total "$total"

    local total_built=$(find "$temp_dir" -mindepth 1 -maxdepth 1 -type f -name "*.vrt" | wc -l)
    echo "Built ${total_built}/${total} tile VRT files"
    if (( total_built < total )); then
        echo >/dev/stderr "ERROR: Failed to build VRT file(s)"
    fi

    local cwd=$(pwd)
    cd "$temp_dir"

    echo "Creating footprint of tile VRT files"
    ls *.vrt | xargs gdaltindex "$output_shp"
    if [ -f "$output_vrt" ]; then
        echo "Built footprint: ${output_shp}"
    else
        echo >/dev/stderr "ERROR: Failed to build footprint"
    fi

    echo "Combining tile VRT files"
    ls *.vrt | xargs gdalbuildvrt "$output_vrt"
    if [ -f "$output_vrt" ]; then
        echo "Built VRT: ${output_vrt}"
    else
        echo >/dev/stderr "ERROR: Failed to build combined VRT"
    fi
    echo "Fixing source tile paths in combined VRT"
    perl -pi -e "s|<SourceFilename[^>]*>[^<>]*?([^<>/\.]+)\.vrt</SourceFilename>|<SourceFilename relativeToVRT=\"0\">${s3_dir_vsis3}\1.tif</SourceFilename>|" "$output_vrt"

    cd "$cwd"
    echo "Done"
}


aws_process_ds() {
    local ds_uri="${1%/}/"
#    local ds_name=$(basename "$ds_uri")
    local ds_name=$(echo "$ds_uri" | sed -r -e 's|[:/]+|@|g' -e 's|@+$||')
    local ds_vrt="${ds_name}.vrt"
    local ds_gpkg="${ds_name}.gpkg"
    echo "Working on dataset: ${ds_uri}, ${ds_name}"
    aws_make_vrt "$ds_uri" "$ds_vrt"
    if [ -f "$ds_vrt" ]; then
        gdaltindex_vrt.sh -i "$ds_vrt" -o "$ds_gpkg"
    fi
}

aws_process_ds_root() {
    local root_uri="${1%/}/"
    aws_ls_s3 "$root_uri" | while IFS= read -r ds_uri; do
        if aws_cmd ls "${ds_uri%/}/cogs" >/dev/null; then
            aws_process_ds "${ds_uri%/}/cogs"
        else
            aws_process_ds "$ds_uri"
        fi
    done
}

aws_process_ds_list() {
    local root_uri
    local root_path
    while IFS= read -r root_uri; do
#        root_path=$(s3_to_path "$root_uri")
#        mkdir -p "$root_path"
#        cd "$root_path"
        aws_process_ds_root "$root_uri"
    done
}
