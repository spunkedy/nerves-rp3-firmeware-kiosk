# nerves-rp3-firmeware-kiosk

A Nerves system for the Raspberry Pi 3 (B / B+ / Zero 2 W) that adds a
fullscreen web-kiosk userspace to the stock `nerves_system_rpi3` portable
image. Built specifically for the official Raspberry Pi 7" DSI touchscreen
plus a USB speaker; pointed at a local Phoenix endpoint by default.

## What's added on top of stock `nerves_system_rpi3`

| Component | Purpose |
| --- | --- |
| **Cog** + **WPE WebKit** | The fullscreen kiosk browser. WebKit-based, ~150 MB rootfs cost. |
| **Weston** + **Wayland** | Minimal display server — no X11. |
| **Mesa3D** with **VC4** Gallium driver | OpenGL ES + EGL on the Pi 3's VideoCore IV. |
| **`vc4-kms-v3d`** dtoverlay (in `config.txt`) | Switches the kernel from legacy fbdev to modern DRM/KMS. |
| **`libinput`** | Touchscreen + USB HID input handling. |
| **GStreamer Base + `LIB_OPENGL`** | HTML5 video playback in WPE. |
| **Liberation fonts** | Default UI font. |
| **`CONFIG_SND_USB_AUDIO=m`** (kernel) | Plug-and-play USB audio devices (USB speaker, USB headset, etc.). |
| **ALSA utils** | `aplay`, `amixer` available on the device. |

The legacy `rpi-userland` (VC4 closed userland) is **removed** — Mesa3D
provides libegl/libgles via the modern KMS path, and they conflict.

## Hardware target

- **Raspberry Pi 3 Model B / B+ / Zero 2 W** (BCM2837)
- **Official Raspberry Pi 7" DSI Touchscreen** — driver and backlight overlays already loaded by stock rpi3 (`rpi-ft5406` + `rpi-backlight`)
- USB speaker / keyboard / mouse — work via `snd-usb-audio` and standard HID

## Using this system in your firmware project

In your firmware app's `mix.exs`:

```elixir
defp deps do
  # ...
  target_deps(@target)
end

defp target_deps(:rpi3_kiosk) do
  [
    {:nerves_rp3_firmeware_kiosk,
     github: "spunkedy/nerves-rp3-firmeware-kiosk",
     tag: "v0.1.0",
     runtime: false,
     targets: :rpi3_kiosk}
  ]
end
```

Build:

```sh
MIX_TARGET=rpi3_kiosk mix deps.get
MIX_TARGET=rpi3_kiosk MIX_ENV=prod mix firmware
MIX_TARGET=rpi3_kiosk MIX_ENV=prod mix burn   # or fwup directly
```

The CI workflow in this repo publishes a prebuilt rootfs tarball to GitHub
Releases on every tag push, so consumers don't have to compile Buildroot
locally — `mix deps.get` just downloads the prebuilt.

## Running the kiosk browser at boot

This system **provides Cog and Weston binaries** but does **not auto-launch
them**. Start them from your firmware app's supervision tree (e.g. via
`MuonTrap.Daemon`) so the BEAM supervises the OS processes:

```elixir
# In your firmware app's supervision tree:
children = [
  Supervisor.child_spec(
    {MuonTrap.Daemon, ["/usr/bin/weston", ["--backend=drm-backend.so", "--tty=1", "--idle-time=0"],
     [env: [{"XDG_RUNTIME_DIR", "/run/user/0"}, {"WAYLAND_DISPLAY", "wayland-0"}]]]},
    id: :weston, restart: :permanent),
  Supervisor.child_spec(
    {MuonTrap.Daemon, ["/usr/bin/cog", ["--platform=wl", "http://127.0.0.1:4000"],
     [env: [{"XDG_RUNTIME_DIR", "/run/user/0"}, {"WAYLAND_DISPLAY", "wayland-0"}],
      delay_to_start: 2_000]]},
    id: :cog, restart: :permanent)
]
```

## Building locally

Building this system from source requires a Linux build host (Buildroot
doesn't run on macOS or Windows natively). On a Mac you'd need Docker or
a Linux VM. The included GitHub Actions workflow does this automatically
on every push — **prefer the prebuilt artifact** over local builds.

If you do need to build locally on Linux:

```sh
sudo apt-get install -y build-essential autoconf automake libtool \
  libssl-dev libncurses-dev pkg-config wget cpio file rsync \
  python3 unzip bc squashfs-tools curl ca-certificates git xz-utils
mix deps.get
mix compile
```

Expect 1–3 hours for the first build. WPE WebKit alone takes 60–90 minutes.

## Provenance

This is a fork of [`nerves-project/nerves_system_rpi3`][upstream] v2.0.2
(stock portable system) with kiosk-specific additions modeled after
[`nerves-web-kiosk/kiosk_system_rpi4`][rpi4_kiosk].

[upstream]: https://github.com/nerves-project/nerves_system_rpi3
[rpi4_kiosk]: https://github.com/nerves-web-kiosk/kiosk_system_rpi4

## License

Apache-2.0 — see `LICENSE`. Buildroot-built rootfs components retain their
upstream licenses (mostly GPL-2/LGPL-2 for the kernel and userspace libs).
