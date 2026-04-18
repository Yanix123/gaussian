# Stabilization and Beta Checklist

## Load and quality test plan

- API load smoke: 20 concurrent job creations over 5 minutes
- Worker backlog test: enqueue 100 jobs and track queue lag
- Quality benchmark: 30 fixed scenes (objects + indoor rooms)
- Failure budget: <= 5% unknown errors, <= 30% quality-related failure

## Cost/performance levers

- Dynamic quality downgrade to `medium` when queue lag exceeds threshold
- TTL for raw photos default 30 days; configurable to 90 days
- Artifact LOD generation for reduced CDN egress and faster mobile load

## Beta launch gates

- Crash-free sessions >= 99%
- P95 time-to-result <= 15 min for medium preset
- Monitoring dashboards in place (queue lag, error rate, gpu utilization)
- Incident playbook for worker failures and artifact download errors
