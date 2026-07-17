"""Semantic labeling helpers and optional SAM 3.1 hook.

Why vote in voxel space: multi-view masks disagree; majority keeps walls/floor stable.
"""

from __future__ import annotations

import logging
from typing import Sequence

import numpy as np

logger = logging.getLogger(__name__)

# Stable class ids for export colors / USD materials later.
LABEL_IDS = {
    "unknown": 0,
    "wall": 1,
    "floor": 2,
    "ceiling": 3,
    "door": 4,
    "window": 5,
    "furniture": 6,
}

LABEL_COLORS = {
    0: (0.5, 0.5, 0.5),
    1: (0.75, 0.75, 0.8),
    2: (0.45, 0.35, 0.25),
    3: (0.9, 0.9, 0.95),
    4: (0.6, 0.35, 0.15),
    5: (0.35, 0.65, 0.9),
    6: (0.2, 0.55, 0.35),
}


def vote_labels(label_lists: Sequence[np.ndarray], default: int = 0) -> np.ndarray:
    """Per-point majority vote across views; ties keep the first mode."""
    if not label_lists:
        return np.zeros((0,), dtype=np.int32)
    stacked = np.stack([np.asarray(x, dtype=np.int32) for x in label_lists], axis=0)
    # bincount along views for each point
    n_points = stacked.shape[1]
    out = np.full(n_points, default, dtype=np.int32)
    max_label = int(stacked.max()) if stacked.size else 0
    for i in range(n_points):
        counts = np.bincount(stacked[:, i], minlength=max_label + 1)
        out[i] = int(np.argmax(counts))
    return out


def heuristic_labels_from_points(points: np.ndarray) -> np.ndarray:
    """Cheap offline labels without SAM: floor = lowest Y band, ceiling = highest, else wall.

    ARKit camera space is Y-down in image unproject; after unproject without pose,
    we treat the axis with largest extent horizontally as XZ and lowest percentile as floor.
    """
    if points.size == 0:
        return np.zeros((0,), dtype=np.int32)
    # Use vertical axis = Y in OpenCV camera coords (positive down); invert for "up".
    up = -points[:, 1]
    lo = np.percentile(up, 10)
    hi = np.percentile(up, 90)
    labels = np.full(points.shape[0], LABEL_IDS["wall"], dtype=np.int32)
    labels[up <= lo + 0.05] = LABEL_IDS["floor"]
    labels[up >= hi - 0.05] = LABEL_IDS["ceiling"]
    return labels


def colors_for_labels(labels: np.ndarray) -> np.ndarray:
    colors = np.zeros((labels.shape[0], 3), dtype=np.float64)
    for lid, rgb in LABEL_COLORS.items():
        colors[labels == lid] = rgb
    return colors


def try_sam3_labels(frame_paths: list, concepts: list[str]) -> None:
    """Soft probe for SAM 3.1; real PCS wiring lives behind HF auth."""
    try:
        import importlib.util

        if importlib.util.find_spec("sam3") is None:
            logger.info("sam3 not installed; using heuristic / vote labels")
            return
        logger.info("sam3 present for concepts=%s frames=%d — integrate PCS next", concepts, len(frame_paths))
    except Exception as exc:  # noqa: BLE001
        logger.warning("SAM 3 probe failed: %s", exc)


def run_semantics(
    points: np.ndarray,
    backend: str,
    concepts: list[str],
    frame_paths: list | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    """Return (labels, semantic_colors)."""
    if backend == "sam3" and frame_paths:
        try_sam3_labels(frame_paths, concepts)
    labels = heuristic_labels_from_points(points)
    return labels, colors_for_labels(labels)
