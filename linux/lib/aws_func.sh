#!/bin/bash

## Source base functions
source "$(dirname "${BASH_SOURCE[0]}")/bash_base_func.sh"


#aws_cmd() {
#    aws s3 "$@"
#}
#aws_cmd() {
#    aws s3 --profile Developer "$@"
#}

s3path2url() {
    local region='eu-central-1';
    sed -r \
        -e "s|^.*s3://([^/]+)/([^ ]+).*$|https://${region}.console.aws.amazon.com/s3/object/\1\?region=eu-central\-1\&bucketType=general\&prefix=\2|" \
        -e "s|(/[^/\.]+)$|\1/|" \
        -e "s|/$|/\&showversions=false|" \
        -e "s|aws.amazon.com/s3/object/(.*/\&showversions=false)|aws.amazon.com/s3/buckets/\1|"
}


aws_ls1() {
    aws_cmd ls "$@" | rev | cut -d' ' -f1 | rev
}
aws_lsh() {
    aws_cmd ls --human-readable "$@"
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


aws_ls_prefix_size() {
    aws_cmd ls --recursive "$@" | rev | cut -d'/' -f2- | rev | awk '{prefix_size_dict[$4] += $3} END {for (prefix in prefix_size_dict) printf "%s,%s\n", prefix, prefix_size_dict[prefix]}' | sort
}
aws_ls_folder_size() {
    aws_cmd ls --recursive "$@" | awk '
BEGIN {}
{
    file_prefix = $4;
    prefix_size = $3;
    n = split(file_prefix, prefix_parts_arr, "/");
    n -= 1;
    a_prefix = prefix_parts_arr[1];
    prefix_size_dict[a_prefix] += prefix_size;
    for (i=2; i<=n; i++) {
        a_prefix = a_prefix "/" prefix_parts_arr[i];
        prefix_size_dict[a_prefix] += prefix_size;
    }
} END {
    for (prefix in prefix_size_dict) {
        printf "%s,%s\n", prefix, prefix_size_dict[prefix];
    }
}' | sort
}


aws_glob() {
    local rootdir="$(echo "$1" | cut -d"*" -f1 | rev | cut -d"/" -f2- | rev)/"
    local pattern="^${1//\*/'[^/]+'}"
    aws_cmd cp "$rootdir" ./. --recursive --dryrun  | cut -d" " -f3 | grep -Eo "$pattern" | sort -u
}
aws_find() {
    aws_cmd cp "$1" ./. --recursive --dryrun --exclude "*" --include "$2" | cut -d" " -f3
}
aws_resolve_path() {
    if [ "$(string_contains "$SHELLOPTS" 'monitor')" = true ]; then
        local enable_monitor_at_end=true
        set +o monitor
    else
        local enable_monitor_at_end=true
    fi

    local path=$(echo "$1" | sed -r -e 's|\*+|\*|g' -e 's|(/[0-9a-zA-Z]+)\*$|\1|')
    if echo "$path" | grep -Eq '\*/?$'; then
        aws_resolve_path_recursive "$path" false
    else
        aws_resolve_path_recursive "$path" true
    fi

    if [ "$enable_monitor_at_end" = true ]; then
        set -o monitor
    fi
}
aws_resolve_path_recursive() {
    local path="$1"
    local test_children="$2"
    if ! echo "$path" | grep -q '\*'; then
        echo "$path"
    else
        local prefix_str=$(aws_resolve_path_recursive "$(echo "$path" | rev | cut -d'*' -f2- | rev)" false | tr '\n' ' ')
        local prefix_arr
        IFS=' ' read -a prefix_arr <<< "$prefix_str"
        local postfix=$(echo "$path" | rev | cut -d'*' -f1 | rev)
        local prefix
        local echo_cmd='echo'
        if [ "$test_children" = true ]; then
            echo_cmd='aws_ls_s3'
        fi
        local pid_arr=()
        for prefix in "${prefix_arr[@]}"; do
            aws_cmd ls "${prefix%/}/" | grep -E "^[[:space:]]+PRE [^/]+/$" | rev | cut -d' ' -f1 | rev | while IFS= read -r folder; do
                ${echo_cmd} "${prefix%/}/${folder%/}/${postfix#/}"
            done &
            pid_arr+=( $! )
        done
        for pid in "${pid_arr[@]}"; do
            wait "$pid"
        done
    fi
}

aws_cp_multiple_to_dir() {
    local target_dir="$1"; shift
    process_items "aws_cmd cp \${PROCESS_ITEMS_TOKEN} ${target_dir}" false false "$@"
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
