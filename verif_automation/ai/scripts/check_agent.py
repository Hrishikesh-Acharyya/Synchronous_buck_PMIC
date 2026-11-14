#!/usr/bin/env python3
#
# Filename:         check_agent.py
#
# File Description: Checks that the AI agent is ready before a real task is
#                   run: Claude Code is installed and logged in, the command
#                   the tasks use is accepted, the answer comes back as
#                   structured data, the RTL can be read, and the
#                   testbenches cannot - neither opened nor searched.
#
#                   It sends one small request (ai/tasks/check_agent) through
#                   exactly the command, tools and permission settings the
#                   real tasks use (triage_mutants.command), so a pass here
#                   means those are right on this machine. It costs a few
#                   thousand tokens and is not kept as evidence.
#
#                   Usage: check_agent.py [--model NAME]
#                   Exit status 0 when every check passes.
#
# Global variables: REPO, TASK, RTL, TB - see below

import argparse
import json
import pathlib
import shutil
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import triage_mutants as T  # noqa: E402

# REPO: the repository root
REPO = T.REPO
# TASK: the task folder - instructions and output schema
TASK = HERE.parent / "tasks" / "check_agent"
# RTL / TB: a file the agent must be able to read, and one it must not
RTL = "rtl-systemverilog/clk_rst/reset_sync.sv"
TB = "tb/clk_rst/reset_sync_tb.sv"


def main():

    """
    Purpose: Run the checks in order, print each result, and stop at the
             first one that makes the later ones meaningless.
    """
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--model")
    args = ap.parse_args()
    failed = []

    def say(ok, what, hint=""):
        print(f"  {'ok  ' if ok else 'FAIL'}  {what}" + (f"\n        {hint}" if hint and not ok else ""), flush=True)
        if not ok:
            failed.append(what)
        return ok

    # 1. installed
    where = shutil.which(T.CLAUDE)
    if not say(bool(where), f"Claude Code is installed ({where or 'claude not found on PATH'})",
               "install it (curl -fsSL https://claude.ai/install.sh | bash), open a new terminal, and run this again"):
        sys.exit(1)
    version = subprocess.run([T.CLAUDE, "--version"], capture_output=True, text=True).stdout.strip()
    print(f"        version {version}")

    # 2. one request, with the real command
    lines = (REPO / RTL).read_bytes().decode().replace("\r", "").split("\n")
    n = next(i for i, x in enumerate(lines) if x.startswith("module "))
    prompt = (TASK / "TASK.md").read_text().replace("{rtl}", RTL).replace("{tb}", TB).replace("{line}", str(n + 1))
    cmd = T.command(args.model, TASK)
    print("  ...   sending one small request (up to a minute)", flush=True)
    start = time.time()
    try:
        p = subprocess.run(cmd, input=prompt, capture_output=True, text=True, cwd=REPO, timeout=600)
    except subprocess.TimeoutExpired:
        say(False, "the request finished", "no answer in ten minutes - check the network: curl -I https://api.anthropic.com")
        sys.exit(1)
    secs = time.time() - start
    result = T.read_response(p.stdout)
    text = (p.stdout + p.stderr).strip()
    low = text.lower()
    hint = "the agent said: " + " ".join(text.split())[-300:]
    if "unknown option" in low or "unknown argument" in low:
        hint = "this version does not know an option the tasks use - update it: claude update\n        " + hint
    elif "unable to connect" in low or "timed out" in low or "enotfound" in low or "econn" in low:
        hint = ("it cannot reach Anthropic - a network problem on this machine, not in the scripts. Try: "
                "curl -I https://api.anthropic.com\n        " + hint)
    elif "log in" in low or "login" in low or "authenticat" in low or "api key" in low:
        hint = "it is not logged in - run claude once in a terminal and log in with the subscription account\n        " + hint
    answered = result is not None and not result.get("is_error")
    if not say(answered, f"the request was answered ({secs:.0f} s)", hint) or result is None:
        sys.exit(1)
    usage = result.get("usage") or {}
    models = ", ".join((result.get("modelUsage") or {}).keys())
    tokens_in = sum(usage.get(k, 0) for k in ("input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"))
    print(f"        model {models or 'not reported'}; {tokens_in} tokens in, {usage.get('output_tokens', 0)} out")

    # 3. the answer's form, and what it could and could not read
    out = T.structured(result)
    formed = out is not None and {"rtl_line", "tb_read", "tb_search"} <= set(out)
    if not say(formed, "the answer came back as structured data",
               "the answer was not in the task's form - update Claude Code: claude update") or out is None:
        sys.exit(1)
    say(" ".join(str(out["rtl_line"]).split()) == " ".join(lines[n].split()),
        f"the RTL can be read ({RTL})", f"expected line {n + 1}: {lines[n]!r}; got {out['rtl_line']!r}")
    say(out["tb_read"] is False, f"the testbenches cannot be opened ({TB})",
        "the permission settings (ai/scripts/settings_readonly.json) did not stop the read - do not run the "
        "tasks until this is fixed")
    say(out["tb_search"] is False, "the testbenches cannot be searched (tb/)",
        "a search showed testbench lines - the settings file does not cover the search tool on this version")
    print(f"        the agent's note: {' '.join(str(out.get('note', '')).split())[:300]}")

    if failed:
        print(f"\nnot ready: {len(failed)} check{'s' if len(failed) > 1 else ''} failed")
        sys.exit(1)
    print("\nready: make ai_mutants MODULE=<module> will work on this machine")


if __name__ == "__main__":
    main()
