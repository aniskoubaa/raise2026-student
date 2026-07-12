#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# Day 2 / Lab 2.2 — VLA rollout: the TRAINED model picks the red tomato from a
# typed instruction. One command; spawns the scene itself (--spawn).
#
# Needs: the sim up (raise-sim) + grasp_server running (alias: grasp_d3).
# The executor runs under the LEROBOT VENV python (numpy 2) and auto-uses the
# local reference checkpoint when VLA_LOCAL_CKPT is unset.
#
# Usage:  d2l2_vla_rollout.sh [TASK] ["INSTRUCTION"]
#         d2l2_vla_rollout.sh C "pick the red tomato"
set -eo pipefail   # NOT -u: colcon setup.bash references unbound vars (COLCON_TRACE)

TASK="${1:-C}"
INSTRUCTION="${2:-}"

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../raise_ros2_ws" && pwd)"
# shellcheck disable=SC1091
source "${WS}/install/setup.bash"

VENV_PY="${HOME}/raise_venvs/lerobot/bin/python3"
EXEC="${WS}/src/raise2026_labs/day2/day2_02_vla_executor/starter/vla_executor.py"

if [ ! -x "${VENV_PY}" ]; then
  echo "✗ lerobot venv missing. Install it first (HOW_TO_TRAIN_AND_USE.md §1):"
  echo "    /usr/bin/python3 -m venv --system-site-packages ~/raise_venvs/lerobot"
  echo "    ~/raise_venvs/lerobot/bin/python3 -m pip install \"lerobot[smolvla]\""
  exit 1
fi
if ! ros2 topic list 2>/dev/null | grep -q '/joint_states'; then
  echo "✗ sim not detected (/joint_states missing). Start it first:  raise-sim"
  exit 1
fi
if ! ros2 topic list 2>/dev/null | grep -q '/grasp/state'; then
  echo "✗ grasp_server not running. In another terminal:  ros2 run raise2026_tools grasp_server"
  exit 1
fi

echo "── Day 2 / Lab 2.2 — VLA rollout (task ${TASK}) ──"
echo "   ckpt: ${VLA_LOCAL_CKPT:-<auto: local reference checkpoint>}"

if [ -n "${INSTRUCTION}" ]; then
  exec "${VENV_PY}" "${EXEC}" --task "${TASK}" --spawn --instruction "${INSTRUCTION}"
else
  exec "${VENV_PY}" "${EXEC}" --task "${TASK}" --spawn
fi
