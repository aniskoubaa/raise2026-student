#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — post-install smoke test (native).
#
# Fast, non-interactive, no-GUI sanity check run at the end of install_native.sh
# (and runnable any time on its own). Verifies the things that actually break:
#   • ROS 2 is installed and the workspace overlay is built
#   • all 7 raise2026_* packages + their executables are discoverable
#   • Gazebo Harmonic (gz-sim 8) is on PATH and ros_gz is present
#   • the fragile Python imports work — especially cv_bridge under numpy<2
#
# Exits 0 only if every REQUIRED check passes. WARN checks (heavy ML libs,
# OpenAI key) never fail the suite — labs 01–08 don't need them.
#
# NOTE: this does NOT launch Gazebo. `raise-sim` does the full GUI launch.
# Deliberately NOT -e: run every check, then summarize. Not -u either: ROS 2's
# setup.bash references unbound vars internally and trips nounset.
set -o pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_DIR="$(cd "${SIM_DIR}/../raise_ros2_ws" && pwd)"
ENV_FILE="${SIM_DIR}/.env"

# ── Resolve ROS distro (env → .env → /opt/ros) ─────────────────────────────
DISTRO="${RAISE_ROS_DISTRO:-${ROS_DISTRO:-}}"
if [[ -z "$DISTRO" && -f "$ENV_FILE" ]]; then
  DISTRO="$(grep -E '^RAISE_ROS_DISTRO=' "$ENV_FILE" | cut -d= -f2)"
fi
if [[ -z "$DISTRO" || ! -d "/opt/ros/${DISTRO}" ]]; then
  for d in /opt/ros/*; do [[ -d "$d" ]] && DISTRO="$(basename "$d")"; done
fi

# ── Source ROS + workspace overlay (quietly) ───────────────────────────────
if [[ -n "${DISTRO:-}" && -f "/opt/ros/${DISTRO}/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "/opt/ros/${DISTRO}/setup.bash"
fi
if [[ -f "${WS_DIR}/install/setup.bash" ]]; then
  # shellcheck disable=SC1090
  source "${WS_DIR}/install/setup.bash"
fi

# ── Reporting helpers ───────────────────────────────────────────────────────
PASS=0 FAIL=0 WARN=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m⚠\033[0m %s\n' "$1"; WARN=$((WARN+1)); }

# req "<description>" <command...>   → ✓/✗ (counts toward FAIL)
req()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# opt "<description>" <command...>   → ✓/⚠ (never fails the suite)
opt()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else warn "$d (optional)"; fi; }

echo
echo "RAISE 2026 — smoke test  (ROS 2 ${DISTRO:-unknown})"
echo

# ── 1. ROS 2 core ───────────────────────────────────────────────────────────
echo "ROS 2 core"
req "ros2 CLI on PATH"                 command -v ros2
req "/opt/ros/${DISTRO} present"       test -d "/opt/ros/${DISTRO}"
req "workspace built (install/setup.bash)" test -f "${WS_DIR}/install/setup.bash"

# ── 2. Workspace packages ───────────────────────────────────────────────────
echo "Workspace packages"
PKGS=(raise2026_bringup raise2026_worlds raise2026_description \
      raise2026_tools raise2026_teleop raise2026_demos raise2026_labs)
for p in "${PKGS[@]}"; do
  req "package: $p" ros2 pkg prefix "$p"
done

# tool nodes that labs 06-09 invoke with `ros2 run`
echo "Tool executables"
req "tools: gripper_server registered"   bash -c "ros2 pkg executables raise2026_tools 2>/dev/null | grep -q gripper_server"
req "tools: detector_server registered"  bash -c "ros2 pkg executables raise2026_tools 2>/dev/null | grep -q detector_server"
req "teleop: camera_view registered"     bash -c "ros2 pkg executables raise2026_teleop 2>/dev/null | grep -q camera_view"

# bringup launch file (what raise-sim runs)
req "bringup: sim.launch.py installed" \
  test -f "${WS_DIR}/install/raise2026_bringup/share/raise2026_bringup/launch/sim.launch.py"

# ── 3. Gazebo Harmonic + ros_gz ─────────────────────────────────────────────
echo "Gazebo Harmonic"
if command -v gz >/dev/null 2>&1; then
  GZ_VER="$(gz sim --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ "${GZ_VER%%.*}" == "8" ]]; then
    ok "gz sim ${GZ_VER} (Harmonic)"
  else
    warn "gz sim ${GZ_VER:-unknown} — expected major 8 (Harmonic). Labs assume gz-sim8."
  fi
else
  bad "gz (Gazebo) on PATH"
fi
req "ros_gz_sim package present"   ros2 pkg prefix ros_gz_sim
opt "ros_gz_bridge package present" ros2 pkg prefix ros_gz_bridge

# ── 4. Python imports (the fragile ones) ────────────────────────────────────
echo "Python imports"
req "import rclpy" /usr/bin/python3 -c "import rclpy"
# The historic breakage: cv_bridge (apt, numpy 1.x) vs numpy 2.x from pip.
req "import cv_bridge under numpy<2" /usr/bin/python3 -c \
  "import numpy,cv_bridge; assert int(numpy.__version__.split('.')[0])<2, 'numpy '+numpy.__version__+' >= 2 breaks cv_bridge'"
opt "import ultralytics (lab 08 YOLO)" /usr/bin/python3 -c "import ultralytics"
opt "import openai (lab 09 VLM)"       /usr/bin/python3 -c "import openai"
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  ok "OPENAI_API_KEY is set (lab 09 ready)"
else
  warn "OPENAI_API_KEY not set — lab 09 (VLM inspector) needs it; labs 01-08 don't"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "─────────────────────────────────────────────"
printf 'Smoke test: \033[32m%d passed\033[0m, \033[33m%d warnings\033[0m, \033[31m%d failed\033[0m\n' \
  "$PASS" "$WARN" "$FAIL"
echo "─────────────────────────────────────────────"

if (( FAIL > 0 )); then
  cat <<EOF
✗ Smoke test FAILED. The install is not fully working.
  Common fixes:
    • workspace not built → cd ${WS_DIR} && colcon build --symlink-install
    • cv_bridge/numpy     → /usr/bin/python3 -m pip install --user "numpy<2"
    • gz missing          → re-run ./bootstrap/install_native.sh
  Still stuck? Use the Docker path (Jazzy): ./bootstrap/install_docker.sh
EOF
  exit 1
fi

echo "✓ All required checks passed — you're ready. Launch with:  raise-sim"
if (( WARN > 0 )); then
  echo "  (Warnings above are optional — only needed for labs 08/09.)"
fi
exit 0
