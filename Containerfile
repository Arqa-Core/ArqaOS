# --- Stage 1: Fetch the latest ArqaLauncher release asset -------------------
FROM alpine:latest AS fetcher

# Pin to a specific release tag (e.g. "v1.2.0") or keep "latest" to always
# track the newest release.
# Override at build time with:
#   podman build --build-arg LAUNCHER_VERSION=v1.2.0 .
ARG LAUNCHER_VERSION=latest

RUN apk add --no-cache curl jq unzip file tar gzip

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
RUN mkdir -p /app/_extract && cd /app/_extract && \
    if unzip -q /tmp/launcher-package; then \
        echo "Successfully extracted ZIP"; \
    else \
        echo "ZIP extraction failed, trying tar..."; \
        tar -xf /tmp/launcher-package || (echo "TAR extraction also failed"; exit 1); \
    fi && \
    ENTRIES=$(find /app/_extract -maxdepth 1 -type d | tail -n +2 | head -1); \
    if [ -n "$ENTRIES" ] && [ "$(ls -A /app/_extract | grep -v '^\.' | wc -l)" -eq 1 ]; then \
        echo "Flattening single top-level directory"; \
        mv "$ENTRIES"/* /app/ 2>/dev/null || true; \
        mv "$ENTRIES"/.[!.]* /app/ 2>/dev/null || true; \
    else \
        echo "Multiple entries found, moving all"; \
        mv /app/_extract/* /app/ 2>/dev/null || true; \
    fi && \
    rm -rf /app/_extract && \
    if [ ! -f /app/arqa-launcher ] && [ ! -L /app/arqa-launcher ]; then \
        BIN=$(find /app -maxdepth 1 -type f -executable | head -n1); \
        if [ -z "$BIN" ]; then \
            echo "ERROR: no executable found" >&2; \
            ls -laR /app; \
            exit 1; \
        fi; \
        ln -sf "$(basename "$BIN")" /app/arqa-launcher; \
    fi && \
    ls -lh /app/arqa-launcher

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

# === FIX: Disable broken GPG key verification check for terra-mesa repository ===
RUN if [ -f /etc/yum.repos.d/terra-mesa.repo ]; then \
        sed -i 's/gpgcheck=1/gpgcheck=0/g' /etc/yum.repos.d/terra-mesa.repo; \
        sed -i 's/repo_gpgcheck=1/repo_gpgcheck=0/g' /etc/yum.repos.d/terra-mesa.repo || true; \
    fi

RUN rm -rf /ctx

RUN bootc container lint