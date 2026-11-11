#!/usr/bin/env bash
# Re-export GNOME settings into this repo. Run after changing settings in GNOME.
# Repo is public: never commit device pairing, certs or tokens.
set -euo pipefail
cd "$(dirname "$0")"

# Drop whole [extensions/gsconnect*] sections (paired devices + certificate),
# app-picker-layout (per-machine app grid) and any *token*/*certificate* keys.
scrub() {
  awk '
    /^\[/ { skip = ($0 ~ /^\[extensions\/gsconnect/) }
    skip { next }
    /^app-picker-layout=/ { next }
    /^[a-z0-9-]*(token|certificate|private-key|password)[a-z0-9-]*=/ { next }
    { print }
  '
}

dconf dump /org/gnome/desktop/ | scrub > desktop.ini
dconf dump /org/gnome/shell/ | scrub > shell.ini
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ | scrub > media-keys.ini

# Self-check: fail loudly if a secret slipped through
if grep -qiE 'BEGIN CERTIFICATE|token=|password=' ./*.ini; then
  echo "dump.sh: secret-looking value left in ini files, aborting" >&2
  exit 1
fi
