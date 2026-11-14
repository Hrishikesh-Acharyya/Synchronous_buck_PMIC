#!/usr/bin/env python3
#
# Filename:         audit_soak.py
#
# File Description: Independent audit of a pmic_top soak's event log
#                   (soak/all_events.csv): every event of every run checked
#                   against the supervisor's documented rules, written here
#                   from the RTL headers rather than taken from
#                   supervisor_model.py. The model already agreed with the
#                   DUT at every event's check; this catches what the model
#                   and the DUT could both get wrong.
#
#                   Rules, on each settled row:
#                     - running (En = 1, STATUS S_RUN) only with the switch on,
#                       the host enable given, no OTP, no UVLO and no latch;
#                     - En is exactly "running"; PGOOD only while running with
#                       a good rail;
#                     - strikes never above 3, and a latch from the strike
#                       count only at or past MAX_STRIKES.
#                   and on each transition:
#                     - strikes rise only on an overcurrent event (trip,
#                       persist, fault_in_hiccup), by one per trip unless the
#                       event is persistent, and only while running;
#                     - strikes fall only to zero, and only by the reset button
#                       or a long enough clean run (clean_run, wait, or any
#                       event that lets time pass while running);
#                     - a latch, once set, clears only by the reset button;
#                       it is set only by an overcurrent event or the OVP;
#                     - the host enable falls only by a host disable (also
#                       inside fault_in_hiccup); it rises only by a host
#                       enable, the reset button or the switch turning on;
#                     - the knobs (switch, OTP, UVLO, rail) change only on
#                       their own events.
#
#                   Usage: audit_soak.py <all_events.csv>
#                   Prints a count per check and every anomaly (up to three
#                   examples each); exits 1 if any.
#
# Global variables: OVERCURRENT_EVENTS, KNOB_EVENTS, S_RUN

import collections
import csv
import sys

# OVERCURRENT_EVENTS: the events that drive an overcurrent into the board
OVERCURRENT_EVENTS = ("trip", "persist", "fault_in_hiccup")
# KNOB_EVENTS: which events may move each board knob (the reset button keeps
#              every knob; it is physical)
KNOB_EVENTS = {"switch": ("switch",), "otp": ("otp", "fault_in_hiccup"),
               "uvlo": ("uvlo", "fault_in_hiccup"), "rail_good": ("rail",)}
# S_RUN: STATUS state encoding for regulation
S_RUN = "2"


def audit(path):

    """
    Purpose: Run every rule over the log; return (counts, anomalies, examples).
    """
    runs = collections.defaultdict(list)
    for row in csv.DictReader(open(path)):
        runs[row["seed"]].append(row)

    counts, anomalies = collections.Counter(), collections.Counter()
    examples = collections.defaultdict(list)

    def flag(kind, seed, row, text=""):
        anomalies[kind] += 1
        if len(examples[kind]) < 3:
            examples[kind].append(f"seed {seed} event {row['event']} {row['kind']} {row['note'][:40]}: {text}")

    for seed, rows in runs.items():
        for row in rows:
            counts["rows checked"] += 1
            running = row["state"] == S_RUN
            if running and not (row["switch"] == "1" and row["host_enable"] == "1" and row["otp"] == "0"
                                and row["uvlo"] == "0" and row["latched"] == "0"):
                flag("running without every enable, or with a fault or latch", seed, row)
            if row["En"] not in ("None", "") and row["state"] not in ("None", ""):
                if (row["En"] == "1") != running:
                    flag("En disagrees with the state", seed, row, f"En={row['En']} state={row['state']}")
            if row["PGOOD"] == "1" and not (running and row["rail_good"] == "1"):
                flag("PGOOD outside S_RUN or with the rail out", seed, row)
            if int(row["strikes"]) > 3:
                flag("strikes above 3", seed, row)

        for prev, row in zip(rows, rows[1:]):
            kind = row["kind"]
            counts["transitions checked"] += 1
            s_before, s_after = int(prev["strikes"]), int(row["strikes"])

            # ---- strikes ----
            if s_after > s_before:
                counts["strike rises checked"] += 1
                if kind not in OVERCURRENT_EVENTS:
                    flag(f"strikes rose on {kind}", seed, row)
                elif row["condition"] != "running":      # the condition the event arrived in
                    flag("strikes rose while not running", seed, row)
                elif kind != "persist" and s_after != s_before + 1:
                    flag("more than one strike from one trip", seed, row, f"{s_before}->{s_after}")
                if row["latched"] == "1" and prev["latched"] == "0" and s_after < int(row["max_strikes"]) \
                        and "ovp" not in row["note"]:
                    flag("strike latch below MAX_STRIKES", seed, row, f"strikes {s_after} max {row['max_strikes']}")
            if s_after < s_before:
                counts["strike falls checked"] += 1
                if s_after != 0:
                    flag("strikes fell other than to zero", seed, row, f"{s_before}->{s_after}")
                elif kind not in ("reset", "clean_run", "wait") and not (kind == "fault_in_hiccup" and "reset" in row["note"]):
                    if row["condition"] != "running":
                        flag(f"strikes cleared on {kind} without running", seed, row)

            # ---- the latch ----
            if prev["latched"] == "1" and row["latched"] == "0":
                counts["latch clears checked"] += 1
                if not (kind == "reset" or (kind == "fault_in_hiccup" and "reset" in row["note"])):
                    flag(f"latch cleared by {kind}", seed, row)
            if prev["latched"] == "0" and row["latched"] == "1":
                counts["latch sets checked"] += 1
                if kind not in OVERCURRENT_EVENTS + ("ovp",):
                    flag(f"latch set by {kind}", seed, row)

            # ---- the host enable ----
            if prev["host_enable"] == "1" and row["host_enable"] == "0":
                counts["host disables checked"] += 1
                if not (kind == "host" or (kind == "fault_in_hiccup" and "host" in row["note"])):
                    flag(f"host enable fell on {kind}", seed, row)
            if prev["host_enable"] == "0" and row["host_enable"] == "1":
                counts["host restores checked"] += 1
                if kind not in ("host", "reset", "switch") and not (kind == "fault_in_hiccup" and "reset" in row["note"]):
                    # a switch turn-on still being debounced restores it later,
                    # on whichever event's check comes after its edge
                    if not any(r["kind"] in ("switch", "reset") for r in rows[max(0, rows.index(row) - 12):rows.index(row)]):
                        flag(f"host enable restored by {kind}", seed, row)

            # ---- the knobs ----
            for knob, allowed in KNOB_EVENTS.items():
                if prev[knob] != row[knob] and kind not in allowed:
                    flag(f"{knob} changed on {kind}", seed, row)
    counts["runs"] = len(runs)
    return counts, anomalies, examples


if __name__ == "__main__":
    counts, anomalies, examples = audit(sys.argv[1])
    print("audited:")
    for name in ["runs", "rows checked", "transitions checked", "strike rises checked",
                 "strike falls checked", "latch sets checked", "latch clears checked",
                 "host disables checked", "host restores checked"]:
        print(f"  {name:<24} {counts[name]}")
    if not anomalies:
        print("anomalies: none")
        sys.exit(0)
    print("anomalies:")
    for kind, number in anomalies.items():
        print(f"  {kind}: {number}")
        for example in examples[kind]:
            print(f"      {example}")
    sys.exit(1)
