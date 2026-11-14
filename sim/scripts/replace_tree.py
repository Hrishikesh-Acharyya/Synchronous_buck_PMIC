#!/usr/bin/env python3
#
# Filename:         replace_tree.py
#
# File Description: Replaces one folder with a copy of another, for
#                   `make submissions`: a package's rtl/ becomes a copy of the
#                   Verilog tree it is built from. The destination must be a
#                   folder named rtl inside a folder that holds a
#                   SILICLUSTER_README.md - a submission package - so a wrong
#                   argument cannot remove anything else.
#
#                   Usage: replace_tree.py <source_dir> <package>/rtl
#
# Global variables: None

import pathlib
import shutil
import sys


def main():

    """
    Purpose: Check both arguments, then replace the destination with a copy
             of the source.
    """
    if len(sys.argv) != 3:
        sys.exit(__doc__ or "usage: replace_tree.py <source_dir> <package>/rtl")
    src, dst = pathlib.Path(sys.argv[1]).resolve(), pathlib.Path(sys.argv[2]).resolve()
    if not src.is_dir():
        sys.exit(f"replace_tree: no source folder {src}")
    if dst.name != "rtl" or not (dst.parent / "SILICLUSTER_README.md").is_file():
        sys.exit(f"replace_tree: {dst} is not the rtl folder of a submission package - nothing changed")
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


if __name__ == "__main__":
    main()
