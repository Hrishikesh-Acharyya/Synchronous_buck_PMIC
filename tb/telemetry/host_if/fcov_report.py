#!/usr/bin/env python3
#
# Filename:         fcov_report.py
#
# File Description: Merge and report the functional coverage (cocotb-coverage
#                   covergroups) that random_walk exports per run when FCOV_XML
#                   is set.
#
#                   Usage: fcov_report.py merge <merged.xml> <run.xml>...
#                            merge per-run databases into one; prints nothing
#                          fcov_report.py report <merged.xml>
#                            one line per coverpoint / cross with its bins hit,
#                            then every bin no run reached
#                          fcov_report.py summary <merged.xml>
#                            one line: bins hit across all coverpoints, and the
#                            empty-bin count - for result tables
#
#                   The XML is cocotb-coverage's export_to_xml format: nested
#                   elements per covergroup, a leaf per coverpoint or cross
#                   with one child per bin carrying bin= and hits=.
#
# Global variables: None

import sys
import xml.etree.ElementTree as ET


def leaves(xml_path):

    """
    Purpose: Every coverpoint and cross in the database, as
             (name, [(bin, hits), ...]). A leaf is an element whose children
             all carry a bin= attribute.
    """
    root = ET.parse(xml_path).getroot()
    found = []
    for element in root.iter():
        children = list(element)
        if children and all("bin" in child.attrib for child in children):
            name = element.attrib.get("abs_name", element.tag).removeprefix("top.")
            bins = [(child.attrib["bin"], int(child.attrib.get("hits", "0"))) for child in children]
            found.append((name, bins))
    return found


def merge(out_path, run_paths):

    """
    Purpose: Merge per-run databases with cocotb-coverage's own merge, so bin
             definitions are taken from the files rather than re-declared here.
    """
    from cocotb_coverage.coverage import merge_coverage
    merge_coverage(lambda *args: None, out_path, *run_paths)


def report(xml_path):

    """
    Purpose: Readable listing: coverage per coverpoint / cross, then the bins
             at zero - the to-do list for random_walk's constraints.
    """
    empty = []
    for name, bins in leaves(xml_path):
        hit = sum(1 for _, hits in bins if hits > 0)
        print(f"  {name:<40} {hit:>3} of {len(bins):<3} bins hit")
        empty += [f"  {name}: {label}" for label, hits in bins if hits == 0]
    print("empty bins:")
    print("\n".join(empty) if empty else "  no empty bins")


def summary(xml_path):

    """
    Purpose: One line for a result table: bins hit over bins total, across
             every coverpoint and cross.
    """
    all_bins = [hits for _, bins in leaves(xml_path) for _, hits in bins]
    hit = sum(1 for hits in all_bins if hits > 0)
    print(f"{hit} {len(all_bins)}")


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "merge":
        merge(sys.argv[2], sys.argv[3:])
    elif len(sys.argv) == 3 and sys.argv[1] == "report":
        report(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "summary":
        summary(sys.argv[2])
    else:
        sys.exit("usage: fcov_report.py merge <out.xml> <run.xml>... | report <xml> | summary <xml>")
