from dataclasses import dataclass
import os
import sys
from pathlib import Path


@dataclass(frozen=True)
class PipelineConfig:
    repo_root: Path
    uploads_root: Path
    work_root: Path
    artifacts_root: Path
    simulate: bool = True
    min_registered_images: int = 8
    min_sparse_points: int = 200
    colmap_binary: str = "colmap"
    gs_train_command: str = "python train.py -s {uploads_dir} -m {train_dir}"


def build_default_config() -> PipelineConfig:
    repo_root = Path(__file__).resolve().parents[1]
    sibling_gs_root = repo_root.parent / "gaussian-splatting"
    if sys.platform == "win32":
        sibling_gs_python = sibling_gs_root / ".venv" / "Scripts" / "python.exe"
    else:
        sibling_gs_python = sibling_gs_root / ".venv" / "bin" / "python"
    sibling_gs_train = sibling_gs_root / "train.py"
    if sibling_gs_python.exists() and sibling_gs_train.exists():
        default_train_command = f"{sibling_gs_python} {sibling_gs_train} -s {{uploads_dir}} -m {{train_dir}}"
    elif sibling_gs_train.exists():
        default_train_command = f"python {sibling_gs_train} -s {{uploads_dir}} -m {{train_dir}}"
    else:
        default_train_command = "python train.py -s {uploads_dir} -m {train_dir}"

    simulate = os.getenv("GAUSSIAN_SIMULATE", "1") == "1"
    min_registered_images = int(os.getenv("GAUSSIAN_MIN_REGISTERED_IMAGES", "8"))
    min_sparse_points = int(os.getenv("GAUSSIAN_MIN_SPARSE_POINTS", "200"))
    return PipelineConfig(
        repo_root=repo_root,
        uploads_root=repo_root / "uploads",
        work_root=repo_root / "work",
        artifacts_root=repo_root / "artifacts",
        simulate=simulate,
        min_registered_images=min_registered_images,
        min_sparse_points=min_sparse_points,
        colmap_binary=os.getenv("COLMAP_BINARY", "colmap"),
        gs_train_command=os.getenv(
            "GS_TRAIN_COMMAND",
            default_train_command,
        ),
    )
