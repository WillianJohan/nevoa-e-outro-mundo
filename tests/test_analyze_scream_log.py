#!/usr/bin/env python3
"""Testes leves de scripts/analyze_scream_log.py."""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))

from analyze_scream_log import analyze_lines, parse_timestamp_ms  # noqa: E402


def test_parse_timestamp_ms():
    line = "LOG  : General     , 1730000000123> [NOM] scream played kind=ambient gap=30000ms next=33000"
    assert parse_timestamp_ms(line) == 1730000000123


def test_analyze_played_and_legacy():
    t0 = 1730000000000
    lines = [
        f"LOG  , {t0}> [NOM] scream played kind=ambient source=ambient gap=30000ms next=33000 sound=NOM_AmbientScream1 dist=40",
        f"LOG  , {t0 + 90000}> [NOM] scream played kind=carpideira gap=45000ms next=136000 sound=NOM_CarpideiraScream why=near",
        f"LOG  , {t0 + 91000}> [NOM] scream blocked kind=ambient reason=gate nextAt=50000",
        f"LOG  , {t0 + 92000}> [NOM] variantes grito x=1 y=2 raio=40",
        f"LOG  , {t0 + 93000}> [NOM] variantes carpideira grito por=near x=1 y=2 raio=60",
        f"LOG  , {t0 + 94000}> [NOM] ambient scream cor=red",
    ]
    data = analyze_lines(lines)
    assert data["counts"]["played"] == 2
    assert data["counts"]["blocked"] == 1
    assert data["counts"]["legacy_corredor"] == 1
    assert data["counts"]["legacy_carpideira"] == 1
    assert data["counts"]["carpideira_grito"] == 1
    assert data["counts"]["ambient_debug"] == 1
    assert data["played_by_kind"]["ambient"] == 1
    assert data["played_by_sound"]["NOM_AmbientScream1"] == 1
    iv = data["interval_between_played"]
    assert iv["n"] == 1
    assert iv["mean_s"] == 90.0


def run_all():
    tests = [test_parse_timestamp_ms, test_analyze_played_and_legacy]
    for t in tests:
        try:
            t()
        except Exception as e:
            print("FAIL tests/test_analyze_scream_log.py :: %s\n  %s" % (t.__name__, e))
            return 1
    print("OK tests/test_analyze_scream_log.py (%d tests)" % len(tests))
    return 0


if __name__ == "__main__":
    sys.exit(run_all())
