<!-- Author: Prof. Anis Koubaa <anis.koubaa@gmail.com> -->

# RAISE 2026 — Student Materials

Agentic Robotics & Vision-Language-Action Models for Autonomous Agriculture.
Everything you need to follow the RAISE 2026 summer school and run the labs on
your own machine.

> **Platform:** Ubuntu 24.04 + ROS 2 Jazzy is the only supported platform.

## What's inside

| Folder | What it is |
|---|---|
| `setup_kit/` | **Do this first (before Day 1).** Open `setup_kit/index.html` — it installs ROS 2 Jazzy, Gazebo Harmonic, and the Day-2 AI toolkit. ~60–90 min. |
| `raise_ros2_ws/` | The **course code** — the ROS 2 workspace you build and run (robot, sim tools, lab scripts). |
| `sim/` | Simulator launchers and demo scripts (`raise-sim`, one-command demos). |
| `datasets/` | The **reference dataset** used in Day 2 (a "pick the red tomato" recording). |
| `slides/` | The **lecture slides** (student editions) for Day 1 and Day 2. |
| `lab_guides/` | **Step-by-step hands-on guides** — open the `.html` files, copy-paste the commands. |
| `checkpoints/` | Where the **pre-trained SmolVLA model** goes (handed to you on Day 1 — see the README there). |
| `GETTING_STARTED.md` | How to launch and verify the simulator. |

## Quick start

**1 — Before the school:** open `setup_kit/index.html` and follow it. Run
`setup_kit/scripts/check_setup.sh` at the end and send the instructors the summary.

**2 — Install & build the course** (once, ~5–10 min — this step builds the
ROS 2 workspace; without it there is no `raise-sim`):
```bash
cd sim && ./install.sh
```

**3 — Launch the robot:**
```bash
raise-sim          # opens the greenhouse simulator (leave it running)
```
See `GETTING_STARTED.md` for details and the verify steps.

**4 — Day 1 labs** (ROS 2 tools → an LLM agent): open
[`lab_guides/lab1_handson.html`](lab_guides/lab1_handson.html) and follow it, copy-paste.

**5 — Day 2 labs** (build the dataset → run the SmolVLA model): open
[`lab_guides/lab2_handson.html`](lab_guides/lab2_handson.html). You **run** the
provided model — no training required.

**Slides:** review anytime in `slides/`.

## The pre-trained model

The ~1 GB SmolVLA checkpoint is **not** in this repository — it is handed to you
on Day 1 (USB / shared folder). Place it where `checkpoints/README.md` describes,
and Lab 2.2 will pick it up automatically.

## License

**Educational, non-commercial use only** (CC BY-NC 4.0). © Prof. Anis Koubaa, RAISE 2026 — see `LICENSE.md`.
