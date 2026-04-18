import os
from urllib.parse import urlparse

from fastapi.testclient import TestClient

os.environ["GAUSSIAN_SIMULATE"] = "1"
os.environ["GAUSSIAN_ALLOW_SIMULATED_JOBS"] = "1"

from backend.app.main import app


client = TestClient(app)


def test_job_lifecycle() -> None:
    files = [
        ("files", (f"frame_{i}.jpg", f"fake-jpeg-{i}".encode("utf-8"), "image/jpeg"))
        for i in range(12)
    ]
    created = client.post(
        "/jobs",
        files=files,
    )
    assert created.status_code == 201
    payload = created.json()
    job_id = payload["job_id"]
    artifact_url = payload["artifact_url"]
    artifact_name = artifact_url.rsplit("/", 1)[-1]

    assert payload["status"] == "done"
    assert artifact_url.endswith(f"/{artifact_name}")
    assert artifact_name.endswith((".obj", ".usdz"))
    assert payload["failure_reason"] is None
    assert payload["jobId"] == job_id

    job = client.get(f"/jobs/{job_id}")
    assert job.status_code == 200
    assert job.json()["status"] == "done"
    assert job.json()["artifact_url"].endswith(f"/{artifact_name}")

    artifact = client.get(f"/jobs/{job_id}/artifact")
    assert artifact.status_code == 200
    assert artifact.json()["artifact_url"].endswith(f"/{artifact_name}")

    scene_path = urlparse(artifact_url).path
    scene_file = client.get(scene_path)
    assert scene_file.status_code == 200
    if artifact_name.endswith(".obj"):
        assert "o " in scene_file.text


def test_jobs_requires_multipart_files() -> None:
    bad = client.post("/jobs", json={"x": "y"})
    assert bad.status_code == 422
