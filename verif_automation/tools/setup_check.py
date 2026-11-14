#!/usr/bin/env python3
#
# Filename:         setup_check.py
#
# File Description: Checks that the tools verif_automation's commands need are
#                   installed, and says how to get each one that is missing.
#                   It only looks: nothing is installed or changed.
#
#                   Needed by everything: Python 3.8+, git, make.
#                   Needed by mutation testing: Verilator (the sim/ targets),
#                   and cocotb for the two modules tested by the host_if
#                   suite.
#                   Needed by the AI steps (make triage, make judge): the
#                   Claude Code command, logged in.
#
# Global variables: CHECKS - what is looked for

import shutil
import subprocess
import sys

# CHECKS: (name, command that prints a version, what needs it, how to get it)
CHECKS = [
    ("git", ["git", "--version"], "everything", "sudo apt install git"),
    ("make", ["make", "--version"], "everything", "sudo apt install make"),
    ("verilator", ["verilator", "--version"], "mutation testing (the sim/ targets)",
     "see the repository README - the version the sim/ Makefile was written for is 5.x"),
    ("cocotb", [sys.executable, "-c", "import cocotb; print('cocotb', cocotb.__version__)"],
     "mutation testing of reg_file and spi_slave (the host_if suite)", "pip install cocotb cocotb-coverage"),
    ("claude", ["claude", "--version"], "the AI steps: make ai_mutants, make judge",
     "curl -fsSL https://claude.ai/install.sh | bash   (then open a new terminal and run: claude)"),
]


def main():

    """
    Purpose: Run each check and print one line per tool.
    """
    ok = sys.version_info >= (3, 8)
    print(f"  {'ok     ' if ok else 'MISSING'} python   {sys.version.split()[0]}"
          + ("" if ok else "   - Python 3.8 or later is needed"))
    missing = 0 if ok else 1
    for name, cmd, needed_by, how in CHECKS:
        found = shutil.which(cmd[0]) is not None
        version = ""
        if found:
            try:
                p = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                version = (p.stdout or p.stderr).strip().splitlines()[0] if (p.stdout or p.stderr).strip() else ""
                found = p.returncode == 0
            except (OSError, subprocess.TimeoutExpired):
                found = False
        if found:
            print(f"  ok      {name:10s}{version}")
        else:
            missing += 1
            print(f"  MISSING {name:10s}needed by {needed_by}\n          to install: {how}")
    if shutil.which("claude"):
        print("\n  claude is installed. Whether it is logged in cannot be checked without making a request:\n"
              "  run 'claude' once and follow the browser prompt if it asks you to log in, then run\n"
              "  make ai_check - it sends one small request and checks the login and the read-only settings.")
    print(f"\n{'everything needed is installed' if not missing else f'{missing} missing'}")
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
