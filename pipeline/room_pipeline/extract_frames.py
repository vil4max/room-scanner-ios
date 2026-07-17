"""Frame extraction and blur filtering.

Why: 30 fps video is redundant for SfM; blurry frames break matching.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import cv2
import numpy as np


def extract_keyframes(video: Path, out_dir: Path, fps: float = 1.5) -> list[Path]:
    """Extract stills with ffmpeg; returns sorted frame paths."""
    out_dir.mkdir(parents=True, exist_ok=True)
    pattern = str(out_dir / "frame_%05d.jpg")
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(video),
        "-vf",
        f"fps={fps}",
        pattern,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr[-500:]}")
    return sorted(out_dir.glob("frame_*.jpg"))


def laplacian_variance(image_bgr: np.ndarray) -> float:
    gray = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2GRAY)
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


def drop_blurry(paths: list[Path], threshold: float = 80.0) -> list[Path]:
    """Keep frames whose Laplacian variance is above threshold."""
    keep: list[Path] = []
    for path in paths:
        image = cv2.imread(str(path))
        if image is None:
            continue
        if laplacian_variance(image) >= threshold:
            keep.append(path)
    # Soft-fail: if everything is "blurry", keep originals so later stages can still run.
    return keep if keep else list(paths)


def ensure_frames(
    video: Path | None,
    existing: list[Path],
    frames_dir: Path,
    fps: float,
    blur_threshold: float,
) -> list[Path]:
    frames = list(existing)
    if not frames and video is not None and video.is_file():
        frames = extract_keyframes(video, frames_dir, fps=fps)
    if not frames:
        raise RuntimeError("No frames available after extraction")
    return drop_blurry(frames, threshold=blur_threshold)
