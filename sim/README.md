# `sim/` — RAISE 2026 Install & Orchestration

Everything **around** the ROS 2 workspace: hardware detection, native install,
Docker, demo launch scripts. The workspace itself lives at `../raise_ros2_ws/`.

## Supported platforms

| Host                          | ROS 2 distro | Gazebo   | Status                         |
| ----------------------------- | ------------ | -------- | ------------------------------ |
| **Ubuntu 24.04** (Noble)      | **Jazzy**    | Harmonic | ✅ **TESTED** — reference platform |
| Ubuntu 22.04 (Jammy)          | Humble       | Harmonic | ⚠️ **UNTESTED** — best-effort   |
| Any other host (incl. WSL)    | — (Docker)   | Harmonic | Docker image, always **Jazzy** |

> ⚠️ RAISE 2026 was developed and verified **only** on Ubuntu 24.04 + ROS 2 Jazzy.
> The Ubuntu 22.04 + Humble native path is provided as a convenience and has **not
> been tested** — it installs Gazebo Harmonic on Humble (via `ros-humble-ros-gzharmonic`)
> so the labs/worlds are unchanged, but if you hit trouble on 22.04 the **Docker
> path (always Jazzy) is the reliable fallback**.

## Zero-to-running on a fresh machine (clones + installs + verifies)

