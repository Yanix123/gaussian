from dataclasses import dataclass, field
from typing import Optional
from uuid import uuid4

from .schemas import JobStage, JobStatus, QualityPreset


@dataclass
class JobRecord:
    id: str
    quality_preset: QualityPreset
    expected_photo_count: int
    status: JobStatus = JobStatus.queued
    stage: JobStage = JobStage.ingest
    progress: int = 0
    status_message: Optional[str] = None
    artifact_url: Optional[str] = None
    failure_reason: Optional[str] = None
    uploads: list[str] = field(default_factory=list)


class InMemoryJobStore:
    def __init__(self) -> None:
        self._jobs: dict[str, JobRecord] = {}

    def create_job(self, quality_preset: QualityPreset, expected_photo_count: int) -> JobRecord:
        job = JobRecord(
            id=str(uuid4()),
            quality_preset=quality_preset,
            expected_photo_count=expected_photo_count,
        )
        self._jobs[job.id] = job
        return job

    def get_job(self, job_id: str) -> Optional[JobRecord]:
        return self._jobs.get(job_id)

    def set_status(self, job_id: str, status: JobStatus) -> None:
        self._jobs[job_id].status = status

    def set_stage(self, job_id: str, stage: JobStage, progress: int, status_message: Optional[str]) -> None:
        job = self._jobs[job_id]
        job.stage = stage
        job.progress = progress
        job.status_message = status_message

    def set_artifact(self, job_id: str, artifact_url: str) -> None:
        job = self._jobs[job_id]
        job.status = JobStatus.done
        job.stage = JobStage.done
        job.progress = 100
        job.status_message = "Artifact ready"
        job.artifact_url = artifact_url
        job.failure_reason = None

    def set_failure(self, job_id: str, failure_reason: str) -> None:
        job = self._jobs[job_id]
        job.status = JobStatus.failed
        job.stage = JobStage.failed
        job.failure_reason = failure_reason
