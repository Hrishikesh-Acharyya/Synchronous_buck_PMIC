#!/usr/bin/env python3
#
# Filename:         collect.py
#
# File Description: Copies the outcome of the place-and-route runs from the
#                   scratch folder work/ into results/, which is committed:
#                   per run, metrics.txt and the timing, power, skew, DRC and
#                   congestion reports as they are, and the flow log, routed
#                   DEF and post-route netlist gzipped; work/summary.tsv; and
#                   the layout pictures of the runs named in IMAGES.
#                   results/ is rebuilt from scratch each time, so it never
#                   mixes the runs of two netlists.
#
#                   Usage: ./collect.py      (after run_pnr.sh and summarize.py)
#
# Global variables: HERE, WORK, RESULTS, REPORTS, GZIPPED, IMAGES - see below

import gzip
import pathlib
import shutil
import sys

# HERE / WORK / RESULTS: this folder, the scratch runs, the committed copy
HERE = pathlib.Path(__file__).resolve().parent
WORK = HERE / "work"
RESULTS = HERE / "results"
# REPORTS: files copied as they are, when a run produced them
REPORTS = ("metrics.txt", "timing_max.rpt", "timing_min.rpt", "power.rpt", "skew.rpt", "drc.rpt",
           "congestion.rpt")
# GZIPPED: large files stored compressed
GZIPPED = ("flow.log", "final.def", "final.v")
# IMAGES: run folder -> picture name in results/images/
IMAGES = {"tel0_180x115_m2.0": "reduced_180x115_border2um.png",
          "tel0_180x115_m10.0": "reduced_180x115_border10um.png",
          "tel0_180x90_m2.0": "reduced_180x90_border2um.png",
          "tel1_180x288_m2.0": "full_180x288_border2um.png",
          "tel1_180x345_m2.0": "full_180x345_border2um.png"}


def main():

    """
    Purpose: Rebuild results/ from work/.
    """
    runs = sorted(p for p in (WORK / "runs").iterdir() if (p / "metrics.txt").is_file())
    if not runs:
        sys.exit("collect: no finished run under work/runs - run run_pnr.sh first")
    if RESULTS.exists():
        shutil.rmtree(RESULTS)
    (RESULTS / "images").mkdir(parents=True)
    for run in runs:
        out = RESULTS / "runs" / run.name
        out.mkdir(parents=True)
        for name in REPORTS:
            if (run / name).is_file():
                shutil.copy(run / name, out / name)
        for name in GZIPPED:
            if (run / name).is_file():
                with open(run / name, "rb") as src, gzip.GzipFile(out / (name + ".gz"), "wb", mtime=0) as dst:
                    shutil.copyfileobj(src, dst)
        if run.name in IMAGES and (run / "layout.png").is_file():
            shutil.copy(run / "layout.png", RESULTS / "images" / IMAGES[run.name])
    if (WORK / "summary.tsv").is_file():
        shutil.copy(WORK / "summary.tsv", RESULTS / "summary.tsv")
    print(f"collect: {len(runs)} runs in {RESULTS}")


if __name__ == "__main__":
    main()
