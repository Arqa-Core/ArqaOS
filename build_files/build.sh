#!/bin/bash
set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages
dnf5 install -y cage plymouth-plugin-script

# Files copied via `cp` lose their git executable bit unless it was set
# in the repo itself - set it explicitly here so we don't depend on
# remembering to `chmod +x` before every commit.
chmod +x /usr/bin/arqa-session-start
chmod +x /usr/bin/arqa-return
chmod +x /usr/libexec/arqa-autologin-setup.sh
chmod +x /etc/skel/Desktop/return-to-frontend.desktop

### Boot splash
# The Plymouth script references Image("background.png") and Image("logo.png")
# relative to the theme's ImageDir. Copy the shared background/logo assets
# into the theme directory under the expected names so they resolve correctly.
cp /usr/share/backgrounds/arqa/arqa-background.png \
   /usr/share/plymouth/themes/arqa/background.png
cp /usr/share/backgrounds/arqa/arqa-logo.png \
   /usr/share/plymouth/themes/arqa/logo.png

# Make our script-based theme the default, then rebuild the initramfs so
# the new theme is actually picked up at boot (plymouth themes that aren't
# baked into initramfs silently fall back to the stock one).
plymouth-set-default-theme arqa

KVER=$(rpm -q --queryformat '%{version}-%{release}.%{arch}\n' kernel-core)
dracut -f --no-hostonly --kver "$KVER"

### Services
systemctl enable podman.socket
systemctl enable sddm.service
systemctl enable arqa-autologin-setup.service
