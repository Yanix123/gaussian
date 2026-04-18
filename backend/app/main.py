from dataclasses import dataclass
import logging
import os
import traceback
from pathlib import Path
from typing import Any
from typing import Callable
from typing import Optional
from uuid import uuid4

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from worker.config import build_default_config
from worker.pipeline import GaussianPipeline
from worker.pipeline import PipelineError


@dataclass
class JobState:
    job_id: str
    status: str = "queued"
    stage: str = "ingest"
    progress: int = 0
    status_message: Optional[str] = None
    failure_reason: Optional[str] = None
    artifact_url: Optional[str] = None


app = FastAPI()
logger = logging.getLogger("backend.jobs")
job_store: dict[str, JobState] = {}

REPO_ROOT = Path(__file__).resolve().parents[2]
ARTIFACT_DIR = Path(os.getenv("GAUSSIAN_ARTIFACT_DIR", str(REPO_ROOT / "artifacts")))
UPLOAD_DIR = Path(os.getenv("GAUSSIAN_UPLOAD_DIR", str(REPO_ROOT / "uploads")))
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
PIPELINE_CONFIG = build_default_config()
PIPELINE = GaussianPipeline(PIPELINE_CONFIG)
ALLOW_SIMULATED_JOBS = os.getenv("GAUSSIAN_ALLOW_SIMULATED_JOBS", "0") == "1"

app.mount("/artifacts", StaticFiles(directory=str(ARTIFACT_DIR)), name="artifacts")


def _sanitize_for_json(value: Any) -> Any:
    if isinstance(value, bytes):
        return "<binary>"
    if isinstance(value, dict):
        return {k: _sanitize_for_json(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_sanitize_for_json(v) for v in value]
    return value


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    errors = _sanitize_for_json(exc.errors())
    return JSONResponse(status_code=422, content={"detail": errors})


def _run_pipeline_reconstruction(
    job_id: str,
    quality_preset: str,
    on_stage: Optional[Callable[[str], None]] = None,
) -> tuple[Path, str]:
    output = PIPELINE.run(job_id=job_id, quality_preset=quality_preset, on_stage=on_stage)
    artifact = output.artifact_path
    if artifact.suffix.lower() == ".obj":
        artifact = _postprocess_artifact(artifact)
    return artifact, f"Pipeline completed ({quality_preset})"


def _postprocess_artifact(obj_path: Path) -> Path:
    try:
        from backend.app.reconstruction.export_usdz import try_convert_to_usdz

        usdz_path = obj_path.with_suffix(".usdz")
        ok, _message = try_convert_to_usdz(str(obj_path), str(usdz_path))
        if ok:
            return usdz_path
    except Exception:
        pass
    return obj_path


def _serialize_job(job: JobState) -> dict[str, Any]:
    return {
        "job_id": job.job_id,
        "jobId": job.job_id,
        "status": job.status,
        "stage": job.stage,
        "progress": job.progress,
        "status_message": job.status_message,
        "statusMessage": job.status_message,
        "failure_reason": job.failure_reason,
        "failureReason": job.failure_reason,
        "artifact_url": job.artifact_url,
        "artifactUrl": job.artifact_url,
    }


@app.post("/jobs")
async def create_job(
    request: Request,
    files: list[UploadFile] = File(...),
    quality_preset: str = Form("medium"),
):
    if not files:
        raise HTTPException(status_code=400, detail="No files uploaded")

    job_id = str(uuid4())
    state = JobState(job_id=job_id, status="running", stage="ingest", progress=5, status_message="Saving input files")
    job_store[job_id] = state

    upload_dir = UPLOAD_DIR / job_id / "frames"
    upload_dir.mkdir(parents=True, exist_ok=True)
    artifact_job_dir = ARTIFACT_DIR / job_id
    artifact_job_dir.mkdir(parents=True, exist_ok=True)

    try:
        for i, file in enumerate(files):
            content = await file.read()
            if not content:
                continue
            suffix = Path(file.filename or "").suffix or ".jpg"
            path = upload_dir / f"{i}{suffix}"
            path.write_bytes(content)

        if PIPELINE_CONFIG.simulate and not ALLOW_SIMULATED_JOBS:
            state.status = "failed"
            state.stage = "failed"
            state.progress = 100
            state.failure_reason = "SIMULATION_MODE_DISABLED_FOR_REAL_SCAN"
            state.status_message = (
                "Backend is running in simulation mode. Start real pipeline backend "
                "or set GAUSSIAN_ALLOW_SIMULATED_JOBS=1 only for debug."
            )
            return JSONResponse(_serialize_job(state), status_code=201)

        state.stage = "colmap"
        state.progress = 25
        state.status_message = "Running COLMAP"

        def on_pipeline_stage(stage: str) -> None:
            stage_progress = {
                "colmap": (25, "Running COLMAP"),
                "training": (50, "Training scene representation"),
                "meshing": (75, "Building mesh from reconstructed points"),
                "export": (90, "Exporting viewer artifact"),
            }
            progress, message = stage_progress.get(stage, (state.progress, state.status_message or "Processing"))
            state.stage = stage
            state.progress = progress
            state.status_message = message

        artifact_path, msg = _run_pipeline_reconstruction(job_id, quality_preset, on_stage=on_pipeline_stage)

        state.stage = "done"
        state.status = "done"
        state.progress = 100
        state.status_message = msg
        state.artifact_url = f"{request.base_url}artifacts/{job_id}/{artifact_path.name}"
        state.failure_reason = None
    except PipelineError as error:
        state.status = "failed"
        state.stage = "failed"
        state.progress = 100
        state.failure_reason = error.code
        state.status_message = str(error)
        logger.warning("Job %s pipeline error: %s", job_id, error)
    except Exception as error:
        state.status = "failed"
        state.stage = "failed"
        state.progress = 100
        state.failure_reason = "RECONSTRUCTION_FAILED"
        tb = traceback.format_exc()
        logger.error("Job %s reconstruction failed: %s\n%s", job_id, error, tb)
        detail = str(error)
        if os.getenv("GAUSSIAN_VERBOSE_ERRORS", "0") == "1":
            detail = f"{detail}\n\n{tb}"[:12000]
        state.status_message = detail

    return JSONResponse(_serialize_job(state), status_code=201)


@app.get("/jobs/{job_id}")
def get_job(job_id: str):
    state = job_store.get(job_id)
    if not state:
        raise HTTPException(status_code=404, detail="Job not found")
    return JSONResponse(_serialize_job(state))


@app.get("/jobs/{job_id}/artifact")
def get_artifact(job_id: str):
    state = job_store.get(job_id)
    if not state:
        raise HTTPException(status_code=404, detail="Job not found")
    if not state.artifact_url:
        raise HTTPException(status_code=409, detail="Artifact is not ready")
    return {"url": state.artifact_url, "artifact_url": state.artifact_url, "artifactUrl": state.artifact_url}