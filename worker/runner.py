import json
from datetime import datetime, timezone

from backend.app.schemas import JobStage
from backend.app.storage import InMemoryJobStore
from worker.pipeline import GaussianPipeline, PipelineError


class WorkerRunner:
    def __init__(self, store: InMemoryJobStore, pipeline: GaussianPipeline) -> None:
        self.store = store
        self.pipeline = pipeline

    def process(self, job_id: str) -> dict[str, object]:
        job = self.store.get_job(job_id)
        if not job:
            raise ValueError(f"unknown job {job_id}")

        try:
            # 🔴 старт реальной работы
            self.store.set_stage(
                job_id,
                JobStage.ingest,
                5,
                "Starting pipeline"
            )

            output = self.pipeline.run(
                job_id,
                job.quality_preset.value
            )

            # 🟢 успех
            self.store.set_stage(
                job_id,
                JobStage.export,
                100,
                "Completed successfully"
            )

        except PipelineError as error:
            self.store.set_failure(job_id, error.code)

            self.store.set_stage(
                job_id,
                JobStage.failed,
                100,
                str(error)
            )
            raise

        event = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "jobId": job_id,
            "qualityPreset": job.quality_preset.value,
            "artifactPath": str(output.artifact_path),
            "metadataPath": str(output.metadata_path),
            "coverageScore": output.metrics.coverage_score,
            "reprojectionError": output.metrics.reprojection_error,
            "trainingLoss": output.metrics.training_loss,
            "registeredImages": output.metrics.registered_images,
            "sparsePoints": output.metrics.sparse_points,
        }

        return event


def serialize_event(event: dict[str, object]) -> str:
    return json.dumps(event, sort_keys=True)