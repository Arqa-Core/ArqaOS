# --- Stage 1: Fetch the latest ArqaLauncher asset ---
FROM alpine:latest AS fetcher
RUN apk add --no-cache curl jq unzip

WORKDIR /tmp
RUN curl -s https://api.github.com/repos/Arqa-Core/ArqaLauncher/releases/latest \
    | jq -r '.assets[] | select(.name | test(".*linux.*|.*zip.*|.*tar.*")) | .browser_download_url' \
    | xargs curl -L -o arqa-launcher-package.zip

RUN mkdir /app && unzip arqa-launcher-package.zip -d /app

# --- Stage 2: Build the Distro Image ---
FROM ghcr.io/ublue-os/bazzite-deck:stable

# Install Cage (Kiosk Wayland Compositor) to handle absolute fullscreen scaling
RUN rpm-ostree install cage

# Copy the fetched frontend into the target directory
COPY --from=fetcher /app /opt/ArqaLauncher

# Create the custom launch script directly in /usr/bin/
RUN echo '#!/bin/bash\n\
# Launch Cage compositor and force ArqaLauncher into standard borderless fullscreen\n\
exec cage -- /opt/ArqaLauncher/arqa-launcher --no-sandbox --fullscreen\n\
' > /usr/bin/arqa-session-start && chmod +x /usr/bin/arqa-session-start

# Create the Desktop Session Entry for SDDM
RUN mkdir -p /usr/share/wayland-sessions && echo '[Desktop Entry]\n\
Name=Arqa Frontend\n\
Comment=Custom Fullscreen Emulation Frontend\n\
Exec=/usr/bin/arqa-session-start\n\
Type=Application\n\
DesktopNames=Arqa\n\
' > /usr/share/wayland-sessions/arqa.desktop

# Configure Autologin to target your new fullscreen layout
RUN mkdir -p /etc/sddm.conf.d && echo '[Autologin]\n\
Relogin=false\n\
Session=arqa.desktop\n\
User=live\n\
' > /etc/sddm.conf.d/autologin.conf

# Keep the SteamOS return shortcut healthy on the KDE skeleton layer
RUN mkdir -p /etc/skel/Desktop && echo '[Desktop Entry]\n\
Name=Return to Frontend\n\
Exec=steamos-session-select arqa\n\
Icon=games-config\n\
Terminal=false\n\
Type=Application\n\
' > /etc/skel/Desktop/return-to-frontend.desktop && chmod +x /etc/skel/Desktop/return-to-frontend.desktop