#!/usr/bin/env python3
"""Run a script from OneWoW_Workspace/bin (Suite pre-commit bridge).

Usage:
    python bin/run_devs.py locale_verify.py OneWoW/Locales

Workspace is the parent of this clone (nested) or a sibling named
OneWoW_Workspace. Override with ONEWOW_WORKSPACE or ONEWOW_DEVS.
If Workspace is missing, exit 0 so public forks without the private
toolchain can still commit.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

SUITE_ROOT = Path(__file__).resolve().parents[1]


def _looks_like_devs(path: Path) -> bool:
    return (path / "bin").is_dir()


def find_devs() -> Path | None:
    for key in ("ONEWOW_WORKSPACE", "ONEWOW_DEVS"):
        env = os.environ.get(key)
        if env:
            path = Path(env).expanduser().resolve()
            if _looks_like_devs(path):
                return path
    parent = SUITE_ROOT.parent
    if (parent / "bin").is_dir() and (
        (parent / ".cursor").is_dir()
        or (parent / "bin" / "locale_verify.py").is_file()
        or (parent / "bin" / "locale" / "locale_verify.py").is_file()
    ):
        return parent
    for name in ("OneWoW_Workspace", "OneWoW_Devs"):
        sibling = parent / name
        if _looks_like_devs(sibling):
            return sibling
    return None


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: python bin/run_devs.py <script.py> [args...]", file=sys.stderr)
        return 2
    script, rest = argv[1], argv[2:]
    devs = find_devs()
    if devs is None:
        print(f"OneWoW_Workspace not found; skipping {script}")
        return 0
    bin_dir = devs / "bin"
    target = bin_dir / script
    if not target.is_file():
        name = Path(script).name
        for sub in ("check", "locale", "release", "docs", "catalog", "warehouse", "wowhead", "devtool"):
            candidate = bin_dir / sub / name
            if candidate.is_file():
                target = candidate
                break
    if not target.is_file():
        print(f"missing {bin_dir / script}", file=sys.stderr)
        return 1
    return subprocess.call([sys.executable, str(target), *rest])


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
