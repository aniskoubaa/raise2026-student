#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — ONE command from a fresh clone to a driving robot.
#
#   git clone https://github.com/aniskoubaa/raise2026-student
#   cd raise2026-student
#   ./start.sh
#
# First run (fresh Ubuntu 24.04): installs everything (ROS 2 Jazzy, Gazebo
# Harmonic, all dependencies, the Day-2 AI toolkit), builds the workspace,
# then LAUNCHES the simulator with keyboard teleop + the phone web interface.
# You'll be asked for your sudo password once. ~30-60 min on good internet.
#
# Every later run: skips straight to launch (~15 s).
#
# What you get when it's up:
#   • Gazebo window: the Sfax greenhouse with the robot
#   • THIS terminal: keyboard driving (w/a/s/d, SPACE = stop)
#   • Your phone (same WiFi): http://<laptop-ip>:5000 — tap-drive + camera view
#
# Stop everything: Ctrl-C here (or `raise-stop` from any terminal).
set -eo pipefail   # NOT -u: ROS/colcon setup scripts reference unbound vars

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WS="${REPO}/raise_ros2_ws"

say() { echo; echo "════ [start] $* ════"; }

# ── anaconda/conda hygiene (breaks ROS tooling) ─────────────────────────────
if [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; then
  exec env -u CONDA_PREFIX -u CONDA_DEFAULT_ENV -u CONDA_PROMPT_MODIFIER -u CONDA_SHLVL \
    PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -i conda | paste -sd:)" \
    bash "$0" "$@"
fi
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -vE '/snap/|anaconda' | paste -sd:)"

# ── [1/4] Install + build (skipped once done) ───────────────────────────────
need_install=0
[[ -f "${WS}/install/setup.bash" ]] || need_install=1
[[ -d /opt/ros/jazzy ]] || need_install=1
command -v gz >/dev/null 2>&1 || need_install=1
if (( need_install )); then
  say "1/4 First-time install (ROS 2 + Gazebo + deps + build; sudo will ask once)"
  "${REPO}/setup_kit/scripts/prepare_machine.sh"   # installs everything, then
                                                    # auto-runs sim/install.sh
  [[ -f "${WS}/install/setup.bash" ]] || {
    echo "✗ the workspace did not build — check the messages above, then re-run ./start.sh" >&2
    exit 1
  }
else
  say "1/4 Install: already done ✓ (skipping)"
fi

# ── [2/4] Lab aliases (managed block, once) ─────────────────────────────────
if ! grep -qF "RAISE2026 aliases" "${HOME}/.bashrc" 2>/dev/null; then
  printf '\n# >>> RAISE2026 aliases >>>\nsource "%s/sim/raise_aliases.sh"\n# <<< RAISE2026 aliases <<<\n' "$REPO" >> "${HOME}/.bashrc"
  say "2/4 Lab aliases installed into ~/.bashrc (new terminals get 01_d1 … vla_d4)"
else
  say "2/4 Lab aliases: already installed ✓"
fi

# ── ROS environment for the teleop processes below ──────────────────────────
set +u
source /opt/ros/jazzy/setup.bash
source "${WS}/install/setup.bash"
set -u 2>/dev/null || true

CLEANUP() {
  echo; echo "[start] shutting down…"
  # kill by pattern: the ros2-run wrapper orphans the actual python node
  pkill -9 -f 'raise2026_teleop.teleop_phone' 2>/dev/null || true
  pkill -9 -f 'raise2026_teleop.teleop_keyboard' 2>/dev/null || true
  "${REPO}/sim/raise-stop" >/dev/null 2>&1 || true
  echo "[start] done. Run ./start.sh anytime to launch again."
}
trap CLEANUP EXIT INT TERM

# ── [3/4] Launch the simulator (repo-local launcher: Wayland/GPU fixes inside) ─
say "3/4 Launching the greenhouse simulator (a Gazebo window will open)…"
"${REPO}/sim/raise-stop" >/dev/null 2>&1 || true      # clean slate (stale sims)
sleep 1
"${REPO}/sim/raise-sim" > /tmp/raise-sim.log 2>&1 &
echo -n "        waiting for the robot"
SIM_UP=0
for _ in $(seq 1 60); do
  if timeout 4 ros2 topic echo /joint_states --once >/dev/null 2>&1; then
    SIM_UP=1; echo " — UP ✓"; break
  fi
  echo -n "."
  sleep 2
done
if (( ! SIM_UP )); then
  echo; echo "✗ the simulator did not come up — see /tmp/raise-sim.log" >&2
  exit 1
fi

# ── [4/4] Phone web interface + keyboard teleop ─────────────────────────────
say "4/4 Starting the phone web interface…"
pkill -9 -f raise2026_teleop.teleop_phone 2>/dev/null || true
ros2 run raise2026_teleop teleop_phone > /tmp/teleop_phone.log 2>&1 &
PHONE_PID=$!
for _ in $(seq 1 15); do
  curl -fsS -o /dev/null http://127.0.0.1:5000/ 2>/dev/null && break
  sleep 1
done
LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"

cat <<EOF

════════════════════════════════════════════════════════════
 ✅ RAISE 2026 is UP

   🖥  Gazebo:  the greenhouse window (robot, tomato rows, animals)
   📱 Phone:   http://${LAN_IP:-<laptop-ip>}:5000   (same WiFi — tap-drive + camera)
   ⌨  Keyboard driving starts NOW in this terminal:
        w/s = forward/back   a/d = turn   SPACE = stop   Ctrl-C = quit all
════════════════════════════════════════════════════════════
EOF

if [[ -t 0 ]]; then
  # foreground keyboard teleop — Ctrl-C ends it and the trap shuts everything down
  ros2 run raise2026_teleop teleop_keyboard
else
  echo "(no interactive terminal — sim + phone stay up; Ctrl-C or 'raise-stop' to end)"
  while ros2 topic list >/dev/null 2>&1; do sleep 5; done
fi
