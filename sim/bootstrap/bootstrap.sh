#!/usr/bin/env bash
# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — remote bootstrap: clone (or update) the repo, then install.
#
# One-liner (fresh machine, nothing checked out yet):
#   curl -fsSL https://raw.githubusercontent.com/aniskoubaa/raise_summer_school/main/RAISE2026/sim/bootstrap/bootstrap.sh | bash
#
# Optional env:
#   RAISE_DIR=<path>   where to clone   (default: $HOME/raise_summer_school)
#   RAISE_REF=<ref>    branch/tag/sha   (default: main)
#
# After cloning it hands off to sim/install.sh (which prompts native vs docker
# and runs the smoke test). When piped via `curl | bash` the prompt has no TTY,
# so install.sh falls back to its detected default automatically.
set -euo pipefail

REPO_URL="https://github.com/aniskoubaa/raise_summer_school.git"
RAISE_DIR="${RAISE_DIR:-${HOME}/raise_summer_school}"
RAISE_REF="${RAISE_REF:-main}"

# ── git present? (auto-install on apt systems) ─────────────────────────────
if ! command -v git >/dev/null 2>&1; then
  echo "[bootstrap] git not found — installing…"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y git
  else
    echo "✗ Please install git manually, then re-run." >&2
    exit 1
  fi
fi

# ── clone or update ─────────────────────────────────────────────────────────
if [[ -d "${RAISE_DIR}/.git" ]]; then
  echo "[bootstrap] Repo already at ${RAISE_DIR} — updating to '${RAISE_REF}'…"
  git -C "${RAISE_DIR}" fetch origin "${RAISE_REF}"
  git -C "${RAISE_DIR}" checkout "${RAISE_REF}"
  git -C "${RAISE_DIR}" pull --ff-only origin "${RAISE_REF}" || true
else
  echo "[bootstrap] Cloning ${REPO_URL} → ${RAISE_DIR}…"
  git clone "${REPO_URL}" "${RAISE_DIR}"
  git -C "${RAISE_DIR}" checkout "${RAISE_REF}" || true
fi

# ── hand off to the installer ───────────────────────────────────────────────
SIM_DIR="${RAISE_DIR}/RAISE2026/sim"
if [[ ! -f "${SIM_DIR}/install.sh" ]]; then
  echo "✗ install.sh not found under ${SIM_DIR} — is RAISE_REF='${RAISE_REF}' correct?" >&2
  exit 1
fi

echo "[bootstrap] Repo ready. Launching installer (${SIM_DIR}/install.sh)…"
cd "${SIM_DIR}"
exec ./install.sh "$@"
