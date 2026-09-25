#!/usr/bin/env python3
"""Porownanie dwoch zrzutow srodowisko.json (MSI vs Consis, przed/po obrazie). Stdout = JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


def load_snapshot(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig")
    data = json.loads(text)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: oczekiwano obiektu JSON")
    return data


def winget_map(data: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for item in data.get("Winget") or []:
        if not isinstance(item, dict):
            continue
        pid = (item.get("Id") or item.get("Name") or "").strip()
        if not pid:
            continue
        out[pid] = str(item.get("Version") or "")
    return out


def pkg_map(data: dict[str, Any], key: str, name_field: str = "Name", ver_field: str = "Version") -> dict[str, str]:
    out: dict[str, str] = {}
    for item in data.get(key) or []:
        if not isinstance(item, dict):
            continue
        name = (item.get(name_field) or item.get("Id") or "").strip()
        if not name:
            continue
        out[name.lower()] = str(item.get(ver_field) or "")
    return out


def ext_ids(data: dict[str, Any], key: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for item in data.get(key) or []:
        if not isinstance(item, dict):
            continue
        eid = (item.get("Id") or "").strip()
        if not eid:
            continue
        out[eid.lower()] = str(item.get("Version") or "")
    return out


def diff_keys(
    left: dict[str, str], right: dict[str, str]
) -> tuple[list[str], list[str], list[dict[str, str]]]:
    only_left = sorted(k for k in left if k not in right)
    only_right = sorted(k for k in right if k not in left)
    version_diff: list[dict[str, str]] = []
    for k in sorted(set(left) & set(right)):
        lv, rv = left[k], right[k]
        if lv != rv and (lv or rv):
            version_diff.append({"id": k, "left": lv, "right": rv})
    return only_left, only_right, version_diff


PIP_THEMES: list[tuple[str, str, frozenset[str]]] = [
    (
        "agent-mcp",
        "Agent / LangGraph / LiteLLM / MCP",
        frozenset(
            {
                "langgraph",
                "langgraph-checkpoint",
                "langgraph-checkpoint-sqlite",
                "langgraph-prebuilt",
                "langgraph-sdk",
                "litellm",
                "litellm-enterprise",
                "litellm-proxy-extras",
                "fastmcp",
                "fastmcp-slim",
                "mcp",
                "fastapi",
                "detect-secrets",
                "langchain-core",
                "langsmith",
            }
        ),
    ),
    (
        "cad-pdf",
        "CAD / PDF / DXF / OCR",
        frozenset(
            {
                "ezdxf",
                "pyautocad",
                "opencv-python",
                "pytesseract",
                "pymupdf",
                "pdfplumber",
                "python-docx",
                "docx2pdf",
                "openpyxl",
            }
        ),
    ),
    (
        "ml-heavy",
        "ML / CV (ciezkie)",
        frozenset({"torch", "transformers", "chromadb", "sentence-transformers", "onnxruntime", "scikit-learn"}),
    ),
]

WINGET_HINTS: dict[str, str] = {
    "Docker.DockerDesktop": "kontenery / dev",
    "Anthropic.ClaudeCode": "Claude Code CLI",
    "GitHub.cli": "GitHub CLI (gh)",
    "Python.Python.3.14": "Python 3.14",
    "Python.Python.3.12": "Python 3.12",
    "Google.Antigravity": "Antigravity IDE",
    "Google.AntigravityIDE": "Antigravity IDE 2",
    "HP.HPClick": "ploter HP",
    "Valve.Steam": "Steam",
}


def build_dependency_gaps(
    pip_only_left: list[str],
    pip_only_right: list[str],
    winget_only_left: list[str],
    winget_only_right: list[str],
    left_name: str,
    right_name: str,
) -> list[dict[str, Any]]:
    hints: list[dict[str, Any]] = []
    left_set = set(pip_only_left)
    right_set = set(pip_only_right)

    for _tid, label, pkgs in PIP_THEMES:
        miss_left = sorted(pkgs & right_set)
        miss_right = sorted(pkgs & left_set)
        if miss_left:
            hints.append(
                {
                    "kind": "pip",
                    "theme": label,
                    "weakerSide": left_name or "left",
                    "missingPackages": miss_left,
                    "risk": f"Na {left_name or 'lewej maszynie'} brak bibliotek ({label}) — skrypty/projekty z {right_name or 'prawej'} moga sie wysypac.",
                }
            )
        if miss_right:
            hints.append(
                {
                    "kind": "pip",
                    "theme": label,
                    "weakerSide": right_name or "right",
                    "missingPackages": miss_right,
                    "risk": f"Na {right_name or 'prawej maszynie'} brak bibliotek ({label}) — narzedzia z {left_name or 'lewej'} moga nie dzialac.",
                }
            )

    def winget_gaps(only_ids: list[str], weak: str, strong: str) -> None:
        for wid in only_ids:
            role = WINGET_HINTS.get(wid)
            if not role:
                continue
            hints.append(
                {
                    "kind": "winget",
                    "id": wid,
                    "weakerSide": weak,
                    "risk": f"Na {weak} brak {wid} ({role}) - na {strong} jest; workflow moze sie roznic.",
                }
            )

    winget_gaps(winget_only_right, left_name or "left", right_name or "right")
    winget_gaps(winget_only_left, right_name or "right", left_name or "left")
    return hints


def build_sync_hints(pip_version_diff: list[dict[str, str]], left_name: str, right_name: str) -> dict[str, Any]:
    """Ktore pakiety warto podbic, gdy cel = rownosc wersji (recznie / aktualizuj-pip.py)."""
    review: list[dict[str, str]] = []
    for row in pip_version_diff:
        review.append(
            {
                "package": row["id"],
                "left": row["left"],
                "right": row["right"],
                "hint": f"Rozne wersje: {left_name}={row['left']} vs {right_name}={row['right']}",
            }
        )
    return {"pipVersionDiffCount": len(review), "items": review}


def machine_meta(data: dict[str, Any]) -> dict[str, Any]:
    py = data.get("Python") if isinstance(data.get("Python"), dict) else {}
    return {
        "computerName": data.get("ComputerName"),
        "os": data.get("OS"),
        "capturedAt": data.get("CapturedAt"),
        "pipCount": len(data.get("PythonPackages") or []),
        "wingetCount": len(data.get("Winget") or []),
        "mcpPinWarning": bool(py.get("mcpPinWarning")) if py else False,
    }


def compare_snapshots(left: dict[str, Any], right: dict[str, Any]) -> dict[str, Any]:
    w_l, w_r = winget_map(left), winget_map(right)
    p_l, p_r = pkg_map(left, "PythonPackages"), pkg_map(right, "PythonPackages")
    c_l, c_r = ext_ids(left, "CursorExtensions"), ext_ids(right, "CursorExtensions")
    v_l, v_r = ext_ids(left, "VsCodeExtensions"), ext_ids(right, "VsCodeExtensions")

    w_only_l, w_only_r, w_ver = diff_keys(w_l, w_r)
    p_only_l, p_only_r, p_ver = diff_keys(p_l, p_r)
    c_only_l, c_only_r, c_ver = diff_keys(c_l, c_r)
    v_only_l, v_only_r, v_ver = diff_keys(v_l, v_r)

    same = (
        not w_only_l
        and not w_only_r
        and not w_ver
        and not p_only_l
        and not p_only_r
        and not p_ver
        and not c_only_l
        and not c_only_r
        and not c_ver
        and not v_only_l
        and not v_only_r
        and not v_ver
    )

    left_name = str(left.get("ComputerName") or "left")
    right_name = str(right.get("ComputerName") or "right")
    gaps = build_dependency_gaps(p_only_l, p_only_r, w_only_l, w_only_r, left_name, right_name)

    return {
        "ok": True,
        "same": same,
        "left": machine_meta(left),
        "right": machine_meta(right),
        "raport": {
            "dependencyGaps": gaps,
            "gapCount": len(gaps),
            "syncHints": build_sync_hints(p_ver, left_name, right_name),
            "idea": "Luki = miejsca gdzie apka na jednym PC moze miec maly problem, bo na drugim sa biblioteki/narzedzia ktorych tu brakuje.",
        },
        "winget": {
            "onlyLeft": w_only_l,
            "onlyRight": w_only_r,
            "versionDiff": w_ver,
        },
        "pip": {
            "onlyLeft": p_only_l,
            "onlyRight": p_only_r,
            "versionDiff": p_ver,
        },
        "cursorExtensions": {
            "onlyLeft": c_only_l,
            "onlyRight": c_only_r,
            "versionDiff": c_ver,
        },
        "vscodeExtensions": {
            "onlyLeft": v_only_l,
            "onlyRight": v_only_r,
            "versionDiff": v_ver,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Porownaj dwa pliki srodowisko.json")
    parser.add_argument("left", nargs="?", help="zrzut A (domyslnie srodowisko.json obok skryptu)")
    parser.add_argument("right", help="zrzut B (inna maszyna / starszy dump)")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    left_path = Path(args.left) if args.left else script_dir / "srodowisko.json"
    right_path = Path(args.right)

    for p in (left_path, right_path):
        if not p.is_file():
            print(json.dumps({"ok": False, "error": f"Brak pliku: {p}"}, ensure_ascii=False))
            return 1

    try:
        left_data = load_snapshot(left_path)
        right_data = load_snapshot(right_path)
        result = compare_snapshots(left_data, right_data)
        result["paths"] = {"left": str(left_path.resolve()), "right": str(right_path.resolve())}
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (json.JSONDecodeError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
