#!/usr/bin/env python3
#
# Filename:         audit_soak.py
#
# File Description: Independent audit of a soak's transaction log
#                   (soak/all_events.csv): every event of every run, checked
#                   against rules written from the register map, not taken from
#                   reg_file_model.py. The model already agreed with the DUT on
#                   every read and scoreboard check; this catches what the
#                   model and the DUT could both get wrong.
#
#                   Checks, per run, event by event:
#                     - every threshold within its clamp range;
#                     - for every write frame that staged a threshold: accept
#                       or reject recomputed from the frame's bytes (write key,
#                       partial multi-byte register, a CHANGE to an S_OFF-only
#                       register outside S_OFF), the committed values (clamped)
#                       and write_rejected;
#                     - thresholds and write_rejected move only on write events;
#                     - an S_OFF-only register never changes outside S_OFF;
#                     - spi_enable falls only on a frame that keyed and wrote
#                       CONTROL = 0; it rises only on CONTROL, the switch or
#                       the watchdog; wd_restored is set only by the watchdog;
#                     - bus_err_count never falls, moves only on a bad CRC or a
#                       broken frame, and every bad-CRC write counts;
#                     - a broken read counts a bus error exactly when it is cut
#                       or stalled inside its command byte;
#                     - sup_state and the timestamp move only on their own
#                       events, and SCRATCH only on a good-CRC write.
#
#                   Usage: audit_soak.py <all_events.csv>
#                   Prints a count per check and every anomaly (up to three
#                   examples each); exits 1 if any.
#
# Global variables: REGISTERS, WRITE_KEY, DISABLE_KEY

import collections
import csv
import re
import sys

# REGISTERS: (name, first address, bytes, clamp min, clamp max, S_OFF-only) -
#            the threshold bank as the register map states it
REGISTERS = [("trip_run",         0x50, 1, 1,     16,      False),
             ("trip_ss",          0x51, 1, 1,     32,      False),
             ("max_strikes",      0x52, 1, 1,     3,       False),
             ("max_on_limit",     0x53, 1, 12,    83,      False),
             ("hiccup_base",      0x54, 3, 50000, 1000000, True),
             ("cycles_per_step",  0x57, 1, 1,     64,      True),
             ("clean_run_target", 0x58, 3, 45000, 524287,  True)]
NAMES = [r[0] for r in REGISTERS]
# WRITE_KEY / DISABLE_KEY: the bytes that arm the threshold bank and a disable
WRITE_KEY, DISABLE_KEY = 0xA7, 0xD1

WRITE_NOTE = re.compile(r"write @0x([0-9a-f]+) \[([^\]]*)\] crc_ok=(True|False)")
BROKEN_READ = re.compile(r"cut=(\w+) stall=(\w+)")


def frame(note):

    """
    Purpose: (address, data bytes, crc_ok) of a complete write frame from its
             CSV note, or None for any other event.
    """
    m = WRITE_NOTE.search(note)
    if not m:
        return None
    data = [int(x.strip().strip("'"), 16) for x in m.group(2).split(",") if x.strip()]
    return int(m.group(1), 16), data, m.group(3) == "True"


