#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 container entrypoint.
# Sources ROS + workspace overlay, then exec's the command.
set -e

# shellcheck disable=SC1091
source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"

if [[ -f /raise_ros2_ws/install/setup.bash ]]; then
  # shellcheck disable=SC1091
  source /raise_ros2_ws/install/setup.bash
elif [[ -d /raise_ros2_ws/src ]]; then
  echo "[entrypoint] /raise_ros2_ws is not built yet. All ROS deps are baked into"
  echo "[entrypoint] the image, so just build the workspace:"
  echo "             cd /raise_ros2_ws"
  echo "             colcon build --symlink-install"
  echo "             source install/setup.bash"
  echo "[entrypoint] (Only if you ADD new deps to a package.xml first run:"
  echo "[entrypoint]   sudo rosdep init && rosdep update && rosdep install --from-paths src --ignore-src -r -y)"
fi

exec "$@"
