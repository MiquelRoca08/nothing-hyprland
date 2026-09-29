# Hardware notes (ASUS ROG Zephyrus G14 GA403)

These dotfiles were built on an ASUS ROG Zephyrus G14 (GA403, 2024–2025 models). Almost everything
is generic Arch + Hyprland; this page collects the parts that are tied to that laptop, or to
hybrid AMD + NVIDIA laptops in general. **If you have this hardware**, read it to know why things
are set the way they are. **If you do not**, use it as a checklist of what to adjust or skip.

Reference machine: AMD Radeon 880M/890M iGPU (drives the built-in panel) + NVIDIA RTX 50-series
dGPU (drives the external outputs), a 2880×1800 120 Hz panel, Realtek ALC285 audio with two Cirrus
CS35L56 amplifiers, and an IR camera. Look up your own with `lspci -k`, `hyprctl monitors all`,
`aplay -l` and `v4l2-ctl --list-devices`.

## What to adjust on other hardware

| What | Where | On other machines |
|---|---|---|
| Monitor names, modes, scales | `home/.config/hypr/conf/monitors.lua` (not in git) | Created per machine by `./install.sh links` (your previous config, the running session or a fallback rule). On the reference laptop: `eDP-1` (2880×1800 @ 120, scale 1.8) and `DP-9` (2560×1440 @ 180 on the NVIDIA GPU). Adjust it in Settings → Displays |
| "Laptop screen" toggle in the menu | `~/.local/bin/menu` (`laptop-screen`) | Toggles `eDP-1`; change the name if your panel is different |
| ASUS tools | `packages.txt` (`asusctl`, `rog-control-center`), `conf/autostart-local.lua` (yours) | Remove both lines on non-ASUS machines; on the reference laptop `rog-control-center` is autostarted from its own `autostart-local.lua`. Settings → Battery's charge limit uses `asusctl` |
| G14 audio patch | `system/etc/modprobe.d/g14-audio.conf`, `system/usr/lib/firmware/g14-audio.fw` | The patch only matches this codec's IDs, so it is inert elsewhere, but you can delete both files |
| Howdy camera | `system/etc/howdy/config.ini` (`device_path`) | A `/dev/v4l/by-path/…` path of this laptop's IR camera: set yours (`ls /dev/v4l/by-path/`) |
| Limine background | `system/boot/EFI/BOOT/limine-nothing.png` | Drawn for 2880×1800; stretched at other resolutions |
| Personal input rules | `conf/input.lua` | A Logitech M705 rule (flat acceleration, slower scroll) and a CS2 scroll rule; harmless without those devices/apps |
| Autostarted apps | `conf/autostart-local.lua` (not in git) | The repo only starts the desktop itself; your apps (on the reference laptop: `steam`, `rog-control-center`, `discord`) go in this list, imported from your previous config by `./install.sh links` |
| GPU drivers | not in `packages.txt` | Install your GPU's drivers yourself (e.g. `nvidia-open` + `nvidia-utils`) |

## Hybrid graphics (AMD iGPU + NVIDIA dGPU)

- The built-in panel (`eDP-1`) is on the AMD GPU; the external ports are on the NVIDIA GPU, which
  is why the external monitor shows up with a high connector number (`DP-9`).
