#!/bin/bash
# arqa-autologin-setup.sh
#
# The ISO's live session runs as user "live", but that account does not
# exist on the installed system - the real account is whatever the person
# created during install. We can't know that name at build time, so on
# first real boot we detect the first human user (UID >= 1000) and write
# the autologin drop-in for them, then disable ourselves.

set -euo pipefail

STAMP=/etc/arqa/.autologin-configured
mkdir -p /etc/arqa

if [ -f "$STAMP" ]; then
    exit 0
fi

TARGET_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}')"

if [ -z "${TARGET_USER:-}" ]; then
    # No human user yet (e.g. still on the live ISO) - try again next boot.
    exit 0
fi

cat > /etc/sddm.conf.d/20-autologin.conf <<EOF
[Autologin]
Relogin=false
Session=arqa.desktop
User=${TARGET_USER}
EOF

touch "$STAMP"
