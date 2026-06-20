#!/bin/bash
set -euxo pipefail

LOG=/var/tmp/arqa-session-start.log
exec >>"$LOG" 2>&1
echo "=== /etc/arqa/session-start.sh $(date -Is) ==="

export XDG_SESSION_TYPE=wayland
export ELECTRON_OZONE_PLATFORM_HINT=wayland

# VM-safe rendering fallback (wlroots/cage in qemu/noVNC)
export WLR_RENDERER_ALLOW_SOFTWARE=1
export LIBGL_ALWAYS_SOFTWARE=1

ARQA_BIN="/opt/ArqaLauncher/arqa-launcher"

if [[ ! -x "$ARQA_BIN" ]]; then
  echo "missing launcher: $ARQA_BIN"
  exec /usr/bin/bash
fi

exec cage -- "$ARQA_BIN" \
  --ozone-platform=wayland \
  --enable-features=UseOzonePlatform,WaylandWindowDecorations \
  --no-sandbox \
  --disable-gpu-sandbox \
  --disable-gpu \
  --in-process-gpu \
  --start-fullscreen
