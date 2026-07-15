#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 Summer School — pre-school machine preparation.
# SELF-CONTAINED: no GitHub access needed. Ubuntu 24.04 + ROS 2 Jazzy ONLY.
#
# Installs everything the school needs that does NOT require the course code
# (the course code is handed to you on Day 1):
#   • ROS 2 Jazzy desktop + dev tools
#   • Gazebo Harmonic bridge (ros_gz)
#   • all apt + pip lab dependencies (Nav2, cv_bridge, YOLO, OpenAI client, …)
#   • the Day-2 LeRobot AI toolkit (~3 GB, from PyPI — no GitHub)
#   • rosdep, firewall multicast rule, Gazebo first-run fix
#
# ── PLATFORM POLICY ─────────────────────────────────────────────────────────
#   Ubuntu 24.04 + ROS 2 Jazzy is the ONLY supported platform.
#   • Not Ubuntu 24.04 → this script REFUSES to install. Install Ubuntu 24.04
#     (dual-boot is fine) and run it there. No Docker, no 22.04, no WSL.
#   • ROS 2 Humble present → it MUST be removed (Jazzy is the only supported
#     distro). This script points it out and offers to remove it.
#
# Usage:  ./prepare_machine.sh      (safe to re-run — every step is idempotent)
set -euo pipefail

DISTRO=jazzy   # the ONE supported ROS 2 distro

# ── 0. Ubuntu 24.04 gate ────────────────────────────────────────────────────
refuse() {
  cat >&2 <<EOF

╔══════════════════════════════════════════════════════════════════════════╗
║  RAISE 2026 supports ONE platform only: Ubuntu 24.04 + ROS 2 Jazzy.       ║
╚══════════════════════════════════════════════════════════════════════════╝

  Detected: $1

  What to do:
    • Install Ubuntu 24.04 LTS (Desktop) on your laptop — dual-boot alongside
      Windows is fine (see the HTML guide, "Choose your path").
    • Boot into Ubuntu 24.04 and run this script there.

  Not supported (the script will not install on these): any other Ubuntu
  version, other Linux distros, Windows/WSL, macOS, or Docker.
EOF
  exit 1
}

[[ "$(uname -s)" == "Linux" ]] || refuse "non-Linux OS ($(uname -s))"

# anaconda breaks ROS tooling — re-exec ourselves with it stripped.
if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
  echo "[prepare] Anaconda env '${CONDA_DEFAULT_ENV}' active — re-exec'ing without it."
  exec env -u CONDA_PREFIX -u CONDA_DEFAULT_ENV -u CONDA_PROMPT_MODIFIER -u CONDA_SHLVL \
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -v anaconda | paste -sd:)" \
    bash "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

os_id=unknown; os_version=unknown; os_codename=unknown
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  os_id="${ID:-unknown}"; os_version="${VERSION_ID:-unknown}"; os_codename="${VERSION_CODENAME:-unknown}"
fi
grep -qi microsoft /proc/version 2>/dev/null && refuse "Windows/WSL (only NATIVE Ubuntu 24.04 is supported)"
[[ "$os_id" == "ubuntu" ]]        || refuse "${os_id} ${os_version} (not Ubuntu)"
[[ "$os_version" == "24.04" ]]    || refuse "Ubuntu ${os_version} (only 24.04 is supported)"

# ── 1. Machine check ────────────────────────────────────────────────────────
cpu_cores="$(nproc)"
ram_gb=$(( ($(awk '/^MemTotal:/ {print $2}' /proc/meminfo) + 524288) / 1048576 ))
disk_free_gb="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
cat <<EOF

RAISE 2026 — machine check
  OS:        Ubuntu ${os_version} (${os_codename})  → ROS 2 ${DISTRO^}  ✓ supported
  CPU:       ${cpu_cores} cores
  RAM:       ${ram_gb} GB
  Free disk: ${disk_free_gb} GB on /
EOF
(( ram_gb < 8 ))        && echo "  ⚠ Less than 8 GB RAM — the simulator will be slow. Close other apps during labs."
(( disk_free_gb < 25 )) && echo "  ⚠ Less than 25 GB free disk — free up space (ROS + ML libs + LeRobot need ~20 GB)."

# ── 2. Remove ROS 2 Humble if present (unsupported) ─────────────────────────
if [[ -d /opt/ros/humble ]]; then
  cat <<'EOF'

⚠ ROS 2 Humble is installed at /opt/ros/humble.
  Humble is NOT supported — RAISE 2026 uses ROS 2 Jazzy only, and having both
  installed makes your shell source the wrong one. It should be removed.

  Remove it with:
      sudo apt purge -y 'ros-humble-*' && sudo apt autoremove -y
