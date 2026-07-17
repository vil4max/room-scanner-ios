"""CLI entry: Session package → semantic PLY / cameras / optional GLB.

Usage:
  python -m room_pipeline.run --input Session_xxx --out out/Session_xxx
"""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

import yaml

from room_pipeline.export import run_exports
from room_pipeline.extract_frames import ensure_frames
from room_pipeline.geometry import run_geometry, write_cameras_json
from room_pipeline.meshing import try_open3d_mesh, voxel_downsample, write_ply
from room_pipeline.package import PackageError, validate_package
from room_pipeline.semantics import run_semantics

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
logger = logging.getLogger("room_pipeline")


def load_config(path: Path | None) -> dict:
    default = Path(__file__).resolve().parents[1] / "configs" / "default.yaml"
    cfg_path = path or default
    with cfg_path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def run(input_dir: Path, out_dir: Path, config_path: Path | None = None) -> int:
    cfg = load_config(config_path)
    out_dir.mkdir(parents=True, exist_ok=True)

    try:
        package = validate_package(input_dir)
    except PackageError as exc:
        logger.error("Package validation failed: %s", exc)
        return 2

    video = package.root / "video.mp4" if package.has_video else None
    frames_dir = package.root / "frames"
    try:
        frames = ensure_frames(
            video=video,
            existing=package.frame_paths,
            frames_dir=frames_dir,
            fps=float(cfg.get("keyframes_fps", 1.5)),
            blur_threshold=float(cfg.get("blur_variance_threshold", 80.0)),
        )
    except Exception as exc:  # noqa: BLE001 — stage-safe
        logger.error("Frame stage failed: %s", exc)
        return 3

    try:
        geometry = run_geometry(
            frame_paths=frames,
            depth_paths=package.depth_paths,
            metadata=package.metadata,
            backend=str(cfg.get("geometry_backend", "auto")),
            device=str(cfg.get("device", "mps")),
            max_views=int(cfg.get("max_views_per_chunk", 32)),
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Geometry stage failed: %s", exc)
        return 4

    write_cameras_json(out_dir / "cameras.json", geometry)
    points, colors = voxel_downsample(
        geometry.points,
        geometry.colors,
        float(cfg.get("voxel_m", 0.015)),
    )

    labels, sem_colors = run_semantics(
        points,
        backend=str(cfg.get("semantics_backend", "vote")),
        concepts=list(cfg.get("concepts", [])),
        frame_paths=frames,
    )
    # Blend original colors lightly with semantic palette for diggable viz.
    viz = 0.35 * colors + 0.65 * sem_colors
    write_ply(out_dir / "room_semantic.ply", points, viz)
    write_ply(out_dir / "points.ply", points, colors)

    obj_path = out_dir / "room_mesh.obj"
    meshed = try_open3d_mesh(points, viz, obj_path, float(cfg.get("tsdf_voxel_m", 0.02)))
    if not meshed:
        obj_path = None

    status = run_exports(
        out_dir,
        points,
        viz,
        list(cfg.get("exports", ["ply", "glb"])),
        obj_path,
    )
    logger.info(
        "Done backend=%s points=%d labels=%d exports=%s",
        geometry.backend,
        points.shape[0],
        labels.shape[0],
        status,
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="RoomScanner offline AI pipeline")
    parser.add_argument("--input", type=Path, required=True, help="Session_* package directory")
    parser.add_argument("--out", type=Path, required=True, help="Output directory")
    parser.add_argument("--config", type=Path, default=None, help="YAML config override")
    args = parser.parse_args(argv)
    return run(args.input, args.out, args.config)


if __name__ == "__main__":
    sys.exit(main())
