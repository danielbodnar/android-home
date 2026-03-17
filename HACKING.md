# HACKING.md — Pushing the Boundaries

> Technical deep-dive on turning Android into a legitimate Linux development
> hypervisor. What works, what's hacky, and what's coming.

## The Architecture You're Actually Running

```
Hardware (Snapdragon/Tensor SoC)
  └─ EL2: KVM hypervisor (built into Android kernel)
      └─ crosvm (Chrome OS Virtual Machine Monitor)
          └─ Debian aarch64 VM
              ├─ virtio-net   → network (NAT through Android)
              ├─ virtio-blk   → disk (resizable in Terminal settings)
              ├─ virtio-input  → HID events (keyboard/mouse/touch)
              ├─ virtio-gpu    → VirGL (GPU-accelerated rendering)
              ├─ virtio-snd    → audio (in development)
              └─ virtio-vsock  → host↔guest communication
```

This is a **real hypervisor** (KVM), not a container or proot hack. The VM runs
its own kernel. You get actual process isolation, memory protection, and
(eventually) near-native performance.

## Bluetooth Keyboard + Mouse: The Full Story

### Why It Just Works™

Android pairs with your BT HID devices at the OS level. The Terminal app's
crosvm instance configures `virtio-input` devices that mirror the Android input
stack. From the guest VM's perspective, these appear as standard evdev devices.

Verify inside the VM:

```bash
# List input devices
cat /proc/bus/input/devices

# Watch raw events (install evtest first)
sudo apt install evtest
sudo evtest
```

You should see devices like:
- `virtio_input` (keyboard)
- `virtio_input` (mouse/pointer)

### Troubleshooting Input

If keyboard/mouse don't work in Weston:

1. **Check Weston's libinput backend** — run `weston --log=/tmp/weston.log` and
   look for `libinput: configuring device` messages
2. **Permissions** — ensure your user is in the `input` group:
   `sudo usermod -aG input bodnar`
3. **Multiple seat issue** — Weston may not see devices on non-default seats.
   Check `loginctl list-seats` and `loginctl seat-status`

### Input Latency

The path is: `BT radio → Android HID stack → crosvm virtio-input → guest kernel
→ evdev → libinput → Weston → app`. Expect 10-30ms additional latency over
native. For coding this is imperceptible. For gaming, noticeable.

## GPU Acceleration: VirGL and gfxstream

### Current State (March 2026)

- **Android 16 stable**: Weston + VirGL works on Pixel devices
- **GPU toggle**: Available in Terminal app settings (varies by build)
- **Performance**: Good enough for terminal compositing, text editors, light GUI
- **NOT good enough for**: 3D-heavy apps, GPU compute, Vulkan

### Enabling GPU Acceleration

```bash
# Method 1: Terminal app settings (if available)
# Settings → System → Developer options → Linux development environment
# Look for "Hardware acceleration" or "GPU" toggle

# Method 2: Check if VirGL is already active
glxinfo | grep "OpenGL renderer"
# ✓ Good: "virgl" or "Venus" or "gfxstream"
# ✗ Bad:  "llvmpipe" (CPU software rendering)

# Method 3: Force GPU in Weston
# Edit ~/.config/weston.ini, ensure [core] does NOT have use-pixman=true
```

### What VirGL Gives You

VirGL translates OpenGL calls from the guest into Vulkan/GL calls on the host
GPU (Adreno on Snapdragon, Mali on Tensor). This means:

- Weston compositing is smooth (60fps)
- GTK4/Qt6 apps render properly
- Ghostty's OpenGL renderer works
- Neovide's Skia/OpenGL pipeline works
- Basic OpenGL 3.x/ES 3.x apps work

### What It Doesn't Give You

- Vulkan passthrough (not yet)
- CUDA/OpenCL compute
- Direct GPU memory mapping
- > OpenGL 4.x features

## Neovide as a Floating Window

