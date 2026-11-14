#!/usr/bin/env python3
#
# Filename:         zip_package.py
#
# File Description: Zips one submission package for `make zip`: its rtl/, its
#                   tb/ and its SILICLUSTER_README.md, under one top folder
#                   named for the package, and nothing else. File times are
#                   fixed, so the same package always gives the same zip.
#
#                   Usage: zip_package.py <package_dir> <out.zip> <top_folder>
#
# Global variables: None

import pathlib
import sys
import zipfile


def main():

    """
    Purpose: Write the zip, listing what went into it.
    """
    if len(sys.argv) != 4:
        sys.exit("usage: zip_package.py <package_dir> <out.zip> <top_folder>")
    pkg, out, top = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
    files = [pkg / "SILICLUSTER_README.md"] + sorted(p for d in ("rtl", "tb") for p in (pkg / d).rglob("*")
                                                    if p.is_file())
    for f in files:
        if not f.is_file():
            sys.exit(f"zip_package: {f} is missing")
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in files:
            info = zipfile.ZipInfo(f"{top}/{f.relative_to(pkg).as_posix()}", date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            z.writestr(info, f.read_bytes())
    print(f"   {out}: {len(files)} files")


if __name__ == "__main__":
    main()
