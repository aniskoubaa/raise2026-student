#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — single-entry installer.
#
# Detects hardware + ROS distro, then prompts: native or docker.
#   • native → Ubuntu 24.04/Jazzy (TESTED) or 22.04/Humble (UNTESTED)
#   • docker → ROS 2 Jazzy image (works on any host; auto-installs Docker)
set -euo pipefail

SIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SIM_DIR}/.env"

# 1) Detect hardware → writes sim/.env (RAISE_ROS_DISTRO, RAISE_NATIVE_SUPPORTED, …)
"${SIM_DIR}/bootstrap/detect_hardware.sh"

# 2) Read what detection decided, to suggest a sensible default.
native_supported=0
ros_distro=unsupported
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  native_supported="${RAISE_NATIVE_SUPPORTED:-0}"
  ros_distro="${RAISE_ROS_DISTRO:-unsupported}"
fi

if (( native_supported == 1 )); then
  default_mode=native
  echo
  echo "Detected a supported native platform → ROS 2 ${ros_distro}."
  [[ "$ros_distro" == "humble" ]] && echo "(Note: Humble/22.04 is UNTESTED — Jazzy/24.04 is the tested platform.)"
else
  default_mode=docker
  echo
  echo "No supported native platform detected → Docker is recommended (Jazzy image)."
fi

# 3) Prompt: native or docker (default shown in brackets).
# `|| true`: don't let read's EOF return code abort us under `set -e` (e.g. when
# stdin isn't a TTY) — fall back to the default mode instead.
MODE=""
read -r -p "Install mode [native/docker] (default: ${default_mode}): " MODE || true
MODE="${MODE:-$default_mode}"

case "$MODE" in
  native)
    if (( native_supported != 1 )); then
      echo "✗ Native install is not supported on this platform. Choose 'docker'." >&2
      exit 1
    fi
    "${SIM_DIR}/bootstrap/install_native.sh"
    ;;
  docker)
    "${SIM_DIR}/bootstrap/install_docker.sh"
    ;;
  *)
    echo "Unknown mode: $MODE  (expected 'native' or 'docker')" >&2
    exit 1
    ;;
esac