def audit(path):

    """
    Purpose: Run every check over the log; return (counts, anomalies, examples).
    """
    runs = collections.defaultdict(list)
    for row in csv.DictReader(open(path)):
        runs[row["seed"]].append(row)

    counts, anomalies = collections.Counter(), collections.Counter()
    examples = collections.defaultdict(list)

    def flag(kind, seed, row, text=""):
        anomalies[kind] += 1
        if len(examples[kind]) < 3:
            examples[kind].append(f"seed {seed} event {row['event']} {row['kind']}: {text}")

    for seed, rows in runs.items():
        for row in rows:
            for name, _, _, low, high, _ in REGISTERS:
                if not low <= int(row[name]) <= high:
                    flag("threshold out of range", seed, row, f"{name}={row[name]}")
        for prev, row in zip(rows, rows[1:]):
            kind, state = row["kind"], int(row["sup_state"])
            parsed = frame(row["note"])
            changed = [n for n in NAMES if row[n] != prev[n]]
            counts["events checked"] += 1

            # ---- what may move on which event ----
            if changed and kind not in ("threshold", "raw_write"):
                flag(f"threshold moved by {kind}", seed, row, str(changed))
            if row["write_rejected"] != prev["write_rejected"] and kind not in ("threshold", "raw_write"):
                flag(f"write_rejected moved by {kind}", seed, row)
            for name, _, _, _, _, off_only in REGISTERS:
                if off_only and row[name] != prev[name] and state != 0:
                    flag("S_OFF-only register changed outside S_OFF", seed, row, name)
            if row["sup_state"] != prev["sup_state"] and kind != "sup_state":
                flag(f"sup_state moved by {kind}", seed, row)
            if row["timestamp_ms"] != prev["timestamp_ms"] and kind != "time":
                flag(f"timestamp moved by {kind}", seed, row)
            if row["scratch"] != prev["scratch"] and not (parsed and parsed[2]):
                flag("SCRATCH moved without a good-CRC write", seed, row)

            # ---- bus errors ----
            before, after = int(prev["bus_err_count"]), int(row["bus_err_count"])
            if after < before:
                flag("bus_err_count fell", seed, row)
            if after != before and not (kind.startswith("broken") or (parsed and not parsed[2])):
                flag(f"bus error counted on a good {kind}", seed, row)
            if parsed and not parsed[2] and after == before and before < 0xFFFF:
                flag("bad-CRC write not counted", seed, row)
            if kind == "broken_read":
                m = BROKEN_READ.search(row["note"])
                bit = int(m.group(1)) if m.group(1) != "None" else int(m.group(2))
                if (bit < 8) != (after != before) and before < 0xFFFF:
                    flag("broken read counted against the command-byte rule", seed, row, row["note"][:50])
                counts["broken reads checked"] += 1

            # ---- the enable path ----
            en_before, en_after = int(prev["spi_enable"]), int(row["spi_enable"])
            if en_before == 1 and en_after == 0:
                keyed = False
                if parsed and parsed[2]:
                    address, data, _ = parsed
                    armed = False
                    for i, value in enumerate(data):
                        a = (address + i) & 0x7F
                        if a == 0x40:
                            armed = value == DISABLE_KEY
                        elif a == 0x41:
                            keyed = keyed or ((value & 1) == 0 and armed)
                            armed = armed and not (value & 1)
                if not keyed:
                    flag("disable without a keyed CONTROL write", seed, row, row["note"][:60])
                counts["disables checked"] += 1
            if en_before == 0 and en_after == 1 and kind not in ("control", "raw_write", "switch", "time"):
                flag(f"enable by {kind}", seed, row)
            if prev["wd_restored"] == "0" and row["wd_restored"] == "1":
                if not (kind == "time" and en_before == 0 and en_after == 1):
                    flag("wd_restored set other than by the watchdog", seed, row)
                counts["watchdog restores checked"] += 1

            # ---- the threshold bank, recomputed from the frame ----
            if parsed and kind in ("threshold", "raw_write"):
                address, data, crc_ok = parsed
                staged, key = {}, False
                for i, value in enumerate(data):
                    a = (address + i) & 0x7F
                    if a == 0x4F:
                        key = value == WRITE_KEY
                    elif 0x50 <= a <= 0x5A:
                        staged[a] = value
                if not crc_ok or not staged:
                    if changed:
                        flag("threshold changed by a frame that cannot commit one", seed, row)
                    if row["write_rejected"] != prev["write_rejected"]:
                        flag("write_rejected moved by a frame that commits no threshold", seed, row)
                    continue
                partial = off_change = False
                new = {}
                for name, first, width, low, high, off_only in REGISTERS:
                    written = [(first + i) in staged for i in range(width)]
                    if any(written) and not all(written):
                        partial = True
                    if all(written):
                        raw = sum(staged[first + i] << (8 * i) for i in range(width))
                        new[name] = min(max(raw, low), high)
                        if off_only and state != 0 and raw != int(prev[name]):
                            off_change = True
                reject = (not key) or partial or off_change
                expected = {n: int(prev[n]) if reject or n not in new else new[n] for n in NAMES}
                if expected != {n: int(row[n]) for n in NAMES}:
                    flag("committed thresholds differ from the rules", seed, row,
                         f"key={key} partial={partial} off_change={off_change}")
                if int(row["write_rejected"]) != int(reject):
                    flag("write_rejected differs from the rules", seed, row)
                counts["threshold frames recomputed"] += 1
                counts["  of which rejected" if reject else "  of which accepted"] += 1
    counts["runs"] = len(runs)
    return counts, anomalies, examples


if __name__ == "__main__":
    counts, anomalies, examples = audit(sys.argv[1])
    print("audited:")
    for name in ["runs", "events checked", "threshold frames recomputed", "  of which accepted",
                 "  of which rejected", "disables checked", "watchdog restores checked",
                 "broken reads checked"]:
        print(f"  {name:<32} {counts[name]}")
    if not anomalies:
        print("anomalies: none")
        sys.exit(0)
    print("anomalies:")
    for kind, number in anomalies.items():
        print(f"  {kind}: {number}")
        for example in examples[kind]:
            print(f"      {example}")
    sys.exit(1)
