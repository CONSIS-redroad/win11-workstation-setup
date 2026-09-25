#!/usr/bin/env python3
"""Plan (i opcjonalnie) synchronizacja pip wzgledem zrzutu referencyjnego. Stdout = JSON."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from packaging.version import InvalidVersion, Version
except ImportError:  # pragma: no cover
    Version = None  # type: ignore
    InvalidVersion = ValueError  # type: ignore


def load_snapshot(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig")
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: oczekiwano obiektu JSON")
    return data


def pip_map_from_snapshot(data: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for item in data.get("PythonPackages") or []:
        if not isinstance(item, dict):
            continue
        name = (item.get("Name") or "").strip()
        if not name:
            continue
        out[name.lower()] = str(item.get("Version") or "")
    return out


def pip_map_live() -> dict[str, str]:
    for launcher in ("py", "python", "python3"):
        try:
            proc = subprocess.run(
                [launcher, "-m", "pip", "list", "--format", "json"],
                capture_output=True,
                text=True,
                check=False,
            )
        except OSError:
            continue
        if proc.returncode != 0 or not proc.stdout.strip():
            continue
        parsed = json.loads(proc.stdout)
        out: dict[str, str] = {}
        for row in parsed:
            out[str(row["name"]).lower()] = str(row.get("version") or "")
        return out
    raise RuntimeError("Brak dzialajacego py/python -m pip")


def version_lt(a: str, b: str) -> bool | None:
    if not Version:
        return None
    try:
        return Version(a) < Version(b)
    except InvalidVersion:
        return None


def mcp_major(version: str) -> int | None:
    if not version:
        return None
    part = version.split(".", 1)[0]
    return int(part) if part.isdigit() else None


def build_plan(
    local: dict[str, str],
    reference: dict[str, str],
    *,
    pin_mcp_below_2: bool,
    include_downgrade: bool,
) -> dict[str, Any]:
    install: list[dict[str, str]] = []
    upgrade: list[dict[str, str]] = []
    skipped: list[dict[str, str]] = []
    already_ok: list[str] = []

    for name, ref_ver in sorted(reference.items()):
        loc_ver = local.get(name)
        if loc_ver is None:
            spec = f"{name}=={ref_ver}" if ref_ver else name
            install.append({"name": name, "spec": spec, "referenceVersion": ref_ver})
            continue
        if loc_ver == ref_ver:
            already_ok.append(name)
            continue

        newer_ref = version_lt(loc_ver, ref_ver)
        if newer_ref is False and not include_downgrade:
            skipped.append(
                {
                    "name": name,
                    "local": loc_ver,
                    "reference": ref_ver,
                    "reason": "lokalnie nowsze niz referencja (pominieto)",
                }
            )
            continue
        if newer_ref is False and include_downgrade:
            upgrade.append(
                {
                    "name": name,
                    "from": loc_ver,
                    "to": ref_ver,
                    "spec": f"{name}=={ref_ver}",
                    "action": "downgrade",
                }
            )
            continue

        if name == "mcp" and pin_mcp_below_2 and mcp_major(ref_ver) is not None and mcp_major(ref_ver) >= 2:
            skipped.append(
                {
                    "name": name,
                    "local": loc_ver,
                    "reference": ref_ver,
                    "reason": "referencja ma mcp>=2; pin mcp<2 dla FastMCP 1.x (ROADMAP)",
                }
            )
            continue

        if newer_ref is True or newer_ref is None:
            upgrade.append(
                {
                    "name": name,
                    "from": loc_ver,
                    "to": ref_ver,
                    "spec": f"{name}=={ref_ver}" if ref_ver else name,
                    "action": "upgrade" if newer_ref is True else "review",
                }
            )

    return {
        "install": install,
        "upgrade": upgrade,
        "skipped": skipped,
        "alreadyOkCount": len(already_ok),
        "installCount": len(install),
        "upgradeCount": len(upgrade),
    }


def run_pip_apply(launcher: str, specs: list[str]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for spec in specs:
        proc = subprocess.run(
            [launcher, "-m", "pip", "install", spec],
            capture_output=True,
            text=True,
        )
        results.append(
            {
                "spec": spec,
                "exitCode": proc.returncode,
                "ok": proc.returncode == 0,
                "tail": (proc.stdout + proc.stderr)[-500:],
            }
        )
    return results


def find_pip_launcher() -> str:
    for launcher in ("py", "python", "python3"):
        try:
            proc = subprocess.run(
                [launcher, "-m", "pip", "--version"],
                capture_output=True,
                text=True,
                check=False,
            )
            if proc.returncode == 0:
                return launcher
        except OSError:
            continue
    raise RuntimeError("Brak py/python z pip")


def main() -> int:
    parser = argparse.ArgumentParser(description="Plan synchronizacji pip vs zrzut referencyjny")
    parser.add_argument(
        "--reference",
        required=True,
        help="sciezka do srodowisko.json (np. maszyny/msi.json)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="wykonaj pip install (domyslnie tylko plan JSON)",
    )
    parser.add_argument(
        "--include-downgrade",
        action="store_true",
        help="rowniez obniz wersje gdy referencja starsza",
    )
    parser.add_argument(
        "--allow-mcp2",
        action="store_true",
        help="nie blokuj synchronizacji mcp>=2",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Apply: pozwol na wiecej niz 25 pakietow",
    )
    args = parser.parse_args()

    ref_path = Path(args.reference)
    if not ref_path.is_file():
        print(json.dumps({"ok": False, "error": f"Brak pliku: {ref_path}"}, ensure_ascii=False))
        return 1

    try:
        ref_data = load_snapshot(ref_path)
        reference = pip_map_from_snapshot(ref_data)
        local = pip_map_live()
        plan = build_plan(
            local,
            reference,
            pin_mcp_below_2=not args.allow_mcp2,
            include_downgrade=args.include_downgrade,
        )
        specs = [x["spec"] for x in plan["install"]] + [x["spec"] for x in plan["upgrade"]]
        warning = (
            "pip-sync dotyczy globalnego pip (pierwszy py/python w PATH), nie venv i nie profil_*.json. "
            "Apply instaluje name==wersja z referencji."
        )
        apply_max = 25
        if args.apply and specs and len(specs) > apply_max and not args.force:
            print(
                json.dumps(
                    {
                        "ok": False,
                        "error": (
                            f"Apply odmowa: {len(specs)} pakietow (limit {apply_max}). "
                            "Przejrzyj plan, potem --force albo pip-sync -Apply -ConfirmApply -Force."
                        ),
                        "plan": plan,
                        "warning": warning,
                    },
                    ensure_ascii=False,
                    indent=2,
                )
            )
            return 1
        out: dict[str, Any] = {
            "ok": True,
            "whatIf": not args.apply,
            "warning": warning,
            "reference": {
                "path": str(ref_path.resolve()),
                "computerName": ref_data.get("ComputerName"),
                "capturedAt": ref_data.get("CapturedAt"),
            },
            "localPackageCount": len(local),
            "referencePackageCount": len(reference),
            "plan": plan,
            "pipCommands": [f"py -m pip install {s}" for s in specs],
        }
        if args.apply and specs:
            launcher = find_pip_launcher()
            out["applyResults"] = run_pip_apply(launcher, specs)
            out["whatIf"] = False
        print(json.dumps(out, ensure_ascii=False, indent=2))
        return 0
    except (json.JSONDecodeError, ValueError, RuntimeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
