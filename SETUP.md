# ArqaOS refactor — what I found, what I fixed, what you need to do

I pulled your actual `Containerfile` and `build_files/build.sh` from GitHub to
audit them rather than guess. Here's what was actually wrong, then the
drop-in fixes, then the steps to get `build-disk.yml` producing a real ISO.

## Bugs found in the current repo

1. **`build_files/build.sh` was never called.** Your `Containerfile`
   replaced the whole second stage with raw `RUN` lines and never invoked
   `/ctx/build_files/build.sh`. That means `tmux`, `podman.socket`, and
   anything in `system_files/` were silently doing nothing — the template's
   own scaffolding was dead code.
2. **The `echo '...\n\'` blocks don't produce real newlines.** Plain `echo`
   (no `-e`) writes the literal two characters `\` and `n` into the file,
   not a line break. Your `arqa.desktop`, `autologin.conf`, and
   `return-to-frontend.desktop` were being written as single garbled lines —
   none of them would have parsed correctly.
3. **Electron defaults to X11/XWayland, which Cage doesn't provide.**
   Cage is Wayland-only. Without `--ozone-platform=wayland` (and the Ozone
   feature flag), Electron tries the X11 backend and the kiosk session
   would show a black screen.
4. **Autologin was hardcoded to `User=live`.** `live` is the *ISO* session
   user — it doesn't exist on an installed system. The real account is
   whatever the person names during install, which you can't know at build
   time. I replaced this with a first-boot service that detects the first
   real user (UID ≥ 1000) and writes the autologin config for them.
5. **The release fetcher had no failure handling.** If the GitHub API call
   was rate-limited or the regex matched nothing, `jq` would emit nothing,
   `xargs curl` would silently no-op, and `unzip` would fail on garbage —
   but the build would look "successful" until boot. It now fails loudly
   with a clear error.
6. **Electron Forge's archive isn't flat.** The zip/tar Forge produces
   nests everything inside a folder named after `productName` (e.g.
   `arqa-launcher-linux-x64/arqa-launcher`), so `/opt/ArqaLauncher/arqa-launcher`
   almost certainly didn't exist as written. The fetcher stage now detects
   and flattens that wrapper folder automatically.

## What I'm handing you

A repo-shaped folder (mirrors your actual layout) — copy these paths
straight into `ArqaOS/`:

```
Containerfile                                          (fixed)
build_files/build.sh                                    (fixed)
system_files/usr/bin/arqa-session-start                 (Cage + Wayland flags)
system_files/usr/libexec/arqa-autologin-setup.sh         (first-boot autologin)
system_files/usr/lib/systemd/system/arqa-autologin-setup.service
system_files/usr/share/wayland-sessions/arqa.desktop
system_files/etc/skel/Desktop/return-to-frontend.desktop
system_files/usr/share/plymouth/themes/arqa/arqa.plymouth
system_files/usr/share/plymouth/themes/arqa/arqa.script
system_files/usr/share/plymouth/themes/arqa/background.png   (your logo, themed)
system_files/usr/share/plymouth/themes/arqa/logo.png
system_files/usr/share/sddm/themes/breeze/theme.conf.user    (login bg override)
system_files/usr/share/backgrounds/arqa/arqa-background.png
system_files/usr/share/backgrounds/arqa/arqa-logo.png
```

Why `system_files/` instead of more `RUN echo` blocks: it's the convention
your `build.sh` already expects (`cp -avf /ctx/system_files/. /`), every
file lands at the same path on the real filesystem, and you can preview/edit
plain files instead of escaped shell strings.

**One thing only you can fix:** `arqa-session-start` assumes the extracted
binary is reachable as `/opt/ArqaLauncher/arqa-launcher`. The fetcher stage
now auto-detects the real executable and symlinks it to that name, but if
your Electron Forge `productName` ever changes, double check the symlink
logic still finds exactly one executable at the top level.

## Theming

I used your actual uploaded logo (cropped, no recreation) and color-sampled
your launcher screenshot's background gradient (`#050310` → `#1a0f3f` glow
band → fade) so the boot splash matches what people see a few seconds later
in the launcher itself:

- **Plymouth** (`arqa` theme, script-based): full-bleed gradient + glow,
  centered logo, three pulsing dots tied to boot progress.
- **SDDM**: a `theme.conf.user` override on the existing Breeze theme —
  this only swaps the background image, it doesn't fork/replace the QML
  theme, so login still works normally. Since you're autologging in, this
  screen is mostly a safety net for whenever autologin doesn't apply.
- **GRUB** I left untouched — Bazzite usually boots with a short/quiet
  GRUB timeout already, so it's low-visibility. Say the word if you want a
  matching `/boot/grub2/themes/arqa` background too.

## Repo setup checklist (for `build-disk.yml` to actually produce an ISO)

Your repo is still on the stock `ublue-os/image-template` README defaults —
none of these one-time steps look done yet:

1. **Cosign key** (builds fail without this):
   ```
   COSIGN_PASSWORD="" cosign generate-key-pair
   gh secret set SIGNING_SECRET < cosign.key
   ```
   Commit `cosign.pub`, never commit `cosign.key`.

2. **`image-template.env`** — set:
   ```
   IMAGE_NAME=arqaos
   REPO_ORGANIZATION=Arqa-Core
   ```

3. **`disk_config/iso.toml`** — point it at your own image, not the
   template's placeholder:
   ```toml
   [[customizations.installer.modules]]
   ...
   ```
   The line that matters is the container image reference — it must read
   `ghcr.io/arqa-core/arqaos:latest` (lowercase, matches what `build.yml`
   actually publishes to GHCR).

4. **`.github/workflows/build-disk.yml`** — if `IMAGE_NAME` /
   `REPO_ORGANIZATION` above don't match the defaults, also update this
   workflow's `IMAGE_REGISTRY`, `IMAGE_NAME`, and `DEFAULT_TAG` env vars to
   match, or it'll try to pull a disk image source that doesn't exist.

5. **Enable Actions** on the repo (Actions tab → enable workflows) if you
   haven't already — forks/templates ship with workflows disabled by
   default.

6. **Optional S3 upload** — only needed if you want disk images pushed to a
   bucket instead of just downloaded from the workflow run's Artifacts tab.
   Needs `S3_PROVIDER`, `S3_BUCKET_NAME`, `S3_ACCESS_KEY_ID`,
   `S3_SECRET_ACCESS_KEY`, `S3_REGION`, `S3_ENDPOINT` as Action secrets.

## Testing before pushing

You don't need CI to find out if the Containerfile is broken:

```
just build              # builds the OCI image locally with podman
just build-qcow2        # builds a bootable qcow2 from that image
just run-vm-qcow2       # boots it in a VM so you can see Cage/Plymouth live
```

That loop is much faster than waiting on GitHub Actions, and it's exactly
what will catch a wrong binary path or a missing Wayland flag before it
ships.