EOF
  removed_humble=0
  if [[ -t 0 ]]; then
    read -r -p "Remove ROS 2 Humble now? [Y/n]: " ans || true
    if [[ ! "${ans:-Y}" =~ ^[Nn] ]]; then
      sudo apt purge -y 'ros-humble-*' && sudo apt autoremove -y && removed_humble=1
    fi
  else
    echo "  (non-interactive shell — not removing automatically; run the command above.)"
  fi
  # Either way, drop any Humble sourcing from ~/.bashrc so shells use Jazzy.
  if grep -q '/opt/ros/humble/setup.bash' "${HOME}/.bashrc" 2>/dev/null; then
    sed -i '\|/opt/ros/humble/setup.bash|d' "${HOME}/.bashrc"
    echo "[prepare] Removed the Humble 'source' line from ~/.bashrc"
  fi
  (( removed_humble )) && echo "[prepare] ✓ ROS 2 Humble removed."
fi

# ── 3. ROS 2 Jazzy (idempotent: skipped if already installed) ───────────────
if [[ ! -d "/opt/ros/${DISTRO}" ]]; then
  echo "[prepare] Installing ROS 2 ${DISTRO^} from packages.ros.org (10–30 min)…"
  sudo apt update
  sudo apt install -y software-properties-common curl gnupg lsb-release locales
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  sudo add-apt-repository -y universe
  sudo install -d -m 0755 /usr/share/keyrings
  sudo curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    -o /usr/share/keyrings/ros-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu ${os_codename} main" \
    | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null
  sudo apt update
  sudo apt install -y "ros-${DISTRO}-desktop" ros-dev-tools
  echo "[prepare] ✓ ROS 2 ${DISTRO^} installed."
else
  echo "[prepare] ✓ ROS 2 ${DISTRO^} already installed — skipping."
fi

# ── 4. Gazebo Harmonic bridge ───────────────────────────────────────────────
echo "[prepare] Installing Gazebo Harmonic bridge (ros_gz)…"
sudo apt update
sudo apt install -y ros-jazzy-ros-gz ros-jazzy-ros-gz-bridge ros-jazzy-ros-gz-sim

# ── 5. Required apt deps for the labs ───────────────────────────────────────
echo "[prepare] Installing lab dependencies (apt)…"
sudo apt install -y \
  "ros-${DISTRO}-nav2-bringup" \
  "ros-${DISTRO}-xacro" \
  "ros-${DISTRO}-robot-state-publisher" \
  "ros-${DISTRO}-cv-bridge" \
  python3-opencv \
  python3-flask \
  python3-colcon-common-extensions \
  python3-rosdep \
  python3-venv \
  python3-pip \
  mesa-utils \
  git

# Optional robot-description packages (best-effort; rosdep fills any gaps Day 1).
echo "[prepare] Installing robot description packages (best-effort)…"
for p in "ros-${DISTRO}-clearpath-simulator" "ros-${DISTRO}-ur-description" \
         "ros-${DISTRO}-realsense2-description" "ros-${DISTRO}-robotiq-description"; do
  sudo apt install -y "$p" >/dev/null 2>&1 \
    && echo "[prepare] ✓ $p" \
    || echo "[prepare] ⚠ optional package unavailable, skipping: $p"
done

# ── 6. Pip deps for labs 08–09 (YOLO + VLM) ─────────────────────────────────
# numpy MUST stay <2 in the SAME resolve (cv_bridge is built against numpy 1.x);
# the CPU torch index skips ~2.5 GB of CUDA wheels.
echo "[prepare] Installing Python ML libraries (pip, ~1 GB download)…"
PIP_FLAGS=(--user)
if /usr/bin/python3 -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
  PIP_FLAGS+=(--break-system-packages)
fi
for attempt in 1 2 3; do
  if /usr/bin/python3 -m pip install "${PIP_FLAGS[@]}" \
      --retries 5 --timeout 120 \
      --extra-index-url https://download.pytorch.org/whl/cpu \
      "numpy<2" torch torchvision ultralytics openai; then
    break
  fi
  echo "[prepare] pip attempt ${attempt} failed (network?) — retrying in 10 s…"
  sleep 10
  [[ "$attempt" == "3" ]] && { echo "[prepare] ✗ pip failed 3 times. Check your connection and re-run." >&2; exit 1; }
done

# ── 7. Day-2 AI toolkit: the LeRobot venv (from PyPI — no GitHub, ~3 GB) ─────
# numpy 2 lives ONLY in this venv; the system python keeps numpy 1 for ROS.
# This is the big download you do NOT want on school Wi-Fi — do it at home.
echo "[prepare] Installing the Day-2 LeRobot AI toolkit (~3 GB — do this at home!)…"
VENV="${HOME}/raise_venvs/lerobot"
if "${VENV}/bin/python3" -c 'import lerobot' 2>/dev/null; then
  echo "[prepare] ✓ LeRobot venv already working"
