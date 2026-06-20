# ArqaOS

A customized Fedora Atomic (bootc) distribution with an integrated PS3 XMB-inspired emulation kiosk frontend.

> **Status**: Active development | Builds available at [ghcr.io/Arqa-Core/arqaos](https://ghcr.io/Arqa-Core/arqaos)

## Overview

ArqaOS is a purpose-built Linux operating system designed for retro gaming and emulation. It combines:

- **Base OS**: Fedora Atomic (bootc) leveraging [ublue-os/bazzite-deck](https://github.com/ublue-os/bazzite-deck) as the foundation
- **Launcher**: ArqaLauncher, an Electron-based full-screen kiosk UI inspired by the PlayStation 3 XMB interface
- **Session Management**: Wayland compositor (`cage`), SDDM display manager, and auto-login session orchestration
- **Boot Experience**: Custom Plymouth theme with animated splash screen

The result is a seamless, immersive kiosk experience where users boot directly into a game launcher without seeing traditional desktop elements.

## Architecture

```
ArqaOS (this repository)
├── Containerfile          → Two-stage build: fetch ArqaLauncher, assemble image
├── Containerfile.dev      → Development build using local ArqaLauncher
├── build_files/           → Installation and configuration scripts
│   └── build.sh           → Main provisioning script
├── system_files/          → System files injected into image
│   ├── etc/               → Configuration files (SDDM, session)
│   ├── usr/bin/           → Executable scripts (arqa-session-start, arqa-return)
│   ├── usr/libexec/       → Service helpers
│   └── usr/share/         → Assets (backgrounds, Plymouth theme, SDDM config)
├── disk_config/           → bootc-image-builder configurations for ISO/QCOW2
│   ├── iso.toml           → ISO build configuration
│   ├── iso-gnome.toml     → ISO with GNOME (variant)
│   └── iso-kde.toml       → ISO with KDE (variant)
├── Justfile               → Build automation (podman, ISO, VM)
└── .github/workflows/     → GitHub Actions CI/CD
    ├── build.yml          → Container image build and push
    └── build-iso.yml      → ISO artifact generation

ArqaLauncher (separate repository)
├── main.js                → Electron main process, IPC, emulator management
├── preload.js             → IPC bridge
├── renderer/
│   ├── renderer.js        → React UI (XMB menu, library, settings)
│   ├── style.css          → Styling and animations
│   ├── index.html         → Electron shell
│   └── assets/            → React UMD bundles, sounds, images
└── package.json           → Dependencies and metadata
```

### Build Flow

1. **Local Development**
   ```bash
   just build-dev              # Build with local ArqaLauncher (requires npm install in launcher repo)
   just build                  # Build with latest release from GitHub
   ```

2. **CI/CD (GitHub Actions)**
   - **build.yml**: Triggers on push to `main`, builds container image, signs with cosign, pushes to GHCR
   - **build-iso.yml**: Triggered by build.yml completion, downloads image, generates ISO using bootc-image-builder

3. **Distribution**
   - Container image: `ghcr.io/Arqa-Core/arqaos:latest`
   - ISO artifact: Available in GitHub release for tagged commits
   - qcow2 image: Generated for VM testing

## Design Aesthetic

ArqaOS follows a cohesive visual language inspired by the PlayStation 3 XMB:

| Element | Color | Usage |
|---------|-------|-------|
| **Background** | `#05030c` → `#050310` → `#0a0420` → `#100633` (gradient) | Deep space atmosphere |
| **Accent** | `rgba(138, 84, 255, 0.8)` (`#8a54ff`) | Glow, highlights, focus states |
| **Text** | `#eef0ff` | Labels, menu items |
| **Tertiary** | `#1a1a3e` | Secondary elements |

This palette is maintained across:
- Plymouth boot animation
- SDDM login screen
- ArqaLauncher UI (XMB menu, backgrounds, icons)
- System backgrounds

## Features

### ✅ Current Capabilities

- **XMB-Style Navigation**: Horizontal categories with flowing wave animations
- **ROM Scanning**: Automatic detection of game files from configured ROM directories
- **Emulator Integration**: Launch games through detected emulators (RetroArch, Dolphin, etc.)
- **Gamepad Support**: Full gamepad input mapping for XMB navigation and emulator control
- **Wayland Session**: Modern Wayland compositor (cage) for reliable fullscreen kiosk operation
- **Auto-Login**: Seamless boot-to-kiosk experience with SDDM auto-login
- **Return Mechanism**: Desktop shortcut to cleanly exit games and return to launcher
- **Settings Persistence**: User preferences saved to `arqa-settings.json`
- **Offline Operation**: Bundled React libraries, no internet dependency required

### 🔮 Planned Features

- Multi-user profiles with save state management
- Cloud sync for game saves (optional)
- Shader presets and per-game configurations
- Voice control integration
- Custom theme editor

## Getting Started

### Prerequisites

- **For Building Locally**:
  - Linux system with `podman` or Docker
  - `just` task runner
  - `npm` (for `just build-dev` with local ArqaLauncher)
  - 50+ GB free disk space for image builds

- **For Using ISO**:
  - USB drive (8GB+) for bootable ISO
  - UEFI-capable system
  - 20+ GB disk space for installation

### Quick Build

```bash
# Clone the repository
git clone https://github.com/Arqa-Core/ArqaOS.git
cd ArqaOS

# Build the container image
just build

# Generate ISO from built image
just build-iso

# Or build and test in a VM
just build-qcow2
just _run-vm
```

### Configuration

**System Files** (`system_files/`):
- Edit SDDM theme in `usr/share/sddm/themes/breeze/theme.conf.user`
- Modify Plymouth animation in `usr/share/plymouth/themes/arqa/arqa.script`
- Customize session start in `etc/arqa/session-start.sh`

**Build Arguments**:
```bash
# Pin a specific ArqaLauncher version
just build LAUNCHER_VERSION=v1.2.0

# Use development launcher
just build-dev
```

**ISO Configuration** (`disk_config/`):
- `iso.toml`: Standard GNOME ISO
- `iso-kde.toml`: KDE Plasma variant
- `iso-gnome.toml`: Explicit GNOME variant

## Development

### Project Structure

- **Containerfile**: Main production build
- **Containerfile.dev**: Development build with local launcher injection
- **build.sh**: Runs inside container, installs packages, configures services
- **arqa-autologin-setup.sh**: systemd service that sets up auto-login on first boot
- **arqa-session-start.sh**: Wayland session entry point (sets up cage, SDDM)
- **arqa-return**: Script to cleanly exit emulator and return to launcher

### Common Tasks

```bash
# Check build for syntax errors
just check

# Build image locally (production build with latest launcher release)
just build

# Build image with local ArqaLauncher for testing
just build-dev

# Rebuild specific components
just ostree-rechunk      # Split image layers
just _rootful_load_image # Load image into podman

# Create bootable ISO
just build-iso

# Create QCOW2 disk image for VMs
just build-qcow2

# Run VM with QEMU
just _run-vm
```

### Customization

1. **Launcher UI**: Edit ArqaLauncher repository (separate repo)
   - Modify `renderer/renderer.js` for XMB logic
   - Update `renderer/style.css` for styling
   - Ensure aesthetic contract (#05030c, #8a54ff) is maintained

2. **System Packages**: Edit `build.sh` in `RUN dnf5 install` section

3. **Boot Experience**: Modify Plymouth theme in `system_files/usr/share/plymouth/themes/arqa/`

4. **Session Management**: Edit `system_files/etc/arqa/session-start.sh`

### Environment Variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `LAUNCHER_VERSION` | ArqaLauncher release to fetch | `latest` |
| `IMAGE_NAME` | Container image name | `arqaos` |
| `REPO_ORGANIZATION` | GitHub organization | `Arqa-Core` |
| `BIB_IMAGE` | bootc-image-builder image | `quay.io/centos-bootc/bootc-image-builder:latest` |

## CI/CD Pipeline

### GitHub Actions Workflows

**build.yml** (Triggered on push to `main`)
1. Run `just check` for syntax validation
2. Run `just build` to build container image
3. Run `just ostree-rechunk` to split layers
4. Push to GHCR with labels and metadata
5. Sign image with cosign

**build-iso.yml** (Triggered after build.yml or manual dispatch)
1. Download built container image from GHCR
2. Run bootc-image-builder with `disk_config/iso.toml`
3. Upload ISO as GitHub Actions artifact (30-day retention)
4. Create GitHub release for tagged commits

### Manual Dispatch

Trigger workflows manually:
```bash
# Via GitHub CLI
gh workflow run build.yml
gh workflow run build-iso.yml --ref main
```

## Troubleshooting

### Build Fails with Exit Code 141

**Cause**: SIGPIPE during large file extraction (ArqaLauncher is 99MB+)

**Solution**: Simplified extraction logic in Containerfile handles this automatically. If it persists:
1. Check ArqaLauncher release has linux asset
2. Try pinning a specific version: `just build LAUNCHER_VERSION=v1.0.0`
3. Increase container memory: `podman build --memory 4g`

### ISO Fails to Boot

**Cause**: EFI/UEFI compatibility or partition issues

**Solution**:
1. Verify ISO is written correctly: `sha256sum` check against artifact
2. Ensure UEFI is enabled in BIOS
3. Try writing ISO with `dd` if USB tool fails: `dd if=arqaos-*.iso of=/dev/sdX bs=4M status=progress`

### Launcher Not Starting

**Cause**: Missing dependencies or incorrect file permissions

**Solution**:
1. Check arqa-launcher binary exists: `podman run --rm ghcr.io/Arqa-Core/arqaos:latest ls -lh /app/arqa-launcher`
2. Verify session starts: Check `/var/log/arqa-session.log` (if logging enabled)
3. Test launcher locally: `just build-dev && podman run --rm -it <image> /app/arqa-launcher`

## License

Apache License 2.0 – See [LICENSE](LICENSE) file

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Maintain aesthetic contract (#05030c, #8a54ff)
4. Test locally with `just build-dev`
5. Submit pull request with clear description

## Related Projects

- **[ArqaLauncher](https://github.com/Arqa-Core/ArqaLauncher)**: The Electron-based XMB launcher (separate repo)
- **[ublue-os/bazzite](https://github.com/ublue-os/bazzite)**: Base Fedora Atomic image
- **[bootc](https://github.com/containers/bootc)**: OCI container to OS image tool

## Support

- **Issues**: Report bugs on [GitHub Issues](https://github.com/Arqa-Core/ArqaOS/issues)
- **Discussions**: Join community discussion on [GitHub Discussions](https://github.com/Arqa-Core/ArqaOS/discussions)
- **Releases**: Pre-built images available at [GHCR](https://ghcr.io/Arqa-Core/arqaos)

---

**Made with ♪ by the Arqa-Core team** | [GitHub Organization](https://github.com/Arqa-Core)
