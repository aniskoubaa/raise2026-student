# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — the lab alias block (single source of truth, lives IN the repo).
#
# Source this from ~/.bashrc (get_course.sh adds the line for you):
#     source <repo>/RAISE2026/sim/raise_aliases.sh
#
# Convention: XX_dN  →  run lab script XX of GLOBAL lab N (1..6):
#     d1 = D1L1 (ros2_tools_as_functions)    d4 = D2L2 (vla_executor)
#     d2 = D1L2 (agentic_inspector)          d5 = D3L1 (full_stack)
#     d3 = D2L1 (teleoperation_and_data)     d6 = D3L2 (hackathon)
#
# Day-2 scripts that import LeRobot run under the lerobot venv python
# (numpy 2) — see raise2026_labs/day2/HOW_TO_TRAIN_AND_USE.md §1.

# ── paths derived from THIS file's location (portable across machines) ──────
# readlink -f resolves symlinks too, so sourcing via a symlink also works.
_RAISE_SIM_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_RAISE_ROOT="$(cd "${_RAISE_SIM_DIR}/.." && pwd)"                 # …/RAISE2026
export RAISE_WS="${_RAISE_ROOT}/raise_ros2_ws"
export RAISE_D2="${RAISE_WS}/src/raise2026_labs/day2"
export RAISE_LEROBOT_PY="${HOME}/raise_venvs/lerobot/bin/python3"
RAISE_ENV="${RAISE_WS}/src/.env"                                   # gitignored API keys

# Overlay the workspace if it has been built.
[ -f "${RAISE_WS}/install/setup.bash" ] && source "${RAISE_WS}/install/setup.bash"

# Source the .env (export every KEY=value) so the shell + child nodes get keys.
_raise_load_env() { [ -f "$RAISE_ENV" ] && { set -a; . "$RAISE_ENV"; set +a; }; }

# ── D1L1 — ROS 2 tools as functions ─────────────────────────────────────────
alias 01_d1="ros2 run raise2026_labs 01_drive_forward.py"
alias 02_d1="ros2 run raise2026_labs 02_read_lidar.py"
alias 03_d1="ros2 run raise2026_labs 03_read_camera.py"
alias 04_d1="ros2 run raise2026_labs 04_aim_ptz.py"

# Bash functions can't start with a digit (aliases can), so each server-bundled
# lab gets a normal-named function + a digit alias to it.
_raise_05_d1() {
  ros2 run raise2026_tools gripper_server > /tmp/gripper_server.log 2>&1 &
  local _srv_pid=$!
  trap "kill $_srv_pid 2>/dev/null" INT
  sleep 0.8
  ros2 run raise2026_labs 05_call_gripper.py
  kill $_srv_pid 2>/dev/null
  trap - INT
}
alias 05_d1=_raise_05_d1
alias gripper_server="ros2 run raise2026_tools gripper_server"

_raise_06_d1() {
  ros2 run raise2026_tools move_to_pose_server > /tmp/move_to_pose_server.log 2>&1 &
  local _srv_pid=$!
  trap "kill $_srv_pid 2>/dev/null" INT
  sleep 0.8
  ros2 run raise2026_labs 06_call_robotic_arm.py
  kill $_srv_pid 2>/dev/null
  trap - INT
}
alias 06_d1=_raise_06_d1
alias move_to_pose_server="ros2 run raise2026_tools move_to_pose_server"

_raise_07_d1() {
  ros2 run raise2026_tools navigation_server > /tmp/navigation_server.log 2>&1 &
  local _srv_pid=$!
  trap "kill $_srv_pid 2>/dev/null" INT
  sleep 0.8
  ros2 run raise2026_labs 07_call_navigation.py
  kill $_srv_pid 2>/dev/null
  trap - INT
}
alias 07_d1=_raise_07_d1
alias navigation_server="ros2 run raise2026_tools navigation_server"

_raise_08_d1() {
  ros2 run raise2026_tools detector_server > /tmp/detector_server.log 2>&1 &
  local _srv_pid=$!
  trap "kill $_srv_pid 2>/dev/null" INT
  sleep 2.0   # YOLO model load + first-time weight download
  ros2 run raise2026_labs 08_call_detector.py
  kill $_srv_pid 2>/dev/null
  trap - INT
}
alias 08_d1=_raise_08_d1
alias detector_server="ros2 run raise2026_tools detector_server"

_raise_09_d1() {
  _raise_load_env
  if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "✗ OPENAI_API_KEY not found in env or $RAISE_ENV"
    return 1
  fi
  ros2 run raise2026_tools inspector_server > /tmp/inspector_server.log 2>&1 &
  local _srv_pid=$!
  trap "kill $_srv_pid 2>/dev/null" INT
  sleep 1.5
  ros2 run raise2026_labs 09_call_inspector.py
  kill $_srv_pid 2>/dev/null
  trap - INT
}
alias 09_d1=_raise_09_d1
alias inspector_server="ros2 run raise2026_tools inspector_server"

