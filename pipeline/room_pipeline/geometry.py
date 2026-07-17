"""Geometry backends: LiDAR unproject (default on 15 Pro) + optional foundation models.

Why LiDAR first on Apple Silicon: MapAnything/DA3 often assume CUDA; depth unprojection
gives metric points without downloading 1B weights.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

logger = logging.getLogger(__name__)


@dataclass
class GeometryResult:
    points: np.ndarray  # (N, 3) float64 meters
    colors: np.ndarray  # (N, 3) float64 0..1
    cameras: list[dict[str, Any]]
    backend: str
    scale_note: str


def _intrinsics_from_metadata(metadata: dict[str, Any], width: int, height: int) -> dict[str, float]:
    raw = metadata.get("intrinsics") or {}
    fx = float(raw.get("fx") or max(width, height))
    fy = float(raw.get("fy") or fx)
    cx = float(raw.get("cx") or width * 0.5)
    cy = float(raw.get("cy") or height * 0.5)
    return {"fx": fx, "fy": fy, "cx": cx, "cy": cy, "width": width, "height": height}


def unproject_depth(
    depth: np.ndarray,
    color_rgb: np.ndarray | None,
    K: dict[str, float],
    c2w: np.ndarray | None = None,
    stride: int = 4,
) -> tuple[np.ndarray, np.ndarray]:
    """Unproject metric depth map to XYZ; optional camera-to-world."""
    h, w = depth.shape[:2]
    ys, xs = np.mgrid[0:h:stride, 0:w:stride]
    z = depth[ys, xs]
    valid = np.isfinite(z) & (z > 0.05) & (z < 8.0)
    xs = xs[valid].astype(np.float64)
    ys = ys[valid].astype(np.float64)
    z = z[valid].astype(np.float64)
    x = (xs - K["cx"]) * z / K["fx"]
    y = (ys - K["cy"]) * z / K["fy"]
    pts = np.stack([x, y, z], axis=-1)
    if c2w is not None:
        ones = np.ones((pts.shape[0], 1), dtype=np.float64)
        homo = np.concatenate([pts, ones], axis=1)
        pts = (c2w @ homo.T).T[:, :3]
    if color_rgb is not None:
        colors = color_rgb[::stride, ::stride][valid].astype(np.float64) / 255.0
    else:
        colors = np.full((pts.shape[0], 3), 0.7, dtype=np.float64)
    return pts, colors


def geometry_from_lidar(
    frame_paths: list[Path],
    depth_paths: list[Path],
    metadata: dict[str, Any],
    max_frames: int = 32,
) -> GeometryResult:
    """Build metric cloud by unprojecting ARKit scene-depth maps."""
    import cv2

    # Match by stem so missing depth for a frame is skipped, not fatal.
    depth_by_stem = {p.stem: p for p in depth_paths}
    pairs: list[tuple[Path, Path]] = []
    for frame in frame_paths:
        depth = depth_by_stem.get(frame.stem)
        if depth is not None:
            pairs.append((frame, depth))
    if not pairs:
        raise RuntimeError("has_lidar path requested but no matching frame/depth pairs")

    pairs = pairs[:max_frames]
    all_pts: list[np.ndarray] = []
    all_cols: list[np.ndarray] = []
    cameras: list[dict[str, Any]] = []

    for index, (frame_path, depth_path) in enumerate(pairs):
        depth = np.load(depth_path)
        if depth.ndim != 2:
            raise RuntimeError(f"Depth must be HxW float meters: {depth_path}")
        bgr = cv2.imread(str(frame_path))
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB) if bgr is not None else None
        h, w = depth.shape
        K = _intrinsics_from_metadata(metadata, w, h)
        # Identity c2w per frame: without poses we accumulate in camera frames and
        # still get a usable local cloud; MapAnything later can replace this.
        pts, cols = unproject_depth(depth, rgb, K, c2w=None, stride=4)
        all_pts.append(pts)
        all_cols.append(cols)
        cameras.append(
            {
                "frame": frame_path.name,
                "index": index,
                "intrinsics": K,
                "c2w": np.eye(4).tolist(),
            }
        )

    points = np.concatenate(all_pts, axis=0) if all_pts else np.zeros((0, 3))
    colors = np.concatenate(all_cols, axis=0) if all_cols else np.zeros((0, 3))
    return GeometryResult(
        points=points,
        colors=colors,
        cameras=cameras,
        backend="lidar_unproject",
        scale_note="Metric scale from ARKit scene depth (meters).",
    )


def try_mapanything_or_da3(
    frame_paths: list[Path],
    metadata: dict[str, Any],
    device: str,
    max_views: int,
) -> GeometryResult | None:
    """Soft-import foundation models; return None if not installed."""
    frames = frame_paths[:max_views]
    if not frames:
        return None

    # Placeholder hook: keep import behind try so CI stays offline.
    try:
        import importlib.util

        if importlib.util.find_spec("mapanything") is not None:
            logger.info("MapAnything detected — wire real infer() when integrating weights")
        if importlib.util.find_spec("depth_anything_3") is not None:
            logger.info("Depth Anything 3 detected — wire real infer() when integrating weights")
    except Exception as exc:  # noqa: BLE001 — soft path
        logger.warning("Foundation geometry probe failed: %s", exc)
    _ = (metadata, device, frames)
    return None


def run_geometry(
    frame_paths: list[Path],
    depth_paths: list[Path],
    metadata: dict[str, Any],
    backend: str,
    device: str,
    max_views: int,
) -> GeometryResult:
    """Select geometry backend. `auto` prefers LiDAR unproject when depth exists."""
    has_depth = len(depth_paths) > 0
    use_lidar = backend in ("auto", "lidar") and has_depth
    if use_lidar:
        return geometry_from_lidar(frame_paths, depth_paths, metadata, max_frames=max_views)

    result = try_mapanything_or_da3(frame_paths, metadata, device, max_views)
    if result is not None:
        return result

    raise RuntimeError(
        "No geometry backend available. Provide LiDAR depth maps, or install "
        "MapAnything / Depth Anything 3. See docs/ai-pipeline.md."
    )


def write_cameras_json(path: Path, result: GeometryResult) -> None:
    payload = {
        "backend": result.backend,
        "scale_note": result.scale_note,
        "cameras": result.cameras,
        "point_count": int(result.points.shape[0]),
    }
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
