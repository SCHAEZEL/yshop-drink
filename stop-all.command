#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
UNIAPP_DIR="$ROOT_DIR/yshop-drink-uniapp-vue3"
HBUILDER_CLI="/Applications/HBuilderX.app/Contents/MacOS/cli"

kill_port() {
  local port="$1"
  local pids
  pids="$(lsof -ti tcp:"$port" 2>/dev/null || true)"
  if [ -n "$pids" ]; then
    echo "$pids" | xargs kill
  fi
}

echo "Stopping project services..."
kill_port 48081
kill_port 48082
kill_port 5173

"$HBUILDER_CLI" project close --path "$UNIAPP_DIR" >/dev/null 2>&1 || true
"$HBUILDER_CLI" app quit >/dev/null 2>&1 || true

echo "Stopped ports 48081, 48082, and 5173."
