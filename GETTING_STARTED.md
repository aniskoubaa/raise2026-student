# RAISE 2026 — Getting Started

5 minutes from `git clone` to driving a robot in a simulated Sfax greenhouse.

## Prerequisites
- **Ubuntu 24.04** → ROS 2 Jazzy — ✅ tested reference platform
- Ubuntu 22.04 → ROS 2 Humble — ⚠️ untested / best-effort (use Docker if it misbehaves)
- Any other OS (incl. WSL) → use the **Docker path** (always Jazzy)
- Internet + `sudo` password
- Docker is **not** required up front — the Docker path installs it for you.

## Fastest path — one command on a fresh machine

Clones the repo and runs the installer in one shot:

```bash
curl -fsSL https://raw.githubusercontent.com/aniskoubaa/raise_summer_school/main/RAISE2026/sim/bootstrap/bootstrap.sh | bash
```

## Install (already cloned, once, ~5–10 min)

```bash
cd RAISE2026/sim
./install.sh                    # guided: detects your HW + distro, asks native vs docker
# or call a path directly:
./bootstrap/install_native.sh   # 24.04/Jazzy (tested) or 22.04/Humble (untested)
./bootstrap/install_docker.sh   # Docker (Jazzy image) — auto-installs Docker if missing
```

Installs ROS 2 (Jazzy on 24.04, Humble on 22.04), Gazebo Harmonic, all robot packages, builds the workspace, configures the firewall, and installs the `raise-sim` / `raise-stop` commands. It finishes by running a **smoke test** that verifies everything works and prints a pass/fail report.

## Verify the install anytime

```bash
cd RAISE2026/sim
./bootstrap/smoke_test.sh        # ROS 2 + build + Gazebo Harmonic + Python imports
```

A green `✓ All required checks passed` means you're ready. (One warning about `OPENAI_API_KEY` is expected — only lab 09 needs it.)

## Launch the sim

```bash
raise-sim
```

A Gazebo window opens with an agroforestry plot: Husky + UR5e + RealSense, tomato rows (healthy / wilted / diseased), olive and fig groves, chickens, ducks.

## Drive the robot

Pick one — all three publish to `/cmd_vel`:

| Mode | Command |
|---|---|
| **Keyboard** | `ros2 run raise2026_teleop teleop_keyboard` |
| **Gamepad** | `ros2 launch raise2026_teleop teleop_joy.launch.py` |
| **Phone**   | `ros2 run raise2026_teleop teleop_phone` → on phone visit `http://<laptop-ip>:5000/` |

Keyboard keys: `w`/`s` forward/back · `a`/`d` turn · SPACE stop · Ctrl-C quit.
Gamepad: hold A and push the left stick; A+B for turbo.

## See what the robot sees

```bash
ros2 run rqt_image_view rqt_image_view /wrist_camera/image_raw
```

## Stop

```bash
raise-stop
```

## When things break

- Sim won't launch / hangs → `raise-stop`, then `raise-sim` from a **fresh terminal**.
- Camera looks black → drive forward; the arm is folded looking at the chassis at spawn.
- Keys don't register → use a real terminal (gnome-terminal, terminator). VS Code's integrated terminal can swallow some keys.
- Phone can't reach the laptop → same WiFi, then `sudo ufw allow 5000`.
- Something feels off after install → run `./bootstrap/smoke_test.sh` and read the report.
- On Ubuntu 22.04 (Humble, untested) and hitting trouble → fall back to the Docker path: `./bootstrap/install_docker.sh` (always Jazzy).

## What's where

```
RAISE2026/
├── raise_ros2_ws/                          ROS 2 packages
│   └── src/
│       ├── raise2026_description/          robot URDF (Husky + UR5e + RealSense)
│       ├── raise2026_worlds/               Gazebo worlds + plant / tree / animal models
│       ├── raise2026_bringup/              sim.launch.py + ros_gz bridge
│       ├── raise2026_teleop/               keyboard / joystick / phone drivers
│       ├── raise2026_tools/                LLM-callable service stubs (next step)
│       └── raise2026_demos/                lecture demos (next step)
└── sim/
    ├── install.sh                          guided installer (native vs docker)
    ├── bootstrap/
    │   ├── bootstrap.sh                     remote one-liner: clone repo → install
    │   ├── install_native.sh                native installer (Jazzy / Humble)
    │   ├── install_docker.sh                Docker installer (auto-installs Docker)
    │   └── smoke_test.sh                    post-install verification
    ├── raise-sim                           launcher
    ├── raise-stop                           shutdown
    └── README.md                           full docs + Docker path
```

## Next

After you can drive the Husky around and see the camera feed, the next milestones are:

1. **Nav2 + oracle localization** — `ros2 action send_goal /navigate_to_pose …` drives autonomously
2. **`raise2026_tools` service nodes** — `nav_to_row`, `move_to_pose`, `inspect_plant` — the LLM-callable surface
3. **`d1l1_tools_demo`** — first lab: agent calls those services to inspect a plant

That's it — have fun.
