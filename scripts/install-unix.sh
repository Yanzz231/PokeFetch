#!/usr/bin/env sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/pokefetch"
CONFIG_PATH="$CONFIG_DIR/config.json"
python3 -m pip install --user -e "$ROOT"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_PATH" ]; then
  printf '{\n  "theme": "side-unicode",\n  "sprites_dir": null\n}\n' > "$CONFIG_PATH"
fi
printf 'PokeFetch installed. Config: %s\n' "$CONFIG_PATH"
