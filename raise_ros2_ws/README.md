# `raise_ros2_ws/` — RAISE 2026 ROS 2 Workspace

The colcon workspace shipped with the summer school. Contains only the **`raise2026_*` packages** we author — third-party dependencies (Husky, UR description, MoveIt 2, Nav2, gazebo_ros) come in via `rosdep` at install time, not vendored here.

## Packages

| Package                 | Build type     | Role                                                          |
| ----------------------- | -------------- | ------------------------------------------------------------- |
| `raise2026_description` | `ament_cmake`  | URDF/xacro for Husky A200 + UR5e + Robotiq 2F-85 + RealSense  |
| `raise2026_worlds`      | `ament_cmake`  | Gazebo Harmonic `.sdf` greenhouse worlds + plant meshes       |
| `raise2026_bringup`     | `ament_python` | Launch files: world + robot + cameras + nav stack             |
| `raise2026_tools`       | `ament_python` | ROS 2 services the LLM agent calls (`move_to_pose`, etc.)     |
| `raise2026_demos`       | `ament_python` | One demo node per lecture (≤80 lines each)                    |

## Build

Most people don't build by hand — `../sim/install.sh` (or `../sim/bootstrap/install_native.sh`)
installs ROS 2 + Gazebo + deps and builds this workspace for you on Ubuntu 24.04
(Jazzy, tested) or 22.04 (Humble, untested). To build manually inside an already
set-up environment:

```bash
cd RAISE2026/raise_ros2_ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --symlink-install
source install/setup.bash
```

Verify it afterwards with `../sim/bootstrap/smoke_test.sh`.

## What ships to GitHub

Only `src/`. `build/`, `install/`, `log/` are gitignored (see `.gitignore`).
