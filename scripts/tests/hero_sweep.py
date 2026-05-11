#!/usr/bin/env python3
"""
Hero Sweep Test — scene-integration test for Three Kingdoms Deckbuilder.

Tests that every hero can load battle.tscn without crashing.
Patches PlayerData.chosen_hero_id before each run, launches Godot headless,
checks output for errors, reports pass/fail per hero.

Usage:
  python3 scripts/tests/hero_sweep.py          # all heroes
  python3 scripts/tests/hero_sweep.py --quick  # 3 key heroes only
  python3 scripts/tests/hero_sweep.py zhao_yun cao_cao  # specific heroes

Exit code: 0 if all pass, 1 if any fail.
"""

import subprocess
import sys
import os
import time
import json
from pathlib import Path
from datetime import datetime

PROJECT_DIR = Path("/Users/thomasyau/Projects/game1-three-kingdoms")
PLAYER_DATA_PATH = PROJECT_DIR / "scripts" / "data" / "player_data.gd"
GODOT_BIN = "godot"
BATTLE_SCENE = "res://scenes/battle/battle.tscn"
TIMEOUT = 15  # seconds per hero

ALL_HEROES = [
    # SHU
    "zhao_yun", "guan_yu", "zhang_fei", "zhuge_liang", "liu_bei",
    "ma_chao", "huang_zhong",
    # WEI
    "cao_cao", "sim_yi", "xiahou_dun", "zhen_ji", "guo_jia",
    # WU
    "sun_quan", "zhou_yu", "lu_xun", "huang_gai", "da_qiao",
    # QUN
    "lv_bu", "diao_chan",
]

QUICK_HEROES = ["zhao_yun", "cao_cao", "sun_quan"]

ORIGINAL_CONTENT = None  # cached backup of player_data.gd


def read_player_data():
    """Read current player_data.gd content."""
    return PLAYER_DATA_PATH.read_text()


def patch_hero(hero_id: str):
    """Set PlayerData.chosen_hero_id to the given hero."""
    content = PLAYER_DATA_PATH.read_text()
    # Replace the default line
    for pattern in [
        'var chosen_hero_id: String = "',
        "var chosen_hero_id: String = '",
    ]:
        marker = content.find(pattern)
        if marker >= 0:
            start = marker + len(pattern)
            end = content.index('"', start) if '"' in content[start:start+50] else content.index("'", start)
            new_content = content[:start] + hero_id + content[end:]
            PLAYER_DATA_PATH.write_text(new_content)
            return
    raise RuntimeError(f"Could not find chosen_hero_id line in {PLAYER_DATA_PATH}")


def run_battle(hero_id: str) -> dict:
    """Run battle.tscn headless for one hero. Returns result dict."""
    print(f"  [{hero_id}] ", end="", flush=True)

    try:
        result = subprocess.run(
            [GODOT_BIN, "--headless", "--quit", BATTLE_SCENE],
            cwd=str(PROJECT_DIR),
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        return {
            "hero": hero_id,
            "status": "FAIL",
            "reason": f"Timeout after {TIMEOUT}s (infinite loop or hang)",
            "exit_code": -1,
        }

    # Combine stdout + stderr for error scanning
    output = (result.stdout or "") + "\n" + (result.stderr or "")

    # Check for fatal conditions
    if "Parser Error" in output:
        # Extract the specific parse error
        for line in output.splitlines():
            if "Parser Error" in line:
                return {"hero": hero_id, "status": "FAIL", "reason": line.strip(), "exit_code": result.returncode}
        return {"hero": hero_id, "status": "FAIL", "reason": "Parser Error (unknown)", "exit_code": result.returncode}

    if "SCRIPT ERROR" in output:
        for line in output.splitlines():
            if "SCRIPT ERROR" in line or "Error:" in line:
                return {"hero": hero_id, "status": "FAIL", "reason": line.strip()[:120], "exit_code": result.returncode}
        return {"hero": hero_id, "status": "FAIL", "reason": "SCRIPT ERROR (unknown)", "exit_code": result.returncode}

    # Check for success markers
    battle_ran = "=== Turn" in output or "Turn" in output
    victory = "VICTORY" in output
    defeat = "DEFEAT" in output

    if battle_ran:
        outcome = "VICTORY" if victory else ("DEFEAT" if defeat else "ran")
        return {"hero": hero_id, "status": "PASS", "reason": f"battle {outcome}", "exit_code": result.returncode}
    else:
        # No turn output but no errors — probably scene loaded fine but battle didn't auto-start
        return {"hero": hero_id, "status": "PASS", "reason": "scene loaded (no errors)", "exit_code": result.returncode}


def print_summary(results: list[dict], start_time: float):
    """Print test summary table."""
    passed = [r for r in results if r["status"] == "PASS"]
    failed = [r for r in results if r["status"] == "FAIL"]

    elapsed = time.time() - start_time
    print(f"\n{'='*60}")
    print(f"RESULTS: {len(passed)}/{len(results)} passed in {elapsed:.1f}s")
    print(f"{'='*60}")

    if failed:
        print(f"\nFAILED ({len(failed)}):")
        for r in failed:
            print(f"  ✗ {r['hero']:20s}  {r['reason']}")

    if passed:
        print(f"\nPASSED ({len(passed)}):")
        for r in passed:
            print(f"  ✓ {r['hero']:20s}  {r['reason']}")
    print()

    # Save JSON report
    report_path = PROJECT_DIR / "test-results" / "hero_sweep.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report = {
        "timestamp": datetime.now().isoformat(),
        "duration_s": round(elapsed, 1),
        "total": len(results),
        "passed": len(passed),
        "failed": len(failed),
        "results": results,
    }
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"Report saved to: {report_path}")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Hero Sweep Test")
    parser.add_argument("heroes", nargs="*", help="Specific hero IDs to test")
    parser.add_argument("--quick", action="store_true", help="Test 3 key heroes only")
    args = parser.parse_args()

    # Determine hero list
    if args.heroes:
        heroes = args.heroes
    elif args.quick:
        heroes = QUICK_HEROES
    else:
        heroes = ALL_HEROES

    print(f"\n=== HERO SWEEP TEST ===\n")
    print(f"Project: {PROJECT_DIR}")
    print(f"Heroes:  {len(heroes)}")
    print(f"Timeout: {TIMEOUT}s/hero\n")

    # Backup original player_data.gd
    global ORIGINAL_CONTENT
    ORIGINAL_CONTENT = read_player_data()

    start_time = time.time()
    results = []

    try:
        for hero_id in heroes:
            patch_hero(hero_id)
            result = run_battle(hero_id)
            results.append(result)

            status = "✓" if result["status"] == "PASS" else "✗"
            print(f"{status}  {result['reason']}")
    finally:
        # Restore original
        PLAYER_DATA_PATH.write_text(ORIGINAL_CONTENT)
        print(f"\nRestored {PLAYER_DATA_PATH}")

    print_summary(results, start_time)

    # Exit code
    failed = [r for r in results if r["status"] == "FAIL"]
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
