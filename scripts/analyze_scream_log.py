#!/usr/bin/env python3
"""Conta gritos no console.txt (ou stdin) do Project Zomboid / mod NOM.

Lê um arquivo ou stdin e resume linhas de grito do mod: ``scream played``,
``scream blocked`` (só com ``-debug``), legado ``variantes grito`` /
``variantes carpideira grito``, ``carpideira grito`` (debug servidor),
``ambient scream`` (debug cliente). Agrupa ``scream played`` por ``kind`` e
``sound``; calcula intervalo médio/mediano entre eventos ``scream played``
quando o log traz timestamp (ms ou data/hora vanilla).

Uso::

    python3 scripts/analyze_scream_log.py ~/.var/app/com.valvesoftware.Steam/Zomboid/console.txt
    grep -E 'scream (played|blocked)|variantes grito|carpideira grito|ambient scream' console.txt \\
        | python3 scripts/analyze_scream_log.py

    python3 scripts/analyze_scream_log.py --json console.txt   # saída machine-readable

Exit 0 sempre que o arquivo/stdin foi lido; exit 2 se o path não existe.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from statistics import mean, median
from typing import Iterable, Optional

PLAYED = re.compile(
    r"\[NOM\] scream played kind=(?P<kind>\w+)"
    r"(?: source=(?P<source>\w+))?"
    r" gap=(?P<gap>\d+)ms next=(?P<next>\d+)"
    r"(?: sound=(?P<sound>\S+))?"
    r"(?: dist=(?P<dist>\d+))?"
    r"(?: why=(?P<why>\S+))?"
)
BLOCKED = re.compile(
    r"\[NOM\] scream blocked kind=(?P<kind>\w+) reason=(?P<reason>\w+)(?: (?P<detail>.+))?"
)
LEGACY_CORREDOR = re.compile(r"\[NOM\] variantes grito\b")
LEGACY_CARP = re.compile(r"\[NOM\] variantes carpideira grito\b")
CARPIDeira_GRITO = re.compile(r"\[NOM\][^\n]*carpideira grito\b")
AMBIENT_DEBUG = re.compile(r"\[NOM\] ambient scream\b")

TS_MS = re.compile(r",\s*(\d{13})>")
TS_WALL = re.compile(r",\s*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})>")


def parse_timestamp_ms(line: str) -> Optional[int]:
    m = TS_MS.search(line)
    if m:
        return int(m.group(1))
    m = TS_WALL.search(line)
    if m:
        dt = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        return int(dt.timestamp() * 1000)
    return None


def analyze_lines(lines: Iterable[str]) -> dict:
    counts = Counter(
        played=0,
        blocked=0,
        legacy_corredor=0,
        legacy_carpideira=0,
        carpideira_grito=0,
        ambient_debug=0,
    )
    by_kind = Counter()
    by_sound = Counter()
    by_kind_sound: dict[str, Counter] = defaultdict(Counter)
    blocked_by_kind = Counter()
    played_times_ms: list[int] = []
    gaps_claimed_ms: list[int] = []

    for line in lines:
        line = line.rstrip("\n")
        if PLAYED.search(line):
            m = PLAYED.search(line)
            assert m
            counts["played"] += 1
            kind = m.group("kind")
            by_kind[kind] += 1
            sound = m.group("sound") or "(sem sound=)"
            by_sound[sound] += 1
            by_kind_sound[kind][sound] += 1
            gaps_claimed_ms.append(int(m.group("gap")))
            ts = parse_timestamp_ms(line)
            if ts is not None:
                played_times_ms.append(ts)
            continue
        if BLOCKED.search(line):
            m = BLOCKED.search(line)
            assert m
            counts["blocked"] += 1
            blocked_by_kind[m.group("kind")] += 1
            continue
        if LEGACY_CORREDOR.search(line):
            counts["legacy_corredor"] += 1
            continue
        if LEGACY_CARP.search(line):
            counts["legacy_carpideira"] += 1
        if CARPIDeira_GRITO.search(line):
            counts["carpideira_grito"] += 1
            continue
        if AMBIENT_DEBUG.search(line):
            counts["ambient_debug"] += 1

    intervals_ms: list[int] = []
    if len(played_times_ms) >= 2:
        played_times_ms.sort()
        intervals_ms = [
            played_times_ms[i + 1] - played_times_ms[i]
            for i in range(len(played_times_ms) - 1)
        ]

    def stat_ms(vals: list[int]) -> dict:
        if not vals:
            return {"n": 0}
        return {
            "n": len(vals),
            "mean_s": round(mean(vals) / 1000.0, 2),
            "median_s": round(median(vals) / 1000.0, 2),
            "min_s": round(min(vals) / 1000.0, 2),
            "max_s": round(max(vals) / 1000.0, 2),
        }

    return {
        "counts": dict(counts),
        "played_by_kind": dict(by_kind),
        "played_by_sound": dict(by_sound),
        "played_by_kind_sound": {k: dict(v) for k, v in by_kind_sound.items()},
        "blocked_by_kind": dict(blocked_by_kind),
        "interval_between_played": stat_ms(intervals_ms),
        "gap_field_on_played": stat_ms(gaps_claimed_ms),
        "played_with_timestamp": len(played_times_ms),
    }


def format_report(data: dict) -> str:
    c = data["counts"]
    lines = [
        "=== NOM gritos (analyze_scream_log) ===",
        f"scream played:           {c.get('played', 0)}",
        f"scream blocked (-debug): {c.get('blocked', 0)}",
        f"legado variantes grito:  {c.get('legacy_corredor', 0)}",
        f"legado carpideira grito: {c.get('legacy_carpideira', 0)}",
        f"carpideira grito (debug): {c.get('carpideira_grito', 0)}",
        f"debug ambient scream:    {c.get('ambient_debug', 0)}",
        "",
        "scream played por kind:",
    ]
    for kind, n in sorted(data["played_by_kind"].items(), key=lambda x: (-x[1], x[0])):
        lines.append(f"  {kind}: {n}")
    if not data["played_by_kind"]:
        lines.append("  (nenhum)")

    lines.append("")
    lines.append("scream played por sound:")
    for sound, n in sorted(data["played_by_sound"].items(), key=lambda x: (-x[1], x[0])):
        lines.append(f"  {sound}: {n}")
    if not data["played_by_sound"]:
        lines.append("  (nenhum)")

    iv = data["interval_between_played"]
    lines.append("")
    if iv.get("n", 0):
        lines.append(
            f"intervalo entre scream played (timestamp no log, n={iv['n']}): "
            f"média {iv['mean_s']} s, mediana {iv['median_s']} s "
            f"(min {iv['min_s']} s, max {iv['max_s']} s)"
        )
    else:
        lines.append(
            f"intervalo entre scream played: sem timestamps suficientes "
            f"(linhas com ts: {data.get('played_with_timestamp', 0)})"
        )

    gf = data["gap_field_on_played"]
    if gf.get("n", 0):
        lines.append(
            f"campo gap= nos played (n={gf['n']}): média {gf['mean_s']} s, "
            f"mediana {gf['median_s']} s"
        )

    if data["blocked_by_kind"]:
        lines.append("")
        lines.append("scream blocked por kind:")
        for kind, n in sorted(data["blocked_by_kind"].items()):
            lines.append(f"  {kind}: {n}")

    return "\n".join(lines)


def read_input(path: Optional[str]) -> Iterable[str]:
    if path is None or path == "-":
        return sys.stdin
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.readlines()


def main(argv: Optional[list[str]] = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument(
        "path",
        nargs="?",
        default="-",
        help="console.txt ou '-' para stdin (default: stdin)",
    )
    p.add_argument("--json", action="store_true", help="JSON em vez de texto")
    args = p.parse_args(argv)

    if args.path not in (None, "-") and not __import__("os").path.isfile(args.path):
        print(f"arquivo não encontrado: {args.path}", file=sys.stderr)
        return 2

    if args.path in (None, "-"):
        lines = sys.stdin.readlines()
    else:
        with open(args.path, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()

    data = analyze_lines(lines)
    if args.json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print(format_report(data))
    return 0


if __name__ == "__main__":
    sys.exit(main())
