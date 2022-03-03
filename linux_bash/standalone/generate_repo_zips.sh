#!/bin/bash

set -uo pipefail

script_file=$(readlink -f "${BASH_SOURCE[0]}")
script_dir=$(dirname "$script_file")
script_name=$(basename "$script_file")
script_args=("$@")


if (( $# < 1 )); then
    echo "Usage: ${script_name} REPO_DIR..."
    exit 1
fi

repo_abspath_arr=()
for path in "${script_args[@]}"; do
    repo_abspath_arr+=( "$(readlink -f "$path")" )
done


git_zip() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null; then
        return
    fi
    repo=$(basename "$(git rev-parse --show-toplevel)")
    commit=$(git rev-parse --short HEAD)
    branch=$(git rev-parse --abbrev-ref HEAD)
    zipfile="../${repo}_${branch}-${commit}.zip"
    echo "Creating zipfile archive of repo HEAD with 'git archive': ${zipfile}"
    git archive --format zip --output "$zipfile" HEAD
}


start_dir="$(pwd)"

for repo_dir in "${repo_abspath_arr[@]}"; do
    if [ ! -d "$repo_dir" ]; then
        echo -e "\nArgument path is not a valid directory, skipping: ${repo_dir}"
        continue
    fi

    echo -e "\nChanging to repo dir: ${repo_dir}"
    if ! cd "$repo_dir"; then
        echo "Failed to 'cd' into directory, skipping"
        continue
    fi

    if git rev-parse --is-inside-work-tree 1>/dev/null; then
        git_zip
    fi
done

echo -e "\nChanging back to starting dir: ${start_dir}"
cd "$start_dir" || return
echo "Done!"
