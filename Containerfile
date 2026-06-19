# --- Stage 1: Fetch the latest ArqaLauncher asset ---
FROM alpine:latest AS fetcher
RUN apk add --no-essential curl jq

WORKDIR /tmp
RUN curl -s https://api.github.com/repos/Arqa-Core/ArqaLauncher/releases/latest \
    | jq -r '.assets[] | select(.name |行动.test(".*linux.*|.*AppImage.*|.*zip.*")) | .browser_download_url' \
    | xargs curl -L -o arqa-launcher-package

# Extract if it's a zip/tar, or prepare the binary/AppImage
# (Adjust this depending on if your release output is a zip, tar.gz, or binary)
RUN mkdir /app && \
    if echo "arqa-launcher-package" | grep -q ".zip"; then \
        unzip arqa-launcher-package -d /app; \
    else \
        mv arqa-launcher-package /app/ArqaLauncher && chmod +x /app/ArqaLauncher; \
    fi


# --- Stage 2: Build the Distro Image ---
FROM ghcr.io/ublue-os/bazzite-deck:stable

# Copy the fetched frontend from Stage 1 into the system
COPY --from=fetcher /app /opt/ArqaLauncher

# Create the custom launch script directly in /usr/bin/
RUN echo '#!/bin/bash\n\
# Initialize gamescope or run directly. Running under gamescope is highly recommended for scaling & controllers:\n\
gamescope -f -r 60 -- /opt/ArqaLauncher/ArqaLauncher --no-sandbox\n\
' > /usr/bin/arqa-session-start && chmod +x /usr/bin/arqa-session-start

# Create a custom Desktop Session Entry for SDDM/Display Manager
RUN mkdir -p /usr/share/wayland-sessions && echo '[Desktop Entry]\n\
Name=Arqa Frontend\n\
Comment=Custom Emulation Frontend\n\
Exec=/usr/bin/arqa-session-start\n\
Type=Application\n\
DesktopNames=Arqa\n\
' > /usr/share/wayland-sessions/arqa.desktop

# Set your custom session as the default boot target for the user session
RUN mkdir -p /etc/sddm.conf.d && echo '[Autologin]\n\
Relogin=false\n\
Session=arqa.desktop\n\
User=live\n\
' > /etc/sddm.conf.d/autologin.conf

# Create a "Return to Frontend" shortcut on the default desktop skeleton
RUN mkdir -p /etc/skel/Desktop && echo '[Desktop Entry]\n\
Name=Return to Frontend\n\
Exec=steamos-session-select arqa\n\
Icon=games-config\n\
Terminal=false\n\
Type=Application\n\
' > /etc/skel/Desktop/return-to-frontend.desktop && chmod +x /etc/skel/Desktop/return-to-frontend.desktop