#!/usr/bin/env bash
# Install COLMAP + graphdeco-inria/gaussian-splatting (CUDA extensions) for Linux GPU (e.g. RunPod).
# Layout expected by worker/config.py: app repo at /gaussian, sibling at /gaussian-splatting.
# Usage:
#   sudo bash scripts/install_gaussian_splatting_runpod.sh
# Override:
#   GS_ROOT=/workspace/gaussian-splatting TORCH_CUDA=cu124 sudo -E bash scripts/install_gaussian_splatting_runpod.sh

set -euo pipefail

GS_ROOT="${GS_ROOT:-/gaussian-splatting}"
GS_REPO="${GS_REPO:-https://github.com/graphdeco-inria/gaussian-splatting.git}"
# PyTorch wheel tag: cu121, cu124, cu128 — must match the CUDA toolkit nvcc you build with.
TORCH_CUDA="${TORCH_CUDA:-cu124}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo so apt can install COLMAP and build tools."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  git \
  ca-certificates \
  build-essential \
  cmake \
  ninja-build \
  colmap \
  libgl1 \
  libglib2.0-0 \
  python3 \
  python3-venv \
  python3-pip

if [[ ! -d "${GS_ROOT}/.git" ]]; then
  mkdir -p "$(dirname "${GS_ROOT}")"
  git clone --recursive "${GS_REPO}" "${GS_ROOT}"
else
  git -C "${GS_ROOT}" submodule update --init --recursive
fi

python3 -m venv "${GS_ROOT}/.venv"
# shellcheck source=/dev/null
source "${GS_ROOT}/.venv/bin/activate"
python -m pip install -U pip setuptools wheel

if [[ -d /usr/local/cuda ]]; then
  export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
  export PATH="${CUDA_HOME}/bin:${PATH}"
fi

# Install PyTorch (pick TORCH_CUDA to match your driver/CUDA; see https://pytorch.org/get-started/locally/)
python -m pip install "torch" "torchvision" "torchaudio" --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"

python -m pip install plyfile tqdm opencv-python

cd "${GS_ROOT}"
# Common RunPod GPUs (add yours if build fails or is slow)
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-7.0 7.5 8.0 8.6 8.9 9.0+PTX}"
python -m pip install \
  ./submodules/diff-gaussian-rasterization \
  ./submodules/simple-knn \
  --no-build-isolation

python -c "import diff_gaussian_rasterization, simple_knn, torch; print('OK torch', torch.__version__, 'cuda', torch.version.cuda)"

echo ""
echo "=== Next: app venv (FastAPI + Open3D meshing) ==="
echo "  cd /gaussian   # your clone of this repo"
echo "  python3 -m venv .venv && source .venv/bin/activate"
echo "  pip install -r backend/requirements.txt"
echo "  pip install open3d"
echo ""
echo "=== Environment for real pipeline ==="
echo "  export GAUSSIAN_SIMULATE=0"
echo "  export COLMAP_BINARY=colmap"
echo "  export GS_TRAIN_COMMAND=\"${GS_ROOT}/.venv/bin/python ${GS_ROOT}/train.py -s {uploads_dir} -m {train_dir}\""
echo "  python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000"
echo ""