else
  /usr/bin/python3 -m venv --system-site-packages "${VENV}"
  "${VENV}/bin/python3" -m pip install --upgrade pip >/dev/null 2>&1 || true
  lerobot_ok=0
  for attempt in 1 2 3; do
    if "${VENV}/bin/python3" -m pip install --timeout 120 --retries 10 "lerobot[smolvla]"; then
      lerobot_ok=1; echo "[prepare] ✓ LeRobot installed in ${VENV}"; break
    fi
    echo "[prepare] LeRobot pip attempt ${attempt} failed (network?) — retrying in 10 s…"; sleep 10
  done
  (( lerobot_ok )) || echo "[prepare] ⚠ LeRobot install failed — re-run this script to retry (Day-2 needs it)." >&2
fi

# Pre-download the SmolVLA VLM backbone into the HF cache (~1 GB). With it
# cached, the Day-2 tools run FULLY OFFLINE at the school — no HF Hub
# traffic, no rate limits on the shared wifi.
BACKBONE_DIR="${HOME}/.cache/huggingface/hub/models--HuggingFaceTB--SmolVLM2-500M-Video-Instruct"
if [[ -d "${BACKBONE_DIR}" ]]; then
  echo "[prepare] ✓ SmolVLA vision backbone already cached (Day-2 runs offline)"
elif "${VENV}/bin/python3" -c 'import lerobot' 2>/dev/null; then
  echo "[prepare] Pre-downloading the SmolVLA vision backbone (~1 GB, once)…"
  "${VENV}/bin/python3" - <<'PYEOF' || echo "[prepare] ⚠ backbone pre-download failed — first Day-2 model load will fetch it instead." >&2
from transformers import AutoProcessor, AutoModelForImageTextToText
m = 'HuggingFaceTB/SmolVLM2-500M-Video-Instruct'
AutoProcessor.from_pretrained(m)
AutoModelForImageTextToText.from_pretrained(m)
print('[prepare] ✓ backbone cached')
PYEOF
fi

# ── 8. rosdep (ready for the fast Day-1 workspace build) ────────────────────
[[ -f /etc/ros/rosdep/sources.list.d/20-default.list ]] || sudo rosdep init
rosdep update

# ── 9. ufw multicast (gz-transport discovery; GUI hangs without it) ─────────
if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "[prepare] Allowing UDP multicast through ufw (gz-transport)…"
  sudo ufw allow in proto udp to 224.0.0.0/4 >/dev/null || true
  sudo ufw allow in proto udp from 224.0.0.0/4 >/dev/null || true
fi

# ── 10. Disable Gazebo's first-run Quick Start dialog (hangs on Fuel calls) ─
GZ_USER_CFG="${HOME}/.gz/sim/8/gui.config"
mkdir -p "$(dirname "${GZ_USER_CFG}")"
if [[ -f "${GZ_USER_CFG}" ]]; then
  sed -i 's|<dialog name="quick_start" show_again="true"/>|<dialog name="quick_start" show_again="false"/>|' "${GZ_USER_CFG}"
else
  cat > "${GZ_USER_CFG}" <<'EOF'
<?xml version="1.0"?>
<!-- Quick start dialog -->
<dialog name="quick_start" show_again="false"/>
EOF
fi

# ── 11. Source ROS 2 Jazzy automatically in new terminals ───────────────────
if ! grep -q "/opt/ros/${DISTRO}/setup.bash" "${HOME}/.bashrc"; then
  echo "source /opt/ros/${DISTRO}/setup.bash" >> "${HOME}/.bashrc"
  echo "[prepare] Added 'source /opt/ros/${DISTRO}/setup.bash' to ~/.bashrc"
fi

cat <<EOF

✓ Preparation complete  (Ubuntu ${os_version} + ROS 2 ${DISTRO^}).

Everything heavy is now on your machine: ROS 2 Jazzy, Gazebo Harmonic, all lab
dependencies, and the Day-2 LeRobot AI toolkit.

EOF

# ── This kit may live INSIDE the course repo → build the course NOW ─────────
# (Student report 2026-07-13: docs left the workspace unbuilt; the build is
#  part of preparation, not a separate step.)
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
if [[ -x "${REPO_ROOT}/sim/install.sh" && -d "${REPO_ROOT}/raise_ros2_ws" ]]; then
  echo
  echo "[prepare] Course repo detected at ${REPO_ROOT} → installing + building the workspace…"
  if "${REPO_ROOT}/sim/install.sh"; then
    echo "[prepare] ✓ course built — try it:   raise-sim"
  else
    echo "[prepare] ⚠ course install reported a problem — re-run manually:"
    echo "            cd ${REPO_ROOT}/sim && ./install.sh"
  fi
else
  cat <<'EOM'
Next step — build the course code (from the course repo):
    cd <course-repo>/sim  &&  ./install.sh
It builds the workspace in ~2 minutes because the heavy parts are done.
EOM
fi

# ── 12. Final verification ──────────────────────────────────────────────────
if [[ -f "${SCRIPT_DIR}/check_setup.sh" ]]; then
  echo
  echo "[prepare] Running readiness check…"
  bash "${SCRIPT_DIR}/check_setup.sh" || true
fi
