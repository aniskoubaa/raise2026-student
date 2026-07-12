#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# Day 2 / Lab 2.1 — teleoperation + LeRobot dataset recording (happy path).
#
# One command to start a recording session for a chosen task. The sim must
# already be running (start it with `raise-sim` in another terminal). Because
# teleop is interactive (you drive with the keyboard), this opens the RECORDER
# and tells you to run the TELEOP in a second terminal.
#
# Usage:  d2l1_teleop_record.sh [TASK] [TEAM]
#         d2l1_teleop_record.sh A team07
set -eo pipefail   # NOT -u: colcon setup.bash references unbound vars (COLCON_TRACE)

TASK="${1:-A}"
TEAM="${2:-team00}"

WS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../raise_ros2_ws" && pwd)"
# shellcheck disable=SC1091
source "${WS}/install/setup.bash"

# Pre-flight: is the sim up? (We just need /joint_states to be publishing.)
if ! ros2 topic list 2>/dev/null | grep -q '/joint_states'; then
  echo "✗ sim not detected (/joint_states missing). Start it first:  raise-sim"
  exit 1
fi

cat <<EOF
─────────────────────────────────────────────────────────────
 RAISE 2026 — Lab 2.1 recording session   (task ${TASK}, ${TEAM})
─────────────────────────────────────────────────────────────
 In a SECOND terminal, start teleop and drive the robot:

     ros2 run raise2026_labs 01_teleop.py --task ${TASK}

 This terminal runs the recorder. Follow its prompts:
   ENTER to start an episode, ENTER to stop, keep/discard.
─────────────────────────────────────────────────────────────
EOF

exec ros2 run raise2026_labs 03_record.py --task "${TASK}" --team "${TEAM}"
