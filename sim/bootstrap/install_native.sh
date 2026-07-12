#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — native install path.
#
# Supported natively:
#   • Ubuntu 24.04 (Noble) + ROS 2 Jazzy   — TESTED reference platform.
#   • Ubuntu 22.04 (Jammy) + ROS 2 Humble  — UNTESTED / best-effort.
#
# Both run Gazebo Harmonic, so the labs/worlds are identical. On Humble we pull
# Harmonic via ros-humble-ros-gzharmonic instead of its default Fortress pairing.
#
# 1) checks: supported Ubuntu, no active conda env
# 2) installs ROS 2 (Jazzy/Humble) if missing
# 3) apt-installs the upstream ROS/Gazebo packages we depend on
# 4) runs rosdep to resolve any remaining package.xml deps
# 5) colcon-builds the workspace, forcing the system Python (anaconda-safe)
set -euo pipefail

# ── 0. If anaconda is active, re-exec ourselves with it stripped. ──────────
# Anaconda's python lacks catkin_pkg and breaks `colcon build`. Don't fight it
# — start over in a clean env.
if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
  echo "[install_native] Anaconda env '${CONDA_DEFAULT_ENV}' active — re-exec'ing without it."
  exec env -u CONDA_PREFIX -u CONDA_DEFAULT_ENV -u CONDA_PROMPT_MODIFIER -u CONDA_SHLVL \
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -v anaconda | paste -sd:)" \
    bash "$0" "$@"
fi

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="$(cd "${SIM_DIR}/../raise_ros2_ws" && pwd)"
ENV_FILE="${SIM_DIR}/.env"

# ── 1. Resolve target ROS distro ───────────────────────────────────────────
# Prefer the value detect_hardware.sh wrote to .env; fall back to /etc/os-release
# so this script also works when run standalone.
ROS_DISTRO_TARGET=""
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  ROS_DISTRO_TARGET="${RAISE_ROS_DISTRO:-}"
fi

# shellcheck disable=SC1091
source /etc/os-release   # ID, VERSION_ID, VERSION_CODENAME
UB_VERSION="${VERSION_ID:-unknown}"
UB_CODENAME="${VERSION_CODENAME:-unknown}"

if [[ -z "$ROS_DISTRO_TARGET" || "$ROS_DISTRO_TARGET" == "unsupported" ]]; then
  case "$UB_VERSION" in
    24.04) ROS_DISTRO_TARGET=jazzy  ;;
    22.04) ROS_DISTRO_TARGET=humble ;;
  esac
fi

if [[ "${ID:-}" != "ubuntu" ]] || [[ -z "$ROS_DISTRO_TARGET" ]]; then
  cat >&2 <<EOF
✗ Native install supports Ubuntu 24.04 (Jazzy) or 22.04 (Humble) only.
  Detected: ${ID:-unknown} ${UB_VERSION}.
  Use the Docker path instead:  ./bootstrap/install_docker.sh
EOF
  exit 1
fi

DISTRO="$ROS_DISTRO_TARGET"

# Loud, honest banner about test status.
if [[ "$DISTRO" == "humble" ]]; then
  cat <<EOF

╔══════════════════════════════════════════════════════════════════════════╗
║  Ubuntu 22.04 + ROS 2 Humble — UNTESTED / best-effort path.               ║
║                                                                          ║
║  RAISE 2026 was developed and TESTED on Ubuntu 24.04 + ROS 2 Jazzy.      ║
║  Humble runs the same Gazebo Harmonic, so the labs SHOULD work, but no    ║
║  part of the 22.04 path has been verified. Distro-specific apt packages   ║
║  are installed best-effort and any that are missing will be reported.     ║
║                                                                          ║
║  If anything breaks, the Docker path (always Jazzy) is the reliable       ║
║  fallback:  ./bootstrap/install_docker.sh                                 ║
╚══════════════════════════════════════════════════════════════════════════╝

EOF
  # Brief, non-blocking pause so the warning is seen but unattended installs proceed.
  sleep 4
else
  echo "[install_native] Ubuntu ${UB_VERSION} → ROS 2 Jazzy (tested reference platform)."
fi

