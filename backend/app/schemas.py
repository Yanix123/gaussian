from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class QualityPreset(str, Enum):
    low = "low"
    medium = "medium"
    high = "high"


class JobStatus(str, Enum):
    queued = "queued"
    running = "running"
    failed = "failed"
    done = "done"


class JobStage(str, Enum):
    ingest = "ingest"
    colmap = "colmap"
    train = "train"
    export = "export"
    done = "done"
    failed = "failed"


class CreateJobRequest(BaseModel):
    quality_preset: QualityPreset = Field(alias="qualityPreset")
    expected_photo_count: int = Field(alias="expectedPhotoCount", ge=1, le=500)


class UploadFileDescriptor(BaseModel):
    name: str
    content_type: str = Field(alias="contentType")


class CreateUploadsRequest(BaseModel):
    files: list[UploadFileDescriptor]


class UploadTarget(BaseModel):
    name: str
    upload_url: str = Field(alias="uploadUrl")


class CreateUploadsResponse(BaseModel):
    uploads: list[UploadTarget]


class JobResponse(BaseModel):
    id: str
    status: JobStatus
    stage: JobStage
    progress: int = Field(ge=0, le=100)
    status_message: Optional[str] = Field(alias="statusMessage", default=None)
    quality_preset: QualityPreset = Field(alias="qualityPreset")
    expected_photo_count: int = Field(alias="expectedPhotoCount")
    artifact_url: Optional[str] = Field(alias="artifactUrl", default=None)
    failure_reason: Optional[str] = Field(alias="failureReason", default=None)


class ArtifactResponse(BaseModel):
    job_id: str = Field(alias="jobId")
    artifact_url: str = Field(alias="artifactUrl")
