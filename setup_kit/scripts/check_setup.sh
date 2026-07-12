#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 Summer School — readiness check (Ubuntu 24.04 + ROS 2 Jazzy only).
#
# Verifies your machine is ready for Day 1 and prints a pass/fail report.
# Send a screenshot of the FINAL SUMMARY to the instructors before the school.
#
# Usage:  ./check_setup.sh
set -uo pipefail

PASS=0; WARN=0; FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
warn() { echo "  ⚠ $*"; WARN=$((WARN+1)); }
bad()  { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

echo
echo "════════════════════════════════════════════════════════"
echo "  RAISE 2026 — machine readiness check"
echo "════════════════════════════════════════════════════════"

# ── 1. Operating system (Ubuntu 24.04 ONLY) ─────────────────────────────────
echo
echo "[1/6] Operating system"
if [[ "$(uname -s)" != "Linux" ]]; then
  bad "Not Linux — RAISE 2026 requires native Ubuntu 24.04. See the HTML guide."
  echo; echo "SUMMARY: ✗ NOT READY (wrong OS)"; exit 1
fi
os_id=unknown; os_version=unknown
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release; os_id="${ID:-unknown}"; os_version="${VERSION_ID:-unknown}"
fi
is_wsl=0; grep -qi microsoft /proc/version 2>/dev/null && is_wsl=1
if (( is_wsl )); then
  bad "Windows/WSL detected — only NATIVE Ubuntu 24.04 is supported. Dual-boot it."
elif [[ "$os_id" == "ubuntu" && "$os_version" == "24.04" ]]; then
  ok "Ubuntu 24.04 — the supported platform"
else
  bad "${os_id} ${os_version} — NOT supported. RAISE 2026 requires Ubuntu 24.04 only."
fi
# ROS 2 Humble must not be present (Jazzy is the only supported distro).
if [[ -d /opt/ros/humble ]]; then
  bad "ROS 2 Humble is installed — remove it: sudo apt purge -y 'ros-humble-*' && sudo apt autoremove -y"
fi

# ── 2. Display server & GPU (the simulator GUI) ─────────────────────────────
# The most common "the sim won't open / hangs on a blank window" reports trace
# back to a Wayland session and hybrid Intel+NVIDIA graphics. The `raise-sim`
# launcher already handles BOTH (forces xcb on Wayland, applies NVIDIA PRIME
# offload when a card is present) — this just reports what it will do.
echo
echo "[2/6] Display server & GPU (simulator GUI)"
if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  warn "No graphical session detected (headless/SSH). Run the sim from the laptop's own screen."
else
  session="${XDG_SESSION_TYPE:-unknown}"
  if [[ "$session" == "wayland" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    ok "Wayland session — the sim launcher auto-forces xcb (Gazebo GUI fix, handled)"
  else
    ok "X11 session (${session}) — native display for the Gazebo GUI"
  fi
fi
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L 2>/dev/null | grep -q GPU; then
  gpu_name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)"
  ok "NVIDIA GPU (${gpu_name:-detected}) — the sim launcher applies PRIME offload"
else
  echo "  – No NVIDIA GPU — Gazebo renders on Intel/AMD or software GL (fine; may be slower)."
fi

# ── 3. Hardware ─────────────────────────────────────────────────────────────
echo
echo "[3/6] Hardware"
cores="$(nproc)"
ram_gb=$(( ($(awk '/^MemTotal:/ {print $2}' /proc/meminfo) + 524288) / 1048576 ))
disk_gb="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"
(( cores >= 4 ))   && ok "CPU: ${cores} cores"       || warn "CPU: only ${cores} cores (4+ recommended)"
(( ram_gb >= 8 ))  && ok "RAM: ${ram_gb} GB"         || warn "RAM: ${ram_gb} GB (8+ GB recommended)"
(( disk_gb >= 10 )) && ok "Free disk: ${disk_gb} GB" || bad  "Free disk: ${disk_gb} GB (need 10+ GB free after install)"

# ── 4. Internet ─────────────────────────────────────────────────────────────
echo
echo "[4/6] Internet"
if curl -fsSL --max-time 10 https://packages.ros.org >/dev/null 2>&1 \
   || curl -fsSL --max-time 10 https://pypi.org >/dev/null 2>&1; then
  ok "Internet reachable"
else
  bad "Cannot reach packages.ros.org / pypi.org — check connection or proxy"
fi

# ── 5. ROS 2 Jazzy stack ────────────────────────────────────────────────────
echo
echo "[5/6] ROS 2 Jazzy stack"
STACK_OK=0
if [[ -d /opt/ros/jazzy ]]; then
  # ROS setup.bash references unbound variables — relax `set -u` around it,
  # or the whole check silently dies right here on machines WITH ROS.
  set +u
  # shellcheck disable=SC1091
  source /opt/ros/jazzy/setup.bash 2>/dev/null
  set -u
  command -v ros2 >/dev/null 2>&1 && ok "ROS 2 Jazzy (ros2 CLI works)" || bad "ROS 2 installed but 'ros2' CLI not working"
  gzv="$(gz sim --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  if [[ "${gzv%%.*}" == "8" ]]; then ok "Gazebo Harmonic (gz sim ${gzv})"; else bad "Gazebo Harmonic missing (got: ${gzv:-none}, want 8.x)"; fi
  command -v colcon >/dev/null 2>&1 && ok "colcon build tool" || bad "colcon missing"
  command -v rosdep >/dev/null 2>&1 && ok "rosdep" || bad "rosdep missing"
  /usr/bin/python3 -c 'import numpy,cv_bridge; assert int(numpy.__version__.split(".")[0])<2' 2>/dev/null \
    && ok "cv_bridge + numpy<2 (camera labs)" || bad "cv_bridge/numpy broken — re-run prepare_machine.sh"
  /usr/bin/python3 -c 'import flask'       2>/dev/null && ok "flask (phone teleop)"      || bad "flask missing"
  /usr/bin/python3 -c 'import cv2'         2>/dev/null && ok "OpenCV"                    || bad "OpenCV missing"
  /usr/bin/python3 -c 'import ultralytics' 2>/dev/null && ok "ultralytics/YOLO (lab 08)" || warn "ultralytics missing (lab 08) — re-run prepare_machine.sh"
  /usr/bin/python3 -c 'import openai'      2>/dev/null && ok "openai client (lab 09)"    || warn "openai client missing (lab 09) — re-run prepare_machine.sh"
  command -v ros2 >/dev/null 2>&1 && [[ "${gzv%%.*}" == "8" ]] && STACK_OK=1
else
  bad "ROS 2 Jazzy not installed — run ./prepare_machine.sh"
fi

# ── 6. Day-2 AI toolkit (LeRobot venv) ──────────────────────────────────────
echo
echo "[6/6] Day-2 AI toolkit (LeRobot venv)"
if "${HOME}/raise_venvs/lerobot/bin/python3" -c 'import lerobot' 2>/dev/null; then
  ok "LeRobot venv working (~/raise_venvs/lerobot) — Day-2 training/execution ready"
else
  warn "LeRobot venv missing — re-run ./prepare_machine.sh (it's a ~3 GB download; do it at home)"
fi
echo "  – The course code + reference model are provided on Day 1 (no GitHub needed)."

# ── Summary ─────────────────────────────────────────────────────────────────
echo
echo "════════════════════════════════════════════════════════"
echo "  FINAL SUMMARY   ✓ ${PASS} passed   ⚠ ${WARN} warnings   ✗ ${FAIL} failed"
if (( FAIL == 0 )) && (( STACK_OK )); then
  echo "  ✅ READY FOR RAISE 2026  (Ubuntu 24.04 + ROS 2 Jazzy)"
  echo "  → Send a screenshot of this summary to the instructors."
else
  echo "  ❌ NOT READY YET"
  echo "  → Fix the ✗ items above (usually: re-run ./prepare_machine.sh),"
  echo "    or bring this screenshot to the instructors for help."
fi
echo "════════════════════════════════════════════════════════"
echo
(( FAIL == 0 )) && (( STACK_OK ))
