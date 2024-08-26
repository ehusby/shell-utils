#!/usr/bin/env python

import os
import re
import subprocess
from pathlib import Path

from typer import run


def xyz2tif(
    xyz_path_: Path,
    crs: int,
    *,
    tif_path: Path | None = None,
    src_nodata_values: list[float] | None = None,
    dst_nodata_value: float = -9999,
    src_column_order: str = "xyz",
) -> Path:
    xyz_path = Path(xyz_path_)
    tif_path = xyz_path.with_suffix(".tif") if tif_path is None else Path(tif_path)

    try:
        src_column_order = src_column_order.lower()
        if len(src_column_order) == 3 and all(c in src_column_order for c in "xyz"):
            pass
        else:
            raise ValueError(f"Source column order '{src_column_order}' not valid")

        # Determine the order of column indices that map from source column order to
        # XYZ order when printed in AWK command.
        awk_column_order = r"\$" + r", \$".join(
            [
                str(i)
                for _, i in sorted(
                    list(zip(src_column_order, range(1, len(src_column_order) + 1)))
                )
            ]
        )

        # Always check for these string-type nodata values (case-insensitive)
        sed_nodata_patterns: set[str] = {
            "",
            "na",
            "n/a",
            "nan",
            "null",
            "nil",
            "none",
        }

        # Add additional (numeric or other string-type) nodata values from arguments
        if src_nodata_values:
            for v in src_nodata_values:
                sed_nodata_patterns.add(str(v))

                try:
                    if float(v) == int(v):
                        # match "-9999"
                        sed_nodata_patterns.add(str(int(v)))
                        # match "-9999.0"; period with/without trailing zeros
                        sed_nodata_patterns.add(f"{int(v)}.0*")
                    else:
                        # match "-9999.9"; decimal number with/without trailing zeros
                        sed_nodata_patterns.add(f"{float(v)}0*")

                    sci_notation = "{:.99e}".format(float(v))

                    # Allow "X.Xe(+/-)0N"; power number N with/without leading zeros
                    sci_notation = re.sub(r"e([+-])0*", r"e\g<1>0*", sci_notation)

                    # Allow "X.Xe+0N" or "X.Xe0N"; positive power number N optional "+" sign
                    sci_notation = re.sub(r"e\+", r"e+?", sci_notation)

                    # Escape +/- sign for regex
                    sci_notation = re.sub(r"e([+-])", r"e\\\g<1>", sci_notation)

                    # match "-9.99900e+03"; coefficient with/without trailing zeros
                    sed_nodata_patterns.add(re.sub(r"0*e", r"0*e", sci_notation))
                    if re.search(r"\.0*e", sci_notation):
                        # match "-9e+03"; integer coefficient with no decimals
                        sed_nodata_patterns.add(re.sub(r"\.0*e", r"e", sci_notation))

                except ValueError:
                    pass

        sed_nodata_patterns_str = "|".join(sorted(list(sed_nodata_patterns)))

        cmd = rf"""
sed -r -e 's/^[\t ]+//' -e 's/["'"'"']+//g' "{xyz_path}" \
    | awk -F '[,;:\r\t |]+' '{{printf "%s %s %s\n", '"{awk_column_order}"'}}' \
    | sed -r 's; ({sed_nodata_patterns_str})$; {dst_nodata_value};I' \
    | grep -E -i '^[-+]?[0-9][0-9\.e\+-]* [-+]?[0-9][0-9\.e\+-]* ' \
    | sort -k2r,2r -k1,1 -S 50% --parallel=4 \
    | \
gdalwarp -overwrite \
    -of GTiff \
    -ot Float32 \
    -s_srs "EPSG:{crs}" \
    -dstnodata "{dst_nodata_value}" \
    -oo COLUMN_ORDER=XYZ \
    -co COMPRESS=LZW -co TILED=YES -co BIGTIFF=YES \
    '/vsistdin?buffer_limit=10000000000/' \
    "{tif_path}"
"""

        subprocess.run(cmd, shell=True)

    except Exception:
        if os.path.isfile(tif_path):
            os.remove(tif_path)
        raise

    return tif_path


if __name__ == "__main__":
    run(xyz2tif)
