# Gaussian Scan MVP

End-to-end MVP for `iOS capture -> cloud Gaussian Splat processing -> mobile 3D viewer`.

## Repository layout

- `docs/` product and API contracts
- `backend/` API service for jobs, uploads, statuses, artifacts
- `worker/` GPU pipeline orchestration and quality metrics
- `ios/` SwiftUI app skeleton for guided capture and scene viewer
- `tests/` smoke tests for API contract and pipeline transitions

## MVP flow

1. iOS captures guided photo set and validates frame quality.
2. Client uploads selected photos to `POST /jobs` (`multipart/form-data`).
3. Backend runs synchronous reconstruction and writes artifact to `/artifacts/{jobId}/model.obj`.
4. iOS receives `artifact_url` and opens it in the viewer.

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.app.main:app --reload
```

Run tests:

```bash
pytest -q
```

Phone testing instructions:

- `docs/iphone_testing.md`
- Quick backend launcher: `./scripts/start_iphone_backend.sh`