This is one of the more satisfying hacks. Weston's default desktop-shell
supports floating windows natively. Neovide launches as a regular Wayland
client and appears as a floating, draggable, resizable window.

```bash
# Inside Weston, from a foot terminal:
neovide

# With specific file:
neovide ~/project/src/main.rs

# Maximize it (Weston keybind):
# Super+F or double-click titlebar
```

### Neovide Wayland Tips

```bash
# Force Wayland backend (should auto-detect, but just in case)
WINIT_UNIX_BACKEND=wayland neovide

# If fonts look wrong, set in ~/.config/neovide/config.toml:
# [font]
# normal = ["JetBrainsMono Nerd Font Mono"]
# size = 14.0
```

### If Neovide Won't Launch (No GPU)

Neovide **requires** OpenGL. If VirGL isn't working:

1. Use `nvim` in `foot` terminal instead (zero GPU requirement)
2. Or use `nvim` inside `ghostty` (if Ghostty works with its software fallback)
3. Check `LIBGL_ALWAYS_SOFTWARE=1 neovide` as last resort (very slow)

## Turning Android Into a "Hypervisor"

### The Desktop Convergence Dream

The end state looks like this:

```
Android Phone/Tablet
  ├─ USB-C hub → external monitor + power
  ├─ Bluetooth → keyboard + mouse
  ├─ Terminal app → Display activity → Weston
  │   ├─ foot/ghostty (terminal)
  │   │   └─ zellij → nushell → nvim/claude/opencode
  │   ├─ neovide (floating window)
  │   └─ firefox-esr (web browser)
  └─ Android apps still running in background
```

### What's Actually Viable Today (March 2026)

| Feature | Status | Notes |
|---------|--------|-------|
| CLI dev (nvim, zellij, etc.) | ✅ Solid | Terminal-only mode works great |
| Bluetooth keyboard/mouse | ✅ Works | Auto-forwarded via virtio-input |
| Wayland GUI (Weston) | ✅ Works | Android 16+ with Display activity |
| GPU acceleration | ⚠️ Varies | Pixel devices best, others hit-or-miss |
| Ghostty | ⚠️ Needs GPU | Falls back to foot terminal |
| Neovide floating window | ⚠️ Needs GPU | Beautiful when it works |
| External monitor | ⚠️ Partial | Depends on Android desktop mode |
| Audio | ❌ WIP | virtio-snd still in development |
| USB device passthrough | ❌ No | crosvm doesn't expose this |
| Docker/containers | ❌ No | Nested virtualization not supported |

### The Pragmatic Setup

For daily coding right now, the reliable path is:

1. **Terminal-only mode** (no GUI needed):
   - Open Terminal app → you're in Debian
   - `zellij` gives you splits and tabs
   - `nvim` with LazyVim is your IDE
   - `claude` and `opencode` for AI assistance
   - BT keyboard makes this surprisingly productive

2. **GUI mode when you want it**:
   - Tap Display button → run `weston`
   - `foot` terminal always works (no GPU needed)
   - Multiple floating foot windows = poor man's tiling WM
   - Neovide/Ghostty as luxuries when GPU works

## Advanced Hacks

### SSH Reverse Tunnel (Code From Anywhere)

```bash
# Inside the VM:
sudo apt install openssh-server
sudo systemctl enable ssh

# Forward port in Terminal app settings, or:
# From another device on the same network:
ssh bodnar@<phone-ip> -p <forwarded-port>
```

### Persistent Sessions

The VM state persists across Terminal app restarts. Your Zellij sessions,
running processes, and filesystem all survive. But a phone reboot kills
everything.

```bash
# Auto-start zellij on login (add to ~/.config/nushell/config.nu):
if ($env | get -i ZELLIJ | is-empty) {
    zellij attach --create main
}
```

### Memory Optimization

The VM has limited RAM (typically 2-4 GB depending on device). Optimize:

