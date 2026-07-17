"""Capture package schema validation and metadata helpers.

Why: refuse bad AirDrop folders before loading any model weights.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1


@dataclass(frozen=True)
class PackageInfo:
    root: Path
    metadata: dict[str, Any]
    has_video: bool
    frame_paths: list[Path]
    depth_paths: list[Path]

    @property
    def has_lidar(self) -> bool:
        # Prefer explicit metadata flag; fall back to depth files on disk.
        if "has_lidar" in self.metadata:
            return bool(self.metadata["has_lidar"])
        return len(self.depth_paths) > 0


class PackageError(ValueError):
    """Raised when a session folder cannot be processed safely."""


def load_metadata(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise PackageError(f"Missing metadata.json at {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise PackageError("metadata.json must be an object")
    return data


def validate_package(root: Path) -> PackageInfo:
    """Validate Session_* layout before expensive stages."""
    root = root.expanduser().resolve()
    if not root.is_dir():
        raise PackageError(f"Input is not a directory: {root}")

    metadata_path = root / "metadata.json"
    metadata = load_metadata(metadata_path)
    version = int(metadata.get("schema_version", 0))
    if version != SCHEMA_VERSION:
        raise PackageError(
            f"Unsupported schema_version={version}; expected {SCHEMA_VERSION}"
        )

    video = root / "video.mp4"
    frames_dir = root / "frames"
    depth_dir = root / "depth"

    frame_paths: list[Path] = []
    if frames_dir.is_dir():
        frame_paths = sorted(frames_dir.glob("frame_*.jpg")) + sorted(
            frames_dir.glob("frame_*.png")
        )

    depth_paths: list[Path] = []
    if depth_dir.is_dir():
        depth_paths = sorted(depth_dir.glob("frame_*.npy"))

    has_video = video.is_file()
    if not has_video and not frame_paths:
        raise PackageError("Package needs video.mp4 and/or frames/frame_*.jpg")

    return PackageInfo(
        root=root,
        metadata=metadata,
        has_video=has_video,
        frame_paths=frame_paths,
        depth_paths=depth_paths,
    )


def write_metadata(path: Path, metadata: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
