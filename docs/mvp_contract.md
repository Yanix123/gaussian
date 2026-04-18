# MVP Contract

## Product scope

- Platform: iOS only
- Processing mode: cloud GPU
- Target turnaround time: 5-20 minutes per scene
- Recommended input: 80-150 photos (object), 120-200 photos (room)

## Quality presets

| Preset | Photos | Max processing time | Target use case |
| --- | --- | --- | --- |
| low | 40-80 | <= 7 min | quick preview |
| medium | 80-150 | <= 15 min | standard object scan |
| high | 120-220 | <= 25 min | room/detail capture |

## SLA (MVP)

- API availability: 99.5% monthly
- Job completion success rate: >= 70% on curated benchmark scenes
- P95 job startup delay (queued to running): <= 3 minutes
- P95 result fetch latency (`GET /jobs/{id}`): <= 500 ms

## Job states

- `queued`: accepted, waiting for worker
- `running`: pipeline started
- `failed`: terminal error with machine-readable code
- `done`: artifact generated and downloadable

## Job stages and progress

- `ingest` (0-20%): frame ingestion and dataset checks
- `colmap` (20-55%): camera poses and sparse reconstruction
- `train` (55-85%): Gaussian training step (simulated by default in local env)
- `export` (85-99%): viewer-compatible artifact export
- `done`/`failed` (100%): terminal stage

Each `GET /jobs/{id}` response includes:

- `stage`
- `progress` (0-100)
- `statusMessage`

## Failure reasons (initial set)

- `INGEST_VALIDATION_FAILED`
- `INSUFFICIENT_COVERAGE`
- `POSE_ESTIMATION_FAILED`
- `TRAINING_DIVERGED`
- `EXPORT_FAILED`
- `PIPELINE_COMMAND_FAILED`

## Runtime configuration

- `GAUSSIAN_SIMULATE=1` keeps pipeline runnable without installed COLMAP/gsplat binaries.
- `GAUSSIAN_SIMULATE=0` enables command execution mode.
- `COLMAP_BINARY` points to the COLMAP executable.
- `GS_TRAIN_COMMAND` accepts template args: `{job_id}`, `{uploads_dir}`, `{train_dir}`.
- Real mode expects training output artifact in `{train_dir}` with extension `.splat`, `.ply`, `.obj`, `.glb`, or `.usdz`.
