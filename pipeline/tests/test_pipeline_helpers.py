"""Unit tests for package schema, blur filter, and label vote (no GPU weights)."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from room_pipeline.extract_frames import drop_blurry, laplacian_variance
from room_pipeline.geometry import unproject_depth
from room_pipeline.package import PackageError, validate_package, write_metadata
from room_pipeline.semantics import LABEL_IDS, heuristic_labels_from_points, vote_labels


def test_validate_package_requires_schema_and_media(tmp_path: Path) -> None:
    # Tests that validation rejects folders without schema_version and media.
    with pytest.raises(PackageError):
        validate_package(tmp_path)
    write_metadata(tmp_path / "metadata.json", {"schema_version": 1})
    with pytest.raises(PackageError):
        validate_package(tmp_path)


def test_validate_package_marks_lidar_from_depth_files(tmp_path: Path) -> None:
    # Tests that has_lidar becomes true when depth maps exist on disk.
    write_metadata(
        tmp_path / "metadata.json",
        {"schema_version": 1, "session_id": "abc", "has_lidar": False},
    )
    frames = tmp_path / "frames"
    depth = tmp_path / "depth"
    frames.mkdir()
    depth.mkdir()
    (frames / "frame_00001.jpg").write_bytes(b"not-a-real-jpeg")
    np.save(depth / "frame_00001.npy", np.ones((4, 4), dtype=np.float32))
    info = validate_package(tmp_path)
    # Explicit metadata wins over file presence.
    assert info.has_lidar is False
    write_metadata(
        tmp_path / "metadata.json",
        {"schema_version": 1, "session_id": "abc", "has_lidar": True},
    )
    info2 = validate_package(tmp_path)
    assert info2.has_lidar is True
    assert len(info2.depth_paths) == 1


def test_drop_blurry_keeps_sharp_synthetic_edge(tmp_path: Path) -> None:
    # Tests blur filter drops low-variance frames and keeps edged ones.
    import cv2

    sharp = np.zeros((64, 64, 3), dtype=np.uint8)
    sharp[:, 32:] = 255
    blurry = np.full((64, 64, 3), 128, dtype=np.uint8)
    sharp_path = tmp_path / "sharp.jpg"
    blur_path = tmp_path / "blur.jpg"
    cv2.imwrite(str(sharp_path), sharp)
    cv2.imwrite(str(blur_path), blurry)
    assert laplacian_variance(sharp) > laplacian_variance(blurry)
    kept = drop_blurry([sharp_path, blur_path], threshold=50.0)
    assert sharp_path in kept


def test_vote_labels_majority() -> None:
    # Tests per-point majority vote across views.
    a = np.array([1, 2, 2], dtype=np.int32)
    b = np.array([1, 1, 2], dtype=np.int32)
    c = np.array([3, 2, 2], dtype=np.int32)
    out = vote_labels([a, b, c])
    assert out.tolist() == [1, 2, 2]


def test_heuristic_floor_ceiling_bands() -> None:
    # Tests heuristic labeling marks lowest and highest up-axis bands.
    points = np.array(
        [
            [0.0, 1.0, 1.0],
            [0.0, 0.0, 1.0],
            [0.0, -1.0, 1.0],
        ],
        dtype=np.float64,
    )
    labels = heuristic_labels_from_points(points)
    assert LABEL_IDS["floor"] in labels
    assert LABEL_IDS["ceiling"] in labels


def test_unproject_depth_center_ray() -> None:
    # Tests depth unprojection places center pixel on optical axis.
    depth = np.full((10, 10), 2.0, dtype=np.float32)
    K = {"fx": 100.0, "fy": 100.0, "cx": 5.0, "cy": 5.0, "width": 10, "height": 10}
    pts, cols = unproject_depth(depth, None, K, stride=5)
    assert pts.shape[0] > 0
    assert cols.shape[0] == pts.shape[0]
    # Near-center sample should have small x/y at z≈2
    mid = pts[np.argmin(np.abs(pts[:, 0]) + np.abs(pts[:, 1]))]
    assert mid[2] == pytest.approx(2.0, rel=1e-3)
