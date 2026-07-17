#!/usr/bin/env python3
"""Thin wrapper so `python scripts/run_all.py` matches docs."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from room_pipeline.run import main

if __name__ == "__main__":
    raise SystemExit(main())
