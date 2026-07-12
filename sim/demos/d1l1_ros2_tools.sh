#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# Day 1 / Lecture 1 — ROS 2 services as functions (LLM tool-use orchestrator).
#
# One command for the lecture: bring up the sim (if not already running), start
# the five tool servers the agent can call, then run 10_orchestrate.py — you type
# a goal in plain English and GPT-4o chains navigate/move_arm/gripper/detect/
# inspect to accomplish it. Mirrors the `10_d1` shell alias, plus sim bring-up.
#
# Ctrl-C (or the orchestrator exiting) tears down the servers and, if this script
# launched the sim, the sim too.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="$(cd "${SIM_DIR}/../raise_ros2_ws" && pwd)"

# Sourcing the workspace overlay also pulls in the ROS 2 underlay it was built
# against (/opt/ros/<distro>), so `ros2` is on PATH after this.
# shellcheck disable=SC1091
source "${WS}/install/setup.bash"

# ── 1. Make sure the simulation is up ───────────────────────────────────────
# Reuse a running sim if the instructor already launched `raise-sim`; otherwise
# start one in the background and remember to stop it on exit.
LAUNCHED_SIM=0
if ros2 topic list 2>/dev/null | grep -qE '^/(scan|odom)$'; then
  echo "[d1l1] Simulation already running — reusing it."
else
  echo "[d1l1] Launching simulation (raise-sim)…"
  "${SIM_DIR}/raise-sim" >/tmp/raise_sim_d1l1.log 2>&1 &
  LAUNCHED_SIM=1
  echo "[d1l1] Waiting for the sim to come up (sensors on /scan, /odom)…"
  for _ in $(seq 1 90); do
    if ros2 topic list 2>/dev/null | grep -qE '^/(scan|odom)$'; then break; fi
    sleep 1
  done
  ros2 topic list 2>/dev/null | grep -qE '^/(scan|odom)$' \
    || echo "[d1l1] ⚠ sim topics not seen yet — continuing anyway (see /tmp/raise_sim_d1l1.log)."
fi

# ── 2. Load API keys (OPENAI for the inspector tool) ────────────────────────
# Lab 1.1 still runs without a key (navigate/move/gripper/detect work); only the
# inspect_plant tool needs it, so we warn rather than abort.
RAISE_ENV="${WS}/src/.env"
if [[ -f "${RAISE_ENV}" ]]; then set -a; # shellcheck disable=SC1090
  source "${RAISE_ENV}"; set +a; fi
[[ -n "${OPENAI_API_KEY:-}" ]] || \
  echo "[d1l1] ⚠ OPENAI_API_KEY not set — the inspect_plant tool will error; the rest works."

# ── 3. Start the five tool servers the agent can call ───────────────────────
SERVERS=(gripper_server move_to_pose_server navigation_server detector_server inspector_server)
PIDS=()
echo "[d1l1] Starting ${#SERVERS[@]} tool servers…"
for srv in "${SERVERS[@]}"; do
  ros2 run raise2026_tools "${srv}" >"/tmp/${srv}.log" 2>&1 &
  PIDS+=($!)
done

# ── 4. Tear everything down on exit ─────────────────────────────────────────
cleanup() {
  echo
  echo "[d1l1] Stopping tool servers…"
  kill "${PIDS[@]}" 2>/dev/null || true
  if [[ "${LAUNCHED_SIM}" == "1" ]]; then
    echo "[d1l1] Stopping simulation…"
    "${SIM_DIR}/raise-stop" >/dev/null 2>&1 || true
  fi
}
trap cleanup INT TERM EXIT

# detector loads YOLOv8; inspector builds the OpenAI client — give them a moment.
sleep 4

# ── 5. Run the orchestrator (interactive) ───────────────────────────────────
echo "[d1l1] Launching the orchestrator. Type a goal in plain English (Ctrl-C to quit)."
ros2 run raise2026_labs 10_orchestrate.py
