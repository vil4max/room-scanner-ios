"""Meshing and point-cloud cleanup.

Open3D is optional: without it we still write ASCII PLY for Results import later.
"""

from __future__ import annotations

import logging
from pathlib import Path

import numpy as np

logger = logging.getLogger(__name__)


def voxel_downsample(points: np.ndarray, colors: np.ndarray, voxel_m: float) -> tuple[np.ndarray, np.ndarray]:
    if points.shape[0] == 0 or voxel_m <= 0:
        return points, colors
    keys = np.floor(points / voxel_m).astype(np.int64)
    # Unique voxels via structured view
    flat = keys[:, 0] + (keys[:, 1] * 73856093) + (keys[:, 2] * 19349663)
    _, indices = np.unique(flat, return_index=True)
    return points[indices], colors[indices]


def write_ply(path: Path, points: np.ndarray, colors: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    n = points.shape[0]
    rgb = np.clip(colors * 255.0, 0, 255).astype(np.uint8)
    with path.open("w", encoding="utf-8") as f:
        f.write("ply\nformat ascii 1.0\n")
        f.write(f"element vertex {n}\n")
        f.write("property float x\nproperty float y\nproperty float z\n")
        f.write("property uchar red\nproperty uchar green\nproperty uchar blue\n")
        f.write("end_header\n")
        for i in range(n):
            x, y, z = points[i]
            r, g, b = rgb[i]
            f.write(f"{x:.5f} {y:.5f} {z:.5f} {int(r)} {int(g)} {int(b)}\n")


def try_open3d_mesh(
    points: np.ndarray,
    colors: np.ndarray,
    out_obj: Path,
    voxel_m: float,
) -> bool:
    try:
        import open3d as o3d
    except ImportError:
        logger.info("open3d not installed; skipping triangle mesh")
        return False

    pcd = o3d.geometry.PointCloud()
    pcd.points = o3d.utility.Vector3dVector(points)
    pcd.colors = o3d.utility.Vector3dVector(colors)
    pcd = pcd.voxel_down_sample(voxel_m)
    pcd.estimate_normals()
    # Ball pivoting needs radii; Poisson is heavier — use simple alpha for MVP.
    mesh = o3d.geometry.TriangleMesh.create_from_point_cloud_alpha_shape(pcd, alpha=max(voxel_m * 4, 0.05))
    if mesh.is_empty():
        logger.warning("Alpha shape mesh empty; writing point cloud only")
        return False
    mesh.compute_vertex_normals()
    out_obj.parent.mkdir(parents=True, exist_ok=True)
    o3d.io.write_triangle_mesh(str(out_obj), mesh)
    return True
