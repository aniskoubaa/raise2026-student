#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# Day 1 / Lecture 2 — agentic inspector (autonomous mission → field report).
#
# One command for the lecture: bring up the sim (if not already running), start
# the five tool servers, then run agent.py — you hand it a MISSION and it runs
# autonomously (navigate / inspect / recover), filing a structured field report
# to /tmp/raise_field_report_*.json. Mirrors the `agent_d2` shell alias, plus
# sim bring-up.
#
# Unlike Lab 1.1 this REQUIRES OPENAI_API_KEY (the whole lab is the LLM loop).
# Ctrl-C (or the agent finishing) tears down the servers and, if this script
# launched the sim, the sim too.
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS="$(cd "${SIM_DIR}/../raise_ros2_ws" && pwd)"

# Sourcing the workspace overlay also pulls in the ROS 2 underlay it was built
# against (/opt/ros/<distro>), so `ros2` is on PATH after this.
# shellcheck disable=SC1091
source "${WS}/install/setup.bash"

# ── 1. Load API keys and require OPENAI_API_KEY ─────────────────────────────
RAISE_ENV="${WS}/src/.env"
if [[ -f "${RAISE_ENV}" ]]; then set -a; # shellcheck disable=SC1090
  source "${RAISE_ENV}"; set +a; fi
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "✗ OPENAI_API_KEY not found in the environment or ${RAISE_ENV}." >&2
  echo "  Add it to ${RAISE_ENV} (export OPENAI_API_KEY=sk-...), then re-run." >&2
  exit 1
fi

# ── 2. Make sure the simulation is up ───────────────────────────────────────
LAUNCHED_SIM=0
if ros2 topic list 2>/dev/null | grep -qE '^/(scan|odom)$'; then
  echo "[d1l2] Simulation already running — reusing it."
else
  echo "[d1l2] Launching simulation (raise-sim)…"
  "${SIM_DIR}/raise-sim" >/tmp/raise_sim_d1l2.log 2>&1 &
  LAUNCHED_SIM=1
  echo "[d1l2] Waiting for the sim to come up (sensors on /scan, /odom)…"
  for _ in $(seq 1 90); do
    if ros2 topic list 2>/dev/null | grep -qE '^/(scan|odom)$'; then break; fi
    sleep 1
  done
  ros2 topic list 2>/dev/null | grep -qE '^/(scan|odom)$' \
    || echo "[d1l2] ⚠ sim topics not seen yet — continuing anyway (see /tmp/raise_sim_d1l2.log)."
fi

# ── 3. Start the five tool servers the agent can call ───────────────────────
SERVERS=(gripper_server move_to_pose_server navigation_server detector_server inspector_server)
PIDS=()
echo "[d1l2] Starting ${#SERVERS[@]} tool servers…"
for srv in "${SERVERS[@]}"; do
  ros2 run raise2026_tools "${srv}" >"/tmp/${srv}.log" 2>&1 &
  PIDS+=($!)
done

# ── 4. Tear everything down on exit ─────────────────────────────────────────
cleanup() {
  echo
  echo "[d1l2] Stopping tool servers…"
  kill "${PIDS[@]}" 2>/dev/null || true
  if [[ "${LAUNCHED_SIM}" == "1" ]]; then
    echo "[d1l2] Stopping simulation…"
    "${SIM_DIR}/raise-stop" >/dev/null 2>&1 || true
  fi
}
trap cleanup INT TERM EXIT

# detector loads YOLOv8; inspector builds the OpenAI client — give them a moment.
sleep 4

# ── 5. Run the autonomous agent (interactive: pick a mission) ───────────────
echo "[d1l2] Launching the agentic inspector. Pick a mission (Ctrl-C to quit)."
echo "[d1l2] Field report will be saved to /tmp/raise_field_report_*.json"
ros2 run raise2026_labs agent.py