```bash
# Check available memory
free -h

# Reduce Weston memory usage — disable animations
# In weston.ini: close-animation=none, focus-animation=none

# Use foot instead of Ghostty (much lighter)
# Use nvim instead of Neovide

# Aggressive swap (the VM disk is on flash, so swap isn't terrible)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Thermal Management

Sustained compilation will thermal throttle your phone. Mitigate:

- Remove phone case during heavy work
- Use a phone cooling fan/pad
- Point a desk fan at it
- Avoid charging while compiling (double heat)
- Use `htop` to monitor CPU frequency drops

### Network: Port Forwarding

The Terminal app manages port forwarding. You can also use SSH tunnels:

```bash
# Expose a local dev server (e.g., Vite on port 5173)
# In Terminal app settings: forward port 5173
# Then access from Android browser at localhost:5173
```

## What's Coming

Based on AOSP commits and Android roadmaps:

- **Audio support** (virtio-snd) — expected in Android 16 QPR updates
- **Better GPU** (gfxstream replacing VirGL) — higher performance, Vulkan
- **Camera passthrough** — for video conferencing from the VM
- **Expanded OEM support** — more non-Pixel devices getting AVF
- **Samsung** — still conspicuously absent, but pressure is building
- **External display improvements** — Android desktop mode maturing

## Alpine-Specific Notes

### musl vs glibc Compatibility

Alpine uses musl libc, not glibc. Most of our tools are native Alpine packages
(compiled against musl) so this is transparent. But a few things to know:

```bash
# Claude Code ships as a native binary. If it's glibc-linked, install gcompat:
apk add gcompat

# gcompat provides a glibc shim that lets most glibc binaries run on musl.
# It handles ~95% of cases. For the remaining 5%, use a glibc chroot.

# Check if a binary needs glibc:
file /usr/local/bin/claude
# "dynamically linked, interpreter /lib/ld-linux-aarch64.so.1" → needs gcompat
# "statically linked" or "interpreter /lib/ld-musl-aarch64.so.1" → native, fine
```

### OpenRC vs systemd

Alpine uses OpenRC. Key differences from systemd:

```bash
# Service management
rc-service sshd start         # start a service
rc-service sshd stop          # stop
rc-service sshd restart       # restart
rc-update add sshd default    # enable at boot
rc-update del sshd default    # disable at boot
rc-status                     # show all service status

# No journalctl — logs go to /var/log/messages (syslog)
tail -f /var/log/messages
```

### Package Management (apk)

```bash
# apk is fast. Like, really fast.
apk update                    # refresh index (~1 second)
apk upgrade                   # upgrade all packages
apk add neovim                # install
apk del neovim                # remove
apk search -v nushell         # search with versions
apk info -a neovim            # detailed package info
apk list --installed          # list installed packages

# Alpine edge = rolling release. Pin to stable if you need stability:
# /etc/apk/repositories can mix edge and stable
```

### The Kernel Situation

The crosvm-provided kernel stays the same after takeover. This kernel is built
by Google for the AVF VM and includes virtio drivers. Alpine's userspace doesn't
care — it just needs a Linux kernel with the right features, which the AVF
kernel provides.

```bash
# Verify kernel features:
uname -r
zcat /proc/config.gz | grep VIRTIO    # should show virtio drivers
zcat /proc/config.gz | grep DRM_VIRTIO # GPU support
```

### If the Takeover Goes Wrong

The Terminal app in Android has a "Reset" option in its settings that
re-downloads the stock Debian image. This is your safety net:

1. Settings → System → Developer options → Linux development environment
2. Look for "Reset" or "Restore" option
3. This wipes the VM disk and re-downloads Debian

So there's zero risk in trying the takeover. Worst case, you factory reset the
VM and try again.

## Contributing

Found a trick that works? A workaround for a limitation? Open a PR. This repo
is meant to be a living document of what's actually possible.

## License

MIT
