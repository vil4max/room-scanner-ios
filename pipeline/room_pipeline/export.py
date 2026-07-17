"""Export GLB / OBJ / USDZ helpers.

trimesh and usd-core are optional; PLY is always produced upstream.
"""

from __future__ import annotations

import logging
import shutil
from pathlib import Path

import numpy as np

logger = logging.getLogger(__name__)


def export_glb(path: Path, points: np.ndarray, colors: np.ndarray) -> bool:
    try:
        import trimesh
    except ImportError:
        logger.info("trimesh not installed; skip GLB")
        return False

    # Point cloud as vertices-only mesh (degenerate faces omitted) — viewers may need PLY.
    # Build a tiny sphere splat cloud alternative: export as PointCloud if supported.
    pc = trimesh.points.PointCloud(vertices=points, colors=(np.clip(colors, 0, 1) * 255).astype(np.uint8))
    path.parent.mkdir(parents=True, exist_ok=True)
    pc.export(path)
    return path.is_file()


def export_obj_from_existing(obj_path: Path, exports: list[str]) -> None:
    _ = exports
    if not obj_path.is_file():
        logger.info("No OBJ mesh to copy")


def try_usdz(glb_path: Path, usdz_path: Path) -> bool:
    """Best-effort USDZ: copy GLB aside with note; real usdzip needs usd-core / Reality Converter."""
    if not glb_path.is_file():
        return False
    # Documented placeholder: keep a sidecar note so Results can still import GLB.
    note = usdz_path.with_suffix(".usdz.txt")
    note.write_text(
        "USDZ export requires `usdzip` or Reality Converter on Mac.\n"
        f"Source GLB: {glb_path.name}\n",
        encoding="utf-8",
    )
    logger.info("Wrote USDZ instructions at %s", note)
    return False


def run_exports(
    out_dir: Path,
    points: np.ndarray,
    colors: np.ndarray,
    exports: list[str],
    obj_path: Path | None,
) -> dict[str, bool]:
    status: dict[str, bool] = {}
    if "glb" in exports:
        status["glb"] = export_glb(out_dir / "room.glb", points, colors)
    if "obj" in exports and obj_path and obj_path.is_file():
        dest = out_dir / "room.obj"
        shutil.copy2(obj_path, dest)
        status["obj"] = True
    elif "obj" in exports:
        status["obj"] = False
    if "usdz" in exports:
        status["usdz"] = try_usdz(out_dir / "room.glb", out_dir / "room.usdz")
    if "ply" in exports:
        status["ply"] = (out_dir / "room_semantic.ply").is_file()
    return status
