#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# Day 3 / Lecture 1 — full-stack planner + executor.
set -euo pipefail

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../raise_ros2_ws" && pwd)"
# shellcheck disable=SC1091
source "${WS}/install/setup.bash"

# [TODO]:
#   ros2 launch raise2026_bringup sim.launch.py &
#   sleep 5
#   ros2 run raise2026_demos d3l1_planner_executor

echo "[scaffold] d3l1_planner_executor.sh — not yet wired"