_raise_10_d1() {
  _raise_load_env
  local servers=(gripper_server move_to_pose_server navigation_server detector_server inspector_server)
  local pids=()
  echo "Starting 5 tool servers …"
  for srv in "${servers[@]}"; do
    ros2 run raise2026_tools "$srv" > "/tmp/${srv}.log" 2>&1 &
    pids+=($!)
  done
  trap 'kill ${pids[*]} 2>/dev/null' INT
  sleep 4    # detector loads YOLO; inspector loads .env + OpenAI client
  ros2 run raise2026_labs 10_orchestrate.py
  echo "Stopping tool servers …"
  kill "${pids[@]}" 2>/dev/null
  trap - INT
}
alias 10_d1=_raise_10_d1

# ── D1L2 — agentic inspector ────────────────────────────────────────────────
_raise_agent_d2() {
  _raise_load_env
  if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "✗ OPENAI_API_KEY not found in env or $RAISE_ENV"
    return 1
  fi
  local servers=(gripper_server move_to_pose_server navigation_server detector_server inspector_server)
  local pids=()
  echo "Starting 5 tool servers …"
  for srv in "${servers[@]}"; do
    ros2 run raise2026_tools "$srv" > "/tmp/${srv}.log" 2>&1 &
    pids+=($!)
  done
  trap 'kill ${pids[*]} 2>/dev/null' INT
  sleep 4
  ros2 run raise2026_labs agent.py
  echo "Stopping tool servers …"
  kill "${pids[@]}" 2>/dev/null
  trap - INT
}
alias agent_d2=_raise_agent_d2

# ── Day-2 sim launch: parked at the plant row ────────────────────────────────
# The Day-2 grasp poses AND the trained reference model expect the robot parked
# facing the plant at (-2, 3) — see task_packs/common/sim_poses.py (PARK).
alias sim_d2='raise-sim x:=-2.0 y:=2.15 yaw:=1.5708'

# ── D2L1 — teleoperation & data collection ──────────────────────────────────
# LeRobot-dependent scripts (03/05/06, finetune, vla) run under the venv python.
alias 01_d3="ros2 run raise2026_labs 01_teleop.py"
alias 02_d3="ros2 run raise2026_labs 02_read_streams.py"
alias 03_d3='"$RAISE_LEROBOT_PY" "$RAISE_D2/day2_01_teleoperation_and_data/starter/03_record.py"'
alias 04_d3="ros2 run raise2026_labs 04_upload.py"
alias 05_d3='"$RAISE_LEROBOT_PY" "$RAISE_D2/day2_01_teleoperation_and_data/starter/05_auto_demonstrate.py"'
alias 06_d3='"$RAISE_LEROBOT_PY" "$RAISE_D2/day2_01_teleoperation_and_data/starter/06_replay_episode.py"'
alias grasp_d3="ros2 run raise2026_tools grasp_server"

# ── D2L2 — fine-tune (background bridge) + VLA executor ─────────────────────
alias finetune_d4='"$RAISE_LEROBOT_PY" "$RAISE_D2/day2_02_vla_executor/starter/finetune_smolvla.py"'
# One-command install of the Day-2 reference brain (fine-tuned SmolVLA, 687 MB,
# public release — no login). Day-2 tools auto-detect it once extracted.
get_brain_d4() {
  local url="https://github.com/aniskoubaa/raise2026-student/releases/download/day2-smolvla-ref-v3/smolvla_C_ref_v3.tar.gz"
  local dst="$HOME/raise_checkpoints/smolvla_C_ref/checkpoints/006000"
  local tmp="/tmp/smolvla_C_ref_v3.tar.gz"
  if [ -d "$dst/pretrained_model" ]; then
    echo "✓ reference brain already installed at $dst"; return 0
  fi
  echo "Downloading the reference brain (687 MB) — interruptions RESUME, just re-run if needed…"
  # -C - resumes a partial file; --http1.1 avoids HTTP/2 stream resets seen on
  # flaky networks; tar -tzf is the completeness check (a resumed 416 also
  # lands here with the file already whole).
  local attempt
  for attempt in 1 2 3 4 5; do
    curl -L --http1.1 -C - --retry 5 --retry-all-errors -o "$tmp" "$url" && break
    tar -tzf "$tmp" >/dev/null 2>&1 && break
    echo "…download interrupted (attempt $attempt/5) — resuming in 5 s"; sleep 5
  done
  if ! tar -tzf "$tmp" >/dev/null 2>&1; then
    echo "✗ download incomplete — re-run get_brain_d4 (it resumes where it stopped)," 
    echo "  or copy the file from the instructors' USB and run:"
    echo "  mkdir -p $dst && tar -xzf <the-file> -C $dst"
    return 1
  fi
  mkdir -p "$dst" &&
  tar -xzf "$tmp" -C "$dst" &&
  rm -f "$tmp" &&
  echo "✓ reference brain installed — run:  vla_d4 --task C --spawn"
}

alias vla_one_d4='"$RAISE_LEROBOT_PY" "$RAISE_D2/day2_02_vla_executor/starter/vla_one_step.py"'
alias vla_d4='"$RAISE_LEROBOT_PY" "$RAISE_D2/day2_02_vla_executor/starter/vla_executor.py"'
