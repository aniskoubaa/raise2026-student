#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — Docker install path.
#
# Auto-installs Docker Engine + Compose v2 (from Ubuntu's apt repos) if they are
# missing, then builds the image and reports how to enter the container. Does NOT
# auto-start a long-running container — the demos under sim/demos/ launch what
# they need.
#
# The Docker image is ALWAYS ROS 2 Jazzy + Gazebo Harmonic (Dockerfile
# ARG ROS_DISTRO=jazzy), regardless of the host's Ubuntu version — the container
# isolates the OS, so a 22.04 or non-Ubuntu host still gets the tested Jazzy stack.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${SIM_DIR}/.env"
COMPOSE_DIR="${SIM_DIR}/docker"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — run detect_hardware.sh first." >&2
  exit 1
fi

# ── Auto-install Docker Engine + Compose v2 if missing ─────────────────────
# Uses Ubuntu's own repos (docker.io + docker-compose-v2): simplest, no remote
# curl|sh, works on 22.04 and 24.04. For the very latest Docker CE, install from
# get.docker.com by hand instead.
install_docker() {
  echo "[install_docker] Docker not found — installing docker.io + docker-compose-v2 (sudo)…"
  if ! command -v apt-get >/dev/null 2>&1; then
    cat >&2 <<'EOF'
✗ Auto-install only supports apt-based systems (Ubuntu/Debian).
  Install Docker Engine + Compose v2 manually, then re-run:
      https://docs.docker.com/engine/install/
EOF
    exit 1
  fi
  sudo apt-get update
  sudo apt-get install -y docker.io docker-compose-v2
  # Enable + start the daemon (no-op if already running).
  sudo systemctl enable --now docker || true
  # Let the current user run docker without sudo (takes effect on next login).
  if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    sudo usermod -aG docker "$USER"
    echo "[install_docker] Added $USER to the 'docker' group."
    echo "[install_docker] Log out and back in (or run 'newgrp docker') for it to take"
    echo "[install_docker] effect in new shells. This run will use sudo where needed."
  fi
}

if ! command -v docker >/dev/null 2>&1; then
  install_docker
fi

# ── Decide whether docker needs sudo in THIS shell ─────────────────────────
# Right after `usermod -aG docker`, the new group isn't active until re-login,
# so the current shell may still need sudo. Detect and adapt transparently.
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  if sudo docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
    echo "[install_docker] Using 'sudo docker' for this run (group not active yet)."
  else
    echo "✗ Docker is installed but the daemon is not reachable." >&2
    echo "  Try: sudo systemctl start docker" >&2
    exit 1
  fi
fi

# ── Ensure Compose v2 plugin is available ──────────────────────────────────
if ! $DOCKER compose version >/dev/null 2>&1; then
  echo "[install_docker] Docker Compose v2 plugin missing — installing docker-compose-v2…"
  sudo apt-get update && sudo apt-get install -y docker-compose-v2
  if ! $DOCKER compose version >/dev/null 2>&1; then
    echo "✗ Docker Compose v2 still unavailable after install." >&2
    exit 1
  fi
fi

# shellcheck disable=SC1091
# shellcheck disable=SC1090
source "$ENV_FILE"

# ── GPU: best-effort nvidia-container-toolkit for GPU tiers ─────────────────
# Needed for the GPU compose override to pass the card into the container.
# Best-effort: a failure here just means you fall back to the CPU compose.
install_nvidia_toolkit() {
  if dpkg -s nvidia-container-toolkit >/dev/null 2>&1; then
    return 0
  fi
  echo "[install_docker] Installing nvidia-container-toolkit (GPU tier)…"
  {
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
      | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
      | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker || true
  } || {
    echo "[install_docker] ⚠ nvidia-container-toolkit setup failed — GPU passthrough"
    echo "[install_docker]   may not work. The CPU compose still runs fine."
    return 1
  }
}

compose_args=(-f "${COMPOSE_DIR}/docker-compose.yml")
if [[ "${RAISE_HW_TIER:-CPU_ONLY}" == "GPU_LOW" || "${RAISE_HW_TIER:-CPU_ONLY}" == "GPU_HIGH" ]]; then
  install_nvidia_toolkit || true
  compose_args+=(-f "${COMPOSE_DIR}/docker-compose.gpu.yml")
  echo "[install_docker] GPU tier (${RAISE_HW_TIER}) — stacking GPU compose override."
else
  echo "[install_docker] CPU-only tier — using CPU compose."
fi

# Build with host UID/GID so workspace writes are not root-owned on the host.
export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"

$DOCKER compose --env-file "$ENV_FILE" "${compose_args[@]}" build

# ── In-container image smoke test ───────────────────────────────────────────
# Verify the image itself is sane (ROS + Gazebo Harmonic + the fragile
# cv_bridge/numpy import). The workspace overlay is built on first entry, so we
# don't test it here. Non-fatal — just informs.
echo
echo "[install_docker] Running in-container image smoke test…"
if $DOCKER compose --env-file "$ENV_FILE" "${compose_args[@]}" run --rm raise2026 bash -lc '
    fail=0
    command -v ros2 >/dev/null 2>&1 && echo "  ✓ ros2 CLI (ROS 2 ${ROS_DISTRO})" || { echo "  ✗ ros2 CLI"; fail=1; }
    v=$(gz sim --version 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1)
    [ "${v%%.*}" = "8" ] && echo "  ✓ gz sim ${v} (Harmonic)" || { echo "  ✗ gz sim (got: ${v:-none}, want major 8)"; fail=1; }
    python3 -c "import numpy,cv_bridge; assert int(numpy.__version__.split(\".\")[0])<2" 2>/dev/null \
      && echo "  ✓ cv_bridge under numpy<2" || { echo "  ✗ cv_bridge/numpy"; fail=1; }
    exit $fail
  '; then
  echo "[install_docker] ✓ Image smoke test passed."
else
  echo "[install_docker] ⚠ Image smoke test had issues (see above). The image built,"
  echo "[install_docker]   but verify the points marked ✗ before relying on it."
fi

cat <<EOF

✓ Image built: raise2026-sim:latest  (ROS 2 Jazzy + Gazebo Harmonic)

To enter the container:
    ${DOCKER} compose --env-file ${ENV_FILE} ${compose_args[*]} run --rm raise2026

First time inside the container, build the workspace (all ROS deps are pre-baked):
    colcon build --symlink-install
    source install/setup.bash
EOF

if [[ "$DOCKER" == "sudo docker" ]]; then
  cat <<EOF

ℹ You're using 'sudo docker' because the 'docker' group isn't active in this
  shell yet. Log out and back in (or run 'newgrp docker') and you can drop the
  'sudo' prefix from the commands above.
EOF
fi
