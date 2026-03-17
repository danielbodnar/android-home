# Android Linux Dev Environment

> Turn your Android phone/tablet into a full Linux development workstation.
> Alpine Linux via live OS takeover, Wayland GUI, Bluetooth peripherals, modern CLI tooling.

## Why Alpine Over Debian?

The Android Terminal app ships a Debian VM. We replace it with Alpine because:

| | Debian (stock) | Alpine (takeover) |
|---|---|---|
| **Base footprint** | ~800MB RAM | ~120MB RAM |
| **Root filesystem** | ~2-3GB | ~500MB |
| **Package manager** | apt (slow) | apk (10x faster) |
| **libc** | glibc (heavy) | musl (50% less memory) |
| **Init** | systemd (3-5s boot) | OpenRC (<1s boot) |
| **nushell** | not packaged | `apk add nushell` ✓ |
| **neovim** | outdated | edge has latest ✓ |
| **zellij** | not packaged | `apk add zellij` ✓ |
| **yazi** | not packaged | `apk add yazi` ✓ |

In a VM with 2-4GB RAM, freeing 680MB by switching to musl/Alpine is the
difference between a sluggish environment and a usable one.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Android OS (Host)                                   │
│  ├─ Bluetooth HID (keyboard + mouse) ← just pair   │
│  ├─ Android Virtualization Framework (AVF / KVM)    │
│  │   └─ crosvm (VM monitor)                        │
│  └─ Terminal App (Display button → Wayland surface) │
│       ↕ virtio-input / virtio-gpu / virtio-net      │
├─────────────────────────────────────────────────────┤
│ Alpine Linux VM (Guest) — aarch64, musl, OpenRC     │
│  ├─ Weston (Wayland) + XWayland                     │
│  ├─ foot / Ghostty (terminals)                      │
│  ├─ Neovide (floating Neovim GUI)                   │
│  ├─ Nushell + Zellij + Yazi                         │
│  ├─ Neovim + LazyVim                                │
│  ├─ mise → Bun + Node                               │
│  └─ Claude Code + OpenCode                          │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

- **Device**: Pixel (Android 15+) or compatible Android 16+ device with AVF
- **Bluetooth**: Keyboard + mouse paired to Android before launching Terminal
- **Storage**: Resize VM disk to 16+ GB in Terminal app settings
- **Enable**: Settings → System → Developer options → Linux development environment

## Quick Start

From inside the Android Linux Terminal (the Debian VM):

```bash
sudo apt update
sudo apt install -y git curl

git clone https://github.com/danielbodnar/android-home.git
cd android-home

# The takeover: Debian → Alpine (20-30 min)
sudo ./takeover.sh
```

The script bootstraps a complete Alpine system, then gives you three options:

- **Option A (safe)**: Run `alpine-switch`, close Terminal app, reopen → Alpine
- **Option B (yolo)**: `sudo ./takeover.sh --pivot` — live pivot_root, zero-downtime swap
- **Option C (test first)**: `chroot /alpine-new su - bodnar` — explore before committing

## The Takeover Technique

The kernel is provided by crosvm and stays the same regardless of userspace.
Alpine runs on any Linux kernel. So the technique is:

1. Download Alpine's `apk.static` (statically linked, zero dependencies)
2. Bootstrap a full Alpine rootfs into `/alpine-new` using `apk.static --initdb`
3. Install all packages via chroot: nushell, neovim, zellij, yazi, weston, foot...
4. Configure user, networking, services, dotfiles
5. Either replace the filesystem (safe) or `pivot_root` (live swap)
6. On next Terminal app launch, crosvm boots same kernel → finds Alpine init → done

## What Gets Installed

**CLI tools** (all native Alpine aarch64 packages — no building from source):
nushell, neovim, zellij, yazi, ripgrep, fd, bat, fzf, zoxide, eza, sd, delta

**Dev tooling**:
mise, Bun, Node.js 22, Claude Code, OpenCode, LazyVim, git, build-base

**GUI / Wayland**:
Weston compositor, foot terminal, XWayland, mesa (VirGL), Adwaita icons

**Fonts**: JetBrains Mono Nerd Font

## Bluetooth Input

Pair your BT keyboard + mouse to **Android**. That's it. The input path is:

```
BT HID → Android → crosvm/virtio-input → Alpine kernel → libinput → Weston → apps
```

No configuration needed inside the VM. The on-screen keyboard does NOT work in
GUI mode, so BT peripherals are essential for the full desktop experience.

## GUI Mode

1. Tap the **Display** button (top-right) in the Terminal app
2. Run `weston` in the display view
3. Click the terminal icon in Weston's bottom panel → foot launches
4. Or run `neovide` for a floating Neovim GUI window

## Also Included

- `setup.sh` — Alternative Debian-only setup (no takeover, just installs tools)
- `scripts/install-gui.sh` — GUI-only install for adding Wayland support later
- `scripts/install-fonts.sh` — Standalone Nerd Font installer
- `HACKING.md` — Deep technical notes on GPU accel, thermal, memory, SSH, etc.
- `config/` — Dotfiles for Weston, foot, Zellij, Nushell, Ghostty (Tokyo Night)

## File Structure

```
android-linux-dev/
├── README.md              # This file
├── takeover.sh            # ★ Alpine takeover (recommended)
├── setup.sh               # Debian-only alternative
├── HACKING.md             # Deep technical notes
├── LICENSE                # MIT
├── .editorconfig
├── .gitignore
├── config/
│   ├── weston.ini
│   ├── foot.ini
│   ├── ghostty.conf
│   ├── zellij/config.kdl
│   └── nushell/{env,config}.nu
└── scripts/
    ├── install-gui.sh
    └── install-fonts.sh
```

## License

MIT
