RAISE 2026 Summer School — Pre-School Setup Kit
================================================

START HERE:  open  index.html  in your web browser (double-click it).

It walks you through preparing your laptop BEFORE Day 1 (14-16 July 2026,
ENET'Com-Sfax). Plan ~60-90 minutes on good home internet (there are a few
GB of downloads you do NOT want to fetch on school Wi-Fi).

PLATFORM: Ubuntu 24.04 + ROS 2 Jazzy is the ONLY supported platform.
  • Not on Ubuntu 24.04? Install it (dual-boot alongside Windows is fine).
    The scripts will not install on any other version, on WSL, or on macOS.
  • Have ROS 2 Humble installed? It must be removed — the script tells you how.

Contents:
  index.html                  the setup guide (open this first)
  scripts/prepare_machine.sh  installs EVERYTHING (self-contained, no GitHub):
                              ROS 2 Jazzy, Gazebo Harmonic, all lab
                              dependencies, and the Day-2 LeRobot AI toolkit
  scripts/check_setup.sh      readiness check — send us a screenshot of its
                              final summary when you're done

The course code and the pre-trained model are handed to you on Day 1
(USB / shared folder) — no GitHub account needed. Because prepare_machine.sh
already installed every dependency, the Day-1 build takes about 2 minutes.

Questions / problems: contact the instructors via the channel this folder
was shared on.

Prof. Anis Koubaa — RAISE 2026
