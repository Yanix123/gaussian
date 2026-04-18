#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"

if [[ -z "${MAC_IP:-}" ]]; then
  MAC_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [[ -z "${MAC_IP:-}" ]]; then
  MAC_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi
if [[ -z "${MAC_IP:-}" ]]; then
  MAC_IP="127.0.0.1"
fi

if [[ -z "${GS_TRAIN_COMMAND:-}" ]]; then
  echo "GS_TRAIN_COMMAND is required for real mode."
  echo "Example:"
  echo "GS_TRAIN_COMMAND=\"python /opt/gaussian-splatting/train.py -s {uploads_dir} -m {train_dir}\" \\"
  echo "  ./scripts/start_real_pipeline_backend.sh"
  exit 1
fi

echo "Installing requirements (safe to re-run)..."
if ! python3 -m pip install -r backend/requirements.txt >/dev/null 2>&1; then
  echo "Skipping auto-install (pip unavailable or externally managed)."
  echo "If startup fails, run inside a venv:"
  echo "  python3 -m venv .venv && source .venv/bin/activate && python -m pip install -r backend/requirements.txt"
fi

echo ""
echo "Backend starting in REAL pipeline mode"
echo "API URL for Xcode env GAUSSIAN_API_BASE_URL:"
echo "http://${MAC_IP}:${PORT}"
echo ""
echo "COLMAP binary: ${COLMAP_BINARY:-colmap}"
echo "GS train command template: ${GS_TRAIN_COMMAND}"
echo ""

export GAUSSIAN_SIMULATE=0
exec python3 -m uvicorn backend.app.main:app --host "$HOST" --port "$PORT"
