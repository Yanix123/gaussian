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

echo "Installing requirements (safe to re-run)..."
if ! python3 -m pip install -r backend/requirements.txt >/dev/null 2>&1; then
  echo "Skipping auto-install (pip unavailable or externally managed)."
  echo "If startup fails, run inside a venv:"
  echo "  python3 -m venv .venv && source .venv/bin/activate && python -m pip install -r backend/requirements.txt"
fi

echo ""
echo "Backend starting for iPhone testing"
echo "API URL for Xcode env GAUSSIAN_API_BASE_URL:"
echo "http://${MAC_IP}:${PORT}"
echo ""
echo "Open this URL from iPhone browser (same Wi-Fi):"
echo "http://${MAC_IP}:${PORT}/docs"
echo ""

exec python3 -m uvicorn backend.app.main:app --host "$HOST" --port "$PORT"
