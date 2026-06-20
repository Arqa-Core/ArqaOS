# --- Stage 1: Fetch the latest ArqaLauncher release asset -------------------
FROM alpine:latest AS fetcher

# Pin to a specific release tag (e.g. "v1.2.0") or keep "latest" to always
# track the newest release. Override at build time with:
#   podman build --build-arg LAUNCHER_VERSION=v1.2.0 .
ARG LAUNCHER_VERSION=latest

RUN apk add --no-cache curl jq unzip file

WORKDIR /tmp

# Pull the release metadata once, fail loudly if it's empty (rate-limited /
# no releases yet / repo renamed) instead of silently producing an empty zip.
RUN set -euo pipefail; \
    if [ "${LAUNCHER_VERSION}" = "latest" ]; then \
        RELEASE_URL="https://api.github.com/repos/Arqa-Core/ArqaLauncher/releases/latest"; \
    else \
        RELEASE_URL="https://api.github.com/repos/Arqa-Core/ArqaLauncher/releases/tags/${LAUNCHER_VERSION}"; \
    fi; \
    curl -fsSL "${RELEASE_URL}" -o release.json; \
    URL=$(jq -r '.assets[] | select(.name | test("linux.*\\.(zip|tar\\.gz)$")) | .browser_download_url' release.json | head -n1); \
    if [ -z "$URL" ] || [ "$URL" = "null" ]; then \
        echo "ERROR: no linux release asset found on ArqaLauncher release '${LAUNCHER_VERSION}'" >&2; \
        cat release.json >&2; \
        exit 1; \
    fi; \
    echo "Fetching: $URL"; \
    curl -fL "$URL" -o launcher-package

# Electron Forge's zip/tar maker nests the binary inside a folder named
# after productName, e.g. "arqa-launcher-linux-x64/arqa-launcher". We don't
# want that path to leak into the Containerfile, so flatten it here: find
# the single top-level directory (if any) and promote its contents up.
RUN set -euo pipefail; \
    mkdir -p /app/_extract; \
    cd /app/_extract; \
    if file /tmp/launcher-package | grep -qi zip; then \
        unzip -q /tmp/launcher-package; \
    else \
        tar -xf /tmp/launcher-package; \
    fi; \
    ENTRIES=$(ls -A); \
    COUNT=$(echo "$ENTRIES" | wc -l); \
    if [ "$COUNT" -eq 1 ] && [ -d "$ENTRIES" ]; then \
        mv "$ENTRIES"/* /app/ 2>/dev/null || true; \
        mv "$ENTRIES"/.[!.]* /app/ 2>/dev/null || true; \
    else \
        mv /app/_extract/* /app/; \
    fi; \
    rm -rf /app/_extract; \
    BIN=$(find /app -maxdepth 1 -type f -executable | head -n1); \
    if [ -z "$BIN" ]; then echo "ERROR: no executable found in extracted package" >&2; ls -laR /app >&2; exit 1; fi; \
    chmod +x "$BIN"; \
    if [ "$(basename "$BIN")" != "arqa-launcher" ]; then ln -sf "$(basename "$BIN")" /app/arqa-launcher; fi

# --- Stage 2: Build the ArqaOS image ----------------------------------------
FROM ghcr.io/ublue-os/bazzite-deck:stable

COPY build_files /ctx/build_files
COPY system_files /ctx/system_files
COPY --from=fetcher /app /opt/ArqaLauncher

# build.sh copies system_files/ over /, installs packages via dnf5, and
# enables the systemd units listed below - keeping all of that in one
# script (instead of scattered RUN lines) is what the upstream image
# template expects, and is what makes `just build` reproducible locally.
RUN chmod +x /ctx/build_files/build.sh && /ctx/build_files/build.sh

RUN rm -rf /ctx

RUN bootc container lint