- **Plymouth is disabled** (`plymouth.enable=0` on every Limine entry, no mkinitcpio hook,
  `plymouth-start.service` masked by the `boot` module). With Plymouth running, the monitor on the
  NVIDIA GPU had no picture after boot and Hyprland's log repeated
  `drm: Cannot commit when a page-flip is awaiting`: `nvidia-drm` loads after the root is mounted,
  Plymouth takes that output too and leaves it in a state Hyprland does not recover from. On a
  single-GPU machine you could re-enable it (see [SYSTEM.md](SYSTEM.md#quiet-boot)); the `nothing`
  Plymouth theme is kept in `system/usr/share/plymouth/themes/nothing/`.
- **No X11 display manager.** SDDM (X11) picked the NVIDIA GPU as primary and drew the login on a
  GPU with no visible outputs, leaving the panel black. The setup uses greetd autologin + the
  shell's lock screen instead, so no display manager ever touches X11.
- **Waking the dGPU.** The bar's system monitor and battery tooltips read the NVIDIA GPU's runtime
  power state from sysfs (which does not wake it) and only call `nvidia-smi` when it is already
  active.
- **walker renderer.** `GSK_RENDERER=ngl` works on both GPUs; `cairo` left rendering artifacts.

## External monitor without picture

If the external monitor stays black after boot:

1. **Does the kernel see it?** `cat /sys/class/drm/card*-DP-*/status`. `disconnected` means
   something physical: cable, input, or the monitor's deep sleep.
2. **Does Hyprland use it?** `hyprctl monitors`.
3. **Is Plymouth running?** `cat /proc/cmdline` (must have `plymouth.enable=0`),
   `systemctl is-enabled plymouth-start.service` (`masked`), and look for `page-flip` in
   `$XDG_RUNTIME_DIR/hypr/*/hyprland.log`.
4. **Connected but black:** cycle its signal so the link renegotiates (the monitor disconnects for a
   few seconds and comes back):
   ```
   hyprctl dispatch 'hl.dsp.dpms({ action = "disable", monitor = "DP-9" })'
   hyprctl dispatch 'hl.dsp.dpms({ action = "enable", monitor = "DP-9" })'
   ```
   If it happens often, add that cycle to `conf/autostart.lua`. 10-bit colour at 180 Hz uses a lot
   of DisplayPort bandwidth: try 8-bit or a lower refresh rate.

## Brightness

- There are two backlights: `amdgpu_bl1` (real) and `nvidia_0` (fake, depending on the GPU mode);
  `brightnessctl` alone picks the wrong one. `scripts/brightness.sh` uses the backlight of the GPU
  the eDP panel is connected to, and adapts if the GPU mode changes.
- External monitors use DDC/CI (see [SYSTEM.md](SYSTEM.md#external-monitor-brightness-ddcci)).

## Audio (speakers and headset microphone)

- **Symptoms without the fix:** the speakers sound muffled (as if low-pass filtered), the volume keys
  change nothing, and a wired headset's microphone does not appear.
- **Cause:** kernels before the upstream fix (added in August 2026, "Fix speakers on ASUS ROG
  Zephyrus G14 GA403UM") lack this model's quirk (ALC285, SSID `1043:1044`). Without it the second
  speaker pair (pin 0x17) goes to a DAC with no volume control and the jack's mic pins (0x19,
  0x1b) stay unconfigured.
- **Fix:** a driver patch applies the GA403U quirk (`ALC285_FIXUP_ASUS_GA403U_HEADSET_MIC`):
  - `/usr/lib/firmware/g14-audio.fw`: for codec `0x10ec0285 0x10431044`, model `1043:1b13`.
  - `/etc/modprobe.d/g14-audio.conf`: `options snd-hda-intel patch=g14-audio.fw,…`.
  - Both need `sudo mkinitcpio -P` and a reboot (the `system` + `boot` modules do it).
  - Check: `journalctl -k -b | grep -E 'Mic=0x19|Mic=0x1b'`; with a headset plugged in,
    `pactl list sources` shows the "Microphone" port.
  - **Once your kernel includes the quirk, delete both files.**
- Do not use WirePlumber's `api.alsa.soft-mixer` as a workaround: with the hardware mixer pinned,
  headphones stay silent.
- A monitor's headphone jack is output only (DisplayPort has no input channel); the headset mic
  only works on the laptop's jack.
- `/var/lib/alsa/asound.state` stores the mixer state (`sudo alsactl store`); `alsa-restore.service`
  restores it on boot. The installer only copies it if it does not exist.

## IR camera (Howdy)

- The G14's IR camera ("ASUS IR camera") gives 360×360 greyscale at 15 fps, with **the IR emitter
  turning on by itself** on alternate frames, so `linux-enable-ir-emitter` is not needed. Howdy
  skips the dark frames with `dark_threshold = 95` (with a dark background, lit frames are 80–87 %
  dark pixels and unlit ones 100 %; the stock 60 fails with "All frames were too dark").
- `device_path` uses the stable `/dev/v4l/by-path/…` name because `/dev/videoN` numbers can change.
- Everything else about Howdy is generic: [SYSTEM.md](SYSTEM.md#face-recognition-howdy).

## Display scaling

- The panel runs at a fractional scale (1.8; 2 also works). Valid scales for 2880×1800 are
  multiples of 1/120 that give an integer logical size (1.8 → 1600×1000; 1.75 does not fit);
  Settings → Displays only offers valid ones.
- XWayland apps (Steam) look right on both monitors with `force_zero_scaling = false`, slightly soft
  on the panel ([HYPRLAND.md](HYPRLAND.md#x11-app-scaling)).
- The Win11-Fluent cursor (optional, from `private/`) needs a 64 px hand cursor for scale 2; see
  [SYSTEM.md](SYSTEM.md#cursor).

## Secure Boot

`sbctl enroll-keys -m` keeps Microsoft's keys: needed for Windows and for the NVIDIA GPU's option
ROMs. Details: [SYSTEM.md](SYSTEM.md#secure-boot-sbctl).
