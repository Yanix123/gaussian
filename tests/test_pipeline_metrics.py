from worker.config import build_default_config
from worker.pipeline import GaussianPipeline


def test_pipeline_quality_metrics_order() -> None:
    config = build_default_config()
    for job_id in ("low-job", "high-job"):
        frames_dir = config.uploads_root / job_id / "frames"
        frames_dir.mkdir(parents=True, exist_ok=True)
        for index in range(12):
            (frames_dir / f"frame_{index}.jpg").write_bytes(b"fake-jpeg-data")

    pipeline = GaussianPipeline(config)
    low = pipeline.run("low-job", "low").metrics
    high = pipeline.run("high-job", "high").metrics

    assert high.coverage_score > low.coverage_score
    assert high.reprojection_error < low.reprojection_error