# ── apt helpers ─────────────────────────────────────────────────────────────
# Required packages must install or we abort. Optional packages are best-effort:
# distro-specific names (Clearpath / UR / Robotiq / RealSense descriptions) vary
# between Jazzy and Humble, so a miss is reported, not fatal — rosdep + the labs
# degrade gracefully.
MISSING_OPTIONAL=()
apt_install_required() { sudo apt install -y "$@"; }
apt_install_optional() {
  local p
  for p in "$@"; do
    if ! sudo apt install -y "$p" >/dev/null 2>&1; then
      echo "[install_native] ⚠ optional package unavailable on ${DISTRO}, skipping: $p"
      MISSING_OPTIONAL+=("$p")
    else
      echo "[install_native] ✓ $p"
    fi
  done
}

# ── 2. Install ROS 2 if missing ────────────────────────────────────────────
# Idempotent: skipped if /opt/ros/${DISTRO} already exists.
if [[ ! -d "/opt/ros/${DISTRO}" ]]; then
  echo "[install_native] ROS 2 ${DISTRO^} not found — installing from packages.ros.org…"
  {
    sudo apt update
    sudo apt install -y software-properties-common curl gnupg lsb-release locales

    # locale → UTF-8 (required by ROS 2)
    sudo locale-gen en_US en_US.UTF-8
    sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    # Ubuntu universe repo
    sudo add-apt-repository -y universe

    # ROS 2 GPG key (idempotent — overwrite if present)
    sudo install -d -m 0755 /usr/share/keyrings
    sudo curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg

    # ROS 2 apt source — codename must match the Ubuntu release (noble/jammy).
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu ${UB_CODENAME} main" \
      | sudo tee /etc/apt/sources.list.d/ros2.list >/dev/null

    sudo apt update
    sudo apt install -y "ros-${DISTRO}-desktop" ros-dev-tools
  } || {
    cat >&2 <<EOF

╔══════════════════════════════════════════════════════════════════════════╗
║  ROS 2 install failed.                                                   ║
╠══════════════════════════════════════════════════════════════════════════╣
║  This step fetches from packages.ros.org and raw.githubusercontent.com.  ║
║  Failure usually means one of:                                           ║
║                                                                          ║
║    1. No internet — connect to a network and retry.                      ║
║    2. Behind a proxy — configure apt + curl for it:                      ║
║          sudo nano /etc/apt/apt.conf.d/95proxies                         ║
║              Acquire::http::Proxy "http://your.proxy:port/";             ║
║              Acquire::https::Proxy "http://your.proxy:port/";            ║
║          export https_proxy=http://your.proxy:port/                      ║
║                                                                          ║
║    3. packages.ros.org / GitHub is temporarily down — retry later.       ║
║                                                                          ║
║  Fallback: use the Docker path instead — it bundles ROS 2 (Jazzy) inside ║
║  the image so only a working \`docker pull\` is required:                  ║
║                                                                          ║
║      ./bootstrap/install_docker.sh                                       ║
║                                                                          ║
║  Manual ROS 2 install reference:                                         ║
║    https://docs.ros.org/en/${DISTRO}/Installation/Ubuntu-Install-Debs.html
╚══════════════════════════════════════════════════════════════════════════╝

EOF
    exit 1
  }
  echo "[install_native] ROS 2 ${DISTRO^} installed at /opt/ros/${DISTRO}."
else
  echo "[install_native] ROS 2 ${DISTRO^} already installed at /opt/ros/${DISTRO} — skipping."
fi

# ── 3. Gazebo Harmonic + ros_gz ────────────────────────────────────────────
# Jazzy: `ros-jazzy-ros-gz` already targets Harmonic.
# Humble: the default `ros-humble-ros-gz` targets FORTRESS — we explicitly pull
#         the Harmonic build via `ros-humble-ros-gzharmonic` so the labs (which
#         assume gz-sim8 / ~/.gz/sim/8) keep working unchanged.
echo "[install_native] Installing Gazebo Harmonic bridge (ros_gz)…"
sudo apt update
if [[ "$DISTRO" == "jazzy" ]]; then
  apt_install_required \
    ros-jazzy-ros-gz \
    ros-jazzy-ros-gz-bridge \
    ros-jazzy-ros-gz-sim
else
  # Humble → Harmonic. This metapackage pulls ros_gz built against gz-harmonic.
  # If your apt can't find it, see: https://gazebosim.org/docs/harmonic/ros_installation
  apt_install_optional ros-humble-ros-gzharmonic
fi

# ── 3b. Apt deps (upstream packages our workspace depends on) ──────────────
# Required: core ROS/utility packages present on both distros.
echo "[install_native] Installing required apt deps (sudo)…"
apt_install_required \
  "ros-${DISTRO}-nav2-bringup" \
  "ros-${DISTRO}-xacro" \
  "ros-${DISTRO}-robot-state-publisher" \
  "ros-${DISTRO}-cv-bridge" \
  python3-opencv \
  python3-flask \
  python3-colcon-common-extensions \
  python3-rosdep \
  python3-venv \
  mesa-utils

# Optional: robot description / simulator packages whose availability differs by
# distro. Best-effort — misses are reported and rosdep tries to fill the gaps.
echo "[install_native] Installing optional description/simulator packages (best-effort)…"
apt_install_optional \
  "ros-${DISTRO}-clearpath-simulator" \
  "ros-${DISTRO}-ur-description" \
  "ros-${DISTRO}-realsense2-description" \
  "ros-${DISTRO}-robotiq-description"

# ── 3c. Pip deps (ML libs for labs 08-09: YOLO detector + VLM inspector) ──
# These have no ROS apt package, so we pip-install into the system Python's
# user site (anaconda was already stripped at section 0, so /usr/bin/python3
# is the interpreter ROS uses).
#
# CRITICAL ORDERING: ultralytics/torch/opencv-python pull numpy 2.x, but the
# apt-installed cv_bridge is compiled against numpy 1.x. If numpy 2.x wins,
# every `from cv_bridge import CvBridge` (labs 03, 08, 09) dies with
# "module compiled using NumPy 1.x cannot be run in NumPy 2.x". So we install
# the ML libs FIRST, then force numpy<2 LAST.
echo "[install_native] Installing pip deps for labs 08-09 (YOLO + VLM)…"
# Ubuntu 24.04's pip needs --break-system-packages (PEP 668); 22.04's pip
# predates that flag and would error on it, so only pass it where supported.
PIP_FLAGS=(--user)
if /usr/bin/python3 -m pip install --help 2>/dev/null | grep -q -- '--break-system-packages'; then
  PIP_FLAGS+=(--break-system-packages)
fi
# One resolve, with numpy pinned <2 IN THE SAME command (ultralytics +
# ultralytics-thop + opencv otherwise drag in numpy 2.x; cv_bridge is built
# against numpy 1.x). Pinning numpy in a *separate, later* command makes pip try
# to replace an already-installed numpy — which dies with
# "Cannot uninstall numpy 1.26.4, RECORD file not found" on a system/debian numpy.
# --extra-index-url picks the CPU torch build (torch==X+cpu sorts above the CUDA
# wheel), skipping ~2.5 GB of nvidia-* CUDA wheels — YOLO runs on CPU, VLM is remote.
# 3-attempt retry loop: large downloads on flaky networks can drop a TLS record
# mid-stream ("SSL: DECRYPTION_FAILED_OR_BAD_RECORD_MAC"); just re-run the install.
for attempt in 1 2 3; do
  if /usr/bin/python3 -m pip install "${PIP_FLAGS[@]}" \
      --retries 5 --timeout 120 \
      --extra-index-url https://download.pytorch.org/whl/cpu \
      "numpy<2" torch torchvision ultralytics openai; then
    break
  fi
  echo "[install_native] pip attempt ${attempt} failed (transient network?) — retrying in 10s…"
  sleep 10
  if [[ "${attempt}" == "3" ]]; then
    echo "[install_native] pip failed after 3 attempts. Check your connection and re-run." >&2
    exit 1
  fi
done

# ── 4. rosdep ──────────────────────────────────────────────────────────────
if [[ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]]; then
  sudo rosdep init
fi
rosdep update
cd "${WS_DIR}"
rosdep install --from-paths src --ignore-src -r -y || true

# ── 5. Build (anaconda-proof) ──────────────────────────────────────────────
echo "[install_native] Building workspace…"
# ROS's setup.bash references unbound vars (e.g. AMENT_TRACE_SETUP_FILES). Under
# this script's `set -u` that aborts the build with "unbound variable" on a
# fresh, non-interactive shell (interactive shells often have it pre-set, which
# is why this went unnoticed). Relax `set -u` only while sourcing ROS.
set +u
# shellcheck disable=SC1090
source "/opt/ros/${DISTRO}/setup.bash"
set -u
colcon build \
  --symlink-install \
  --cmake-args -DPython3_EXECUTABLE=/usr/bin/python3

# ── 6. ufw multicast (gz-transport service discovery) ──────────────────────
# Without this, `gz sim server` and `gz sim gui` can't see each other → GUI
# spins forever on "Requesting list of world names". Idempotent: re-adding
# an existing rule is a no-op.
if command -v ufw >/dev/null 2>&1 && sudo ufw status 2>/dev/null | grep -q "Status: active"; then
  echo "[install_native] Allowing UDP multicast through ufw (gz-transport)…"
  sudo ufw allow in proto udp to 224.0.0.0/4 >/dev/null || true
  sudo ufw allow in proto udp from 224.0.0.0/4 >/dev/null || true
fi

# ── 7. Disable Gazebo's first-run Quick Start dialog ──────────────────────
# Otherwise it hangs on Fuel network calls and looks like Gazebo crashed.
# gz-sim8 (Harmonic) on both Jazzy and Humble → ~/.gz/sim/8/gui.config.
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
echo "[install_native] Quick Start dialog disabled in ${GZ_USER_CFG}"

# ── 8. Install `raise-sim` + `raise-stop` to /usr/local/bin ───────────────
# Standalone scripts: applies snap/anaconda env strips + NVIDIA PRIME offload
# (when present), then `ros2 launch raise2026_bringup sim.launch.py`.
for cmd in raise-sim raise-stop; do
  src="${SIM_DIR}/${cmd}"
  if [[ -f "${src}" ]]; then
    sudo ln -sf "${src}" "/usr/local/bin/${cmd}"
    echo "[install_native] Installed: /usr/local/bin/${cmd} → ${src}"
  fi
done

# ── 9. Done ────────────────────────────────────────────────────────────────
cat <<EOF

✓ Native install complete  (Ubuntu ${UB_VERSION} + ROS 2 ${DISTRO^}).

To launch (from any new shell):
    raise-sim                                        # full sim, default world
    raise-sim world:=greenhouse_2026_lite.sdf        # lite world (CPU-only)
    raise-sim y:=-1.0                                # spawn Husky in another aisle

What the installer just did:
  ✓ Installed ROS 2 ${DISTRO^} + ros-dev-tools (if it wasn't already)
  ✓ Installed Gazebo Harmonic bridge (ros_gz)
  ✓ apt-installed core ROS 2 / Gazebo / utility packages
  ✓ pip-installed ultralytics + openai, then pinned numpy<2 (labs 08-09)
  ✓ rosdep'd transitive deps from raise_ros2_ws
  ✓ colcon-built the workspace (system python pinned)
  ✓ ufw: opened UDP multicast 224.0.0.0/4 (gz-transport discovery)
  ✓ Gazebo: disabled first-run Quick Start dialog
  ✓ Installed raise-sim + raise-stop to /usr/local/bin
EOF

if (( ${#MISSING_OPTIONAL[@]} > 0 )); then
  cat <<EOF

⚠ These optional packages were not available on ${DISTRO} and were skipped:
$(printf '    - %s\n' "${MISSING_OPTIONAL[@]}")
  rosdep may have covered them from package.xml. If a robot model fails to
  load, install the missing piece by hand or use the Docker path (Jazzy).
EOF
fi

if [[ "$DISTRO" == "humble" ]]; then
  cat <<EOF

⚠ Reminder: Ubuntu 22.04 + Humble is UNTESTED. RAISE 2026 is verified on
  Ubuntu 24.04 + Jazzy. Please report any issues you hit on 22.04.
EOF
fi

cat <<EOF

⚠ Lab 09 (VLM inspector) needs an OpenAI key. Add to ~/.bashrc:
    export OPENAI_API_KEY=sk-...
  then: source ~/.bashrc
  (Labs 01-08 work without it; 09 will print a clear error if it's missing.)

Re-run any time you change apt deps or the workspace src/.
It's idempotent — already-done steps are skipped.
EOF

# ── 10. Smoke test ──────────────────────────────────────────────────────────
# Verify the install actually works and report. Non-fatal: the install itself
# already succeeded; this just tells the user (and us) what's wired up.
echo
echo "[install_native] Running smoke test to verify the install…"
if "${SIM_DIR}/bootstrap/smoke_test.sh"; then
  echo "[install_native] ✓ Smoke test passed."
else
  echo "[install_native] ⚠ Smoke test reported failures (see above)."
  echo "[install_native]   Install finished but something isn't fully working;"
  echo "[install_native]   the Docker path (Jazzy) is the reliable fallback."
fi