Nothing checked out yet? One command clones the repo and runs the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/aniskoubaa/raise_summer_school/main/RAISE2026/sim/bootstrap/bootstrap.sh | bash
```

It installs `git` if missing, clones to `~/raise_summer_school` (override with
`RAISE_DIR=`), then hands off to `install.sh`. When piped through `curl | bash`
the native/docker prompt has no terminal, so it uses the detected default
(native on supported Ubuntu, else docker).

## One-shot install (already cloned)

```bash
./install.sh                    # detects HW + distro, then asks: native or docker
raise-sim                       # (native) launches Gazebo with the greenhouse + Husky
raise-stop                      # graceful shutdown
```

Or call a path directly:

```bash
./bootstrap/install_native.sh   # Ubuntu 24.04/Jazzy (tested) or 22.04/Humble (untested)
./bootstrap/install_docker.sh   # Docker (Jazzy image) — auto-installs Docker if missing
```

Every install path ends with a **smoke test** that verifies ROS 2, the workspace
build, all `raise2026_*` packages + executables, Gazebo Harmonic, and the fragile
`cv_bridge`/`numpy<2` import — then prints a pass/warn/fail summary. Run it any
time on its own:

```bash
./bootstrap/smoke_test.sh
```

The native installer:

1. Detects + strips Anaconda from PATH (Anaconda's python lacks `catkin_pkg`).
2. Picks the ROS distro from the Ubuntu version (24.04→Jazzy, 22.04→Humble).
3. **Installs ROS 2** (adds key + apt source, `apt install ros-<distro>-desktop ros-dev-tools`) — skipped if `/opt/ros/<distro>` already exists.
4. Installs Gazebo Harmonic + core apt packages; description/simulator packages are best-effort and any that are missing on a distro are reported, not fatal.
5. `rosdep`s transitive deps from the workspace.
6. `colcon build`s with `Python3_EXECUTABLE=/usr/bin/python3` (anaconda-safe).
7. Opens UDP multicast on `224.0.0.0/4` in ufw (gz-transport service discovery).
8. Disables Gazebo's first-run Quick Start dialog (`~/.gz/sim/8/gui.config`).
9. Symlinks `raise-sim` and `raise-stop` into `/usr/local/bin`.

**Prerequisites:** Ubuntu 24.04 or 22.04 + working internet + `sudo`. ROS 2 itself is installed by the script. **Docker is no longer a prerequisite** — `install_docker.sh` installs `docker.io` + `docker-compose-v2` (and, on GPU tiers, the NVIDIA container toolkit) automatically if they're missing.

After install, **any shell** can launch the sim — no need to source the workspace manually; `raise-sim` does it.

## Structure

```
sim/
├── install.sh                       # router: detects HW → prompts native or docker
├── raise-sim                        # standalone launcher (env-clean + PRIME offload)
├── raise-stop                       # graceful + forceful shutdown
├── bootstrap/
│   ├── bootstrap.sh                 # remote one-liner: clone repo → install (curl | bash)
│   ├── detect_hardware.sh           # writes sim/.env (OS, GPU, RAM, tier, ROS distro)
│   ├── install_native.sh            # 24.04/Jazzy (tested) or 22.04/Humble (untested)
│   ├── install_docker.sh            # docker path — auto-installs Docker if missing
│   └── smoke_test.sh                # post-install verification (ROS, build, gz, imports)
├── docker/
│   ├── Dockerfile                   # ROS 2 Jazzy + Gazebo Harmonic + Quick-Start fix baked in
│   ├── docker-compose.yml           # CPU default
│   └── docker-compose.gpu.yml       # nvidia runtime override
├── demos/                           # one shell entry per lecture (D1L1, D1L2, …)
└── README.md
```

## What `raise-sim` does for you

Three classes of environment hazards on student machines, all handled in one script:

| Hazard | Symptom | Fix in `raise-sim` |
|---|---|---|
| VS Code snap env | `gz sim gui` dies with `symbol lookup error` | strips `GTK_PATH`, `LOCPATH`, `XDG_*`, `VSCODE_*` |
| Anaconda Python shadowing | `colcon build` fails on `catkin_pkg` | strips `CONDA_*` and `/anaconda` from PATH |
| Hybrid Intel + NVIDIA GPU | Gazebo hangs at GL context creation | conditionally sets `__NV_PRIME_RENDER_OFFLOAD=1` if `nvidia-smi` reports a card |

Plus: sets `XAUTHORITY` for X11 auth + sources ROS 2 + the workspace overlay.

## Hardware tiers

`detect_hardware.sh` classifies the machine and writes `sim/.env`:

| `RAISE_HW_TIER` | Trigger             | VLA backend                    | Gazebo renderer |
| --------------- | ------------------- | ------------------------------ | --------------- |
| `CPU_ONLY`      | no NVIDIA GPU       | remote API                     | Ogre1, low tex  |
| `GPU_LOW`       | GPU, 6–16 GB VRAM   | remote API; local VLM allowed  | Ogre2           |
| `GPU_HIGH`      | GPU, ≥16 GB VRAM    | optional local VLA             | Ogre2           |

## Common operations

```bash
raise-sim                                    # full sim, default greenhouse_2026 world
raise-sim world:=greenhouse_2026_lite.sdf    # CPU-only / weak GPU
raise-sim y:=-1.0                            # spawn Husky in a different aisle
raise-stop                                   # graceful then forceful shutdown
```

## Docker (cross-platform fallback — always Jazzy)

```bash
./bootstrap/install_docker.sh         # auto-installs Docker if missing, then builds the image
docker compose --env-file .env -f docker/docker-compose.yml run --rm raise2026
# inside the container, build the workspace (one-time):
#   cd /raise_ros2_ws && colcon build --symlink-install
#   ros2 launch raise2026_bringup sim.launch.py
```

The Docker image is **always ROS 2 Jazzy + Gazebo Harmonic** regardless of the host
OS — the container isolates the distro, so a 22.04 (or non-Ubuntu) host still gets the
tested Jazzy stack. `install_docker.sh` will:

- install `docker.io` + `docker-compose-v2` via apt if Docker isn't present, and add you to the `docker` group (re-login or `newgrp docker` to use it without `sudo`);
- on GPU tiers, best-effort install the NVIDIA container toolkit so the GPU compose override works.

Docker bakes in the Quick-Start-dialog fix; ufw is not relevant inside the container.
