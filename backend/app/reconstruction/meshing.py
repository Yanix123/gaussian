import open3d as o3d
import numpy as np
from pathlib import Path


def colmap_to_mesh(ply_path: str, out_path: str):
    pcd = o3d.io.read_point_cloud(ply_path)

    pcd.estimate_normals()

    mesh, densities = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(
        pcd, depth=9
    )

    mesh.compute_vertex_normals()

    o3d.io.write_triangle_mesh(out_path, mesh)

    return out_path