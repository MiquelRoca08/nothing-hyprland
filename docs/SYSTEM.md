# System

The system side of these dotfiles: where things live, look and feel, login and lock, boot (Limine,
UKI, quiet boot), snapshots and updates, Secure Boot and face unlock. The desktop is documented in
[HYPRLAND.md](HYPRLAND.md), [QUICKSHELL.md](QUICKSHELL.md) and [WALKER.md](WALKER.md). Parts that
are specific to the laptop these dotfiles were built on are in [HARDWARE.md](HARDWARE.md); past
fixes and experiments are in [CHANGELOG.md](CHANGELOG.md).

## What lives where

| What | Where |
|---|---|
| **The dotfiles** | The repo checkout (e.g. `~/dotfiles`): real files in `home/`, symlinked into `$HOME` (list in `links.txt`); `system/` keeps copies/templates of files in `/etc`, `/boot`, `/usr`…; your own files that are not in git go in `private/` |
| Hyprland, shell and launcher | [HYPRLAND.md](HYPRLAND.md), [QUICKSHELL.md](QUICKSHELL.md), [WALKER.md](WALKER.md) |
| Login | greetd (autologin) + the shell's lock screen on startup: `/etc/greetd/config.toml` |
| Lock / idle | The shell's lock screen ([QUICKSHELL.md](QUICKSHELL.md#lock-screen)), `~/.local/bin/lock-screen`, `/etc/pam.d/quickshell-lock` and `quickshell-lock-face`, `~/.config/hypr/hypridle.conf` (generated); `hyprlock.conf` is the fallback |
| Screen sharing | The shell's own picker: `~/.config/hypr/xdph.conf` (`custom_picker_binary`) → `~/.local/bin/share-picker`; `hyprland-share-picker` if the shell does not answer |
| Boot (logo, no console text) | `/boot/limine.conf`, `/boot/EFI/BOOT/limine-nothing.png`, `/usr/local/share/nothing/splash.bmp` (UKI), `/etc/mkinitcpio.conf`, `/etc/mkinitcpio.d/linux.preset`; Plymouth disabled (`/etc/plymouth/`, `/usr/share/plymouth/themes/nothing/`) |
| Updates and snapshots | `/usr/local/bin/arch-update`, `/etc/snapper/configs/root`, `/etc/default/limine`, `/etc/initcpio/*/btrfs-overlayfs` |
| Face unlock | `/etc/howdy/config.ini`, `/etc/pam.d/sudo`, `/etc/pam.d/quickshell-lock-face` |
| External monitor brightness | `/etc/modules-load.d/i2c-dev.conf`, the `i2c` group |
| Laptop-specific audio fix | `/etc/modprobe.d/g14-audio.conf`, `/usr/lib/firmware/g14-audio.fw` ([HARDWARE.md](HARDWARE.md#audio-speakers-and-headset-microphone)) |

### Templates and machine data

`system/` files that need machine data are templates: the `system` module of `./install.sh` fills
in `@USER@`, `@HOME@`, `@MACHINE_ID@` and `@ROOT_PARTUUID@` from the machine it runs on.
`/etc/fstab` is not managed. `home/.config/hypr/xdph.conf` is generated from
`xdph.conf.template` by the `appearance` module.

To change a system file, edit the copy in `system/` and install it with `./install.sh system boot`
(`boot` rebuilds the initramfs when the `system` module changed something that goes into it) or
`sudo install -Dm644 system/<path> /<path>`. A change made only in `/` is overwritten by the next
install.

## Look and feel

The whole desktop is monochrome (black, greys and white) with a red accent, and one theme recolors
everything: the shell, Alacritty, walker, GTK 3/4 apps and Hyprland's borders (Settings →
Personalization → Themes; see [QUICKSHELL.md](QUICKSHELL.md#themes)).

| What | How |
|---|---|
| Hyprland | Theme-coloured border on the active window, grey on inactive ones; gaps and rounding from Settings |
| GTK 3/4 | Theme **`NothingOS`** (`~/.local/share/themes/NothingOS/`, adw-gtk3-dark renamed: its `gtk.css` imports `/usr/share/themes/adw-gtk3-dark/`, so it updates with `adw-gtk-theme`), `prefer-dark`, accent `slate`. `~/.config/gtk-{3,4}.0/gtk.css` only import `theme.css`, the active theme's colours (generated) |
| gsettings | The `appearance` module sets the GTK theme, `color-scheme`, accent, cursor theme and size, and the UI font |
| Fonts | UI, shell and terminal: **JetBrainsMono Nerd Font** (11). Clock and big numbers: [Doto](https://fonts.google.com/specimen/Doto) (`~/.local/share/fonts/doto/`, OFL). Change the defaults in Settings → Personalization → Fonts |
| Alacritty | `~/.config/alacritty/alacritty.toml` imports the theme's colours (`~/.local/share/quickshell/theme/alacritty.toml`, generated). With the Nothing theme: black background, greys, red cursor and accents (the palette's blue is coral red, so folders and the prompt's directory are reddish), pure red only for errors, and muted sage/amber/mauve/cyan. Shift+Enter is bound |
| Bash prompt | `~/.config/bash/prompt.sh`, loaded from `~/.bashrc` (line added by the `appearance` module). See below |
| fastfetch | `~/.config/fastfetch/config.jsonc`: Arch logo in red and labels in coral. It carries the full module list, because a config without `"modules"` shows only the logo |
| Wallpaper | A dot grid drawn by the shell, or an image from `~/Pictures/Wallpapers/` (not in the repo); if the saved image is missing, the dot grid comes back |
| Lock screen | Big Doto clock, grey date, rounded password field |

Not themed: app icons and Qt/KDE apps.

### Cursor

- **Default: XCursor-Pro-Dark** ([ful1e5/XCursor-pro](https://github.com/ful1e5/XCursor-pro)),
  downloaded into `~/.local/share/icons/` by the `appearance` module. Size 32 (`XCURSOR_SIZE` /
  `HYPRCURSOR_SIZE` in `conf/env.lua` and gsettings): the size the theme is drawn for.
- **Optional: Win11-Fluent-Dark**
  ([Windows 11 Fluent Cursors v2 Dark](https://www.deviantart.com/arteffect10520/art/Windows-11-Fluent-Cursors-v2-Dark-968625759)
  by Arteffect10520). It cannot be redistributed, so it is not in the repo: put the converted theme
  in `private/home/.local/share/icons/Win11-Fluent-Dark/` and the `links` module links it.
  `conf/env.lua` and gsettings use it when present. To convert the Windows package with
  [win2xcur](https://github.com/quantum5/win2xcur):
  ```sh
  python3 -m venv /tmp/w2x && /tmp/w2x/bin/pip install win2xcur
  mkdir /tmp/fluent && /tmp/w2x/bin/win2xcurtheme -s -o /tmp/fluent <package>/Regular/Default/Install.inf
  ```
  (`-s` adds a Windows-like shadow; the output folder must exist). Put the result in `cursors/`
  next to an `index.theme` that inherits from XCursor-Pro-Dark. The package's hand (`pointer`) has
  no 64 px size, which scale 2 asks for, so it looks smaller than the arrow: make a 64 px one by
  downscaling the 96 px one.

### Bash prompt

Two lines: the folder with an icon (`~` for `$HOME`; long paths shortened to the first folder, `…`
and the last three), the git branch with ahead/behind (⇡/⇣), staged `+`, modified `~`, conflicts
`!` and untracked `?`; Python environment, background jobs and `✘ code` if the last command failed.
The `❯` arrow is green or red depending on the result. `user@host` only shows over SSH or as root.
It also sets the window title and colours `ls`, `grep`, `diff`, `ip` and `man`. `ls -l` / `-la` /
`-lh` / `-lA` (and `ll`, `la`) use **eza** when installed (permissions letter by letter, owner,
sizes, ISO dates, git status and icons); other options or redirected output use the plain `ls`.

## Login: greetd autologin + lock screen

There is no graphical display manager. **greetd** logs your user in automatically and Hyprland's
first command locks the session with the shell's lock screen, so the lock screen *is* the login.

- `/etc/greetd/config.toml` (template in `system/`): `initial_session` runs
  `/usr/local/bin/autologin-session` as your user, which starts `uwsm start -e -D Hyprland
  hyprland.desktop` **only if the dotfiles' config is in place** (`hyprland.lua`, `autostart.lua`
  running `lock-screen`, and `lock-screen` itself). Otherwise, e.g. if the repo folder was deleted
  and the links are broken, it exits and greetd shows the password login: an unlocked session is
  never opened. After logging out, `default_session` is a text login (`agreety`).
- `conf/autostart.lua` runs `lock-screen` first. It locks with the shell and, if the shell does not
  answer within 5 s, with hyprlock. If locking fails, Hyprland stays locked (Wayland lock protocol).
- **GNOME keyring:** `/etc/pam.d/greetd` starts it (`pam_gnome_keyring.so auto_start`) and
  `/etc/pam.d/quickshell-lock` (and `/etc/pam.d/hyprlock`) unlocks it with your password on the
  first unlock.
- The `login` module disables SDDM if it is enabled and enables greetd. To go back:
  `sudo systemctl disable greetd && sudo systemctl enable sddm` (or `./install.sh uninstall`).
- **Why not SDDM:** it runs on X11, and on hybrid-GPU laptops X11 can pick a GPU without a visible
  screen ([HARDWARE.md](HARDWARE.md#hybrid-graphics-amd-igpu--nvidia-dgpu)).
- If Hyprland does not start: greetd's text login, or `Ctrl+Alt+F3` for a tty.

## Limine

- **Files:** `/boot/limine.conf` and `/boot/EFI/BOOT/limine-nothing.png` (template and image in
  `system/boot/`). The config goes at the **root of the ESP**, not in `/EFI/BOOT/`: Limine tries
  `/EFI/BOOT/limine.conf` first, but limine-snapper-sync only updates `$ESP_PATH/limine.conf`. Do
  not leave a `limine.conf` in `/boot/EFI/BOOT/`: it would take priority and have no snapshots.
- The `system` module installs the template (filling in `@MACHINE_ID@` and `@ROOT_PARTUUID@`) only
  while `/boot/limine.conf` has no snapshots yet; after that, limine-snapper-sync owns the file and
  the `boot` module only adds missing kernel options. To change it later, edit both
  `/boot/limine.conf` and the template.
- The main entry boots the UKI with `root=PARTUUID=… rootflags=subvol=/@ rootfstype=btrfs`.
- **Windows** (optional): an entry commented out in the template loads
  `guid(<PARTUUID>):/EFI/Microsoft/Boot/bootmgfw.efi`; fill in the PARTUUID of Windows' EFI
  partition (`lsblk -o NAME,PARTUUID,LABEL`).
- **Theme:** the shell's dot grid with a rounded black box; menu text inside the box
  (`term_margin`), transparent terminal background, no branding text (`interface_branding:` empty).
  The image is drawn for 2880×1800 and stretched at other resolutions. It was made with `magick`
  (56 px grid, `#303030` dots on `#1a1a1a`, a `#000000` box with a `#2e2e2e` border, radius 36).
- **No enrolled config hash** (`limine enroll-config`): limine-snapper-sync rewrites the file on
  every snapshot, so a hash would stop matching. `limine.conf` can be edited freely; the
  `99-limine.hook` pacman hook only copies the `.EFI` files.

## Quiet boot

From the Limine menu to the lock screen no console text shows: the Limine menu, then the
dot-matrix «NOTHING OS LINUX» logo while the UKI loads, then black until the lock screen.

- **Logo:** `scripts/boot-logo.py` (Pillow) draws it with Nothing's 5×5 dot letters and writes
  `system/usr/local/share/nothing/splash.bmp` and `system/usr/share/plymouth/themes/nothing/logo.png`.
  Run it again only if the logo changes.
- **UKI splash:** systemd-stub shows `splash.bmp` as soon as the UKI loads (`--splash` in
  `/etc/mkinitcpio.d/linux.preset`), until the GPU driver changes the display mode.
- **Until the lock screen:** black; Hyprland draws black (`misc.background_color`) until the shell
  draws the wallpaper and the lock.
- **Kernel options** on every `cmdline:` of `/boot/limine.conf` (snapshots included):
  `quiet splash loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=false
  rd.systemd.show_status=false vt.global_cursor_default=0 plymouth.enable=0`. The `boot` module
  adds missing ones and fixes different values without removing anything; limine-snapper-sync
  copies them to new snapshots. `systemd.show_status=false` rather than `auto`, because `auto`
  prints status as soon as a unit is slow ("A start job is running…").
- **Plymouth is disabled:** installed but with no mkinitcpio hook, `plymouth.enable=0`, and
  `plymouth-start.service` masked, so a typo on the kernel line cannot bring it back (without the
  mask, `plymouth-start.service` would start it after the root is mounted). It left the external
  monitor black on the reference laptop's NVIDIA GPU
  ([HARDWARE.md](HARDWARE.md#hybrid-graphics-amd-igpu--nvidia-dgpu)). The `nothing` theme and
  `/etc/plymouth/plymouthd.conf` (`DeviceScale=1`) are kept. To try it on your hardware: unmask
  `plymouth-start.service`, remove `plymouth.enable=0`, add the `plymouth` hook, add
  `plymouth.force-scale=1` on HiDPI panels (otherwise the logo is drawn ×2), and run
  `sudo mkinitcpio -P`. Test without rebooting:
  `sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth quit`.

### If the boot fails

- **See the messages:** in Limine, press `E` on the entry and remove `quiet` from `cmdline`
  (`F10` boots it once), or read `journalctl -b -1`. `Esc` during the logo also shows them.
- **It does not boot at all:** boot a snapshot from Limine's "Snapshots" group and fix the real
  root by mounting the top level (changes inside a booted snapshot are lost on shutdown):
  ```sh
  dev=$(findmnt -no SOURCE /home | sed 's/\[.*//'); sudo mount -o subvolid=5 "$dev" /mnt
  # edit files under /mnt/@/…
  sudo umount /mnt
  ```
- **Secure Boot errors:** turn Secure Boot off in the firmware settings; everything boots as before.

## Snapshots and updates

- **One snapshot, before each update.** `arch-update` (`/usr/local/bin/arch-update`) creates a
  "Pre-update …" snapshot with `snapper -c root` before updating. Nothing else creates snapshots (no
  snap-pac, no timeline) and only one is kept (`NUMBER_LIMIT=1`, `NUMBER_MIN_AGE=0`,
  `snapper cleanup number`): the state right before the last update, to go back to if it breaks.
  Settings → Updates can also take one without updating (`scripts/snapshot.sh`).
- **limine-snapper-sync** (AUR) adds each snapshot to Limine's "Snapshots" group with a copy of that
  moment's UKI. Its config: `/etc/default/limine`. The format it needs in `limine.conf`:
  `/+Arch Linux` with `comment: machine-id=…`, the UKI in `//linux` and a `//Snapshots` group.
- **Booting a snapshot:** snapshots are read-only; the `btrfs-overlayfs` initramfs hook
  (`/etc/initcpio/`, in `HOOKS` of `/etc/mkinitcpio.conf`) mounts a RAM overlay on top, so the
  system boots normally and changes are lost on shutdown. To go back permanently, use
  limine-snapper-sync's restore.
- **btrfs layout:** root in `@`, home in `@home` (your `/etc/fstab`), snapshots in
  `@/.snapshots`.
- **Space in /boot:** the ESP should be about 1 GiB; the UKI is ~170 MiB and each distinct UKI kept
  by a snapshot takes space (identical ones are shared). Above 85 % the oldest entries are removed.

### Setting up snapshots on an existing btrfs root

If your root is a plain btrfs volume without subvolumes, `scripts/snapshots-setup.sh` migrates it
to `@` / `@home` and sets up snapper and limine-snapper-sync, in phases (it detects the disk's
UUIDs by itself):

```sh
sudo scripts/snapshots-setup.sh phase1    # creates @ and @home, initramfs with overlay, Limine → reboot
sudo scripts/snapshots-setup.sh phase2    # (now booted from @) snapper, Limine config, arch-update
yay -S limine-snapper-sync                # as your user
sudo scripts/snapshots-setup.sh phase3    # enables the sync and creates the first snapshot
sudo scripts/snapshots-setup.sh cleanup   # once everything works: deletes the old root
```

- Until `cleanup`, the old root stays intact and Limine has a «Rescue (old root)» entry that boots
  it. Phase 1 keeps a copy of an existing `/boot/EFI/BOOT/limine.conf` as
  `limine.conf.before-snapshots`, and mounts the top level at `/mnt/btrfs-top`.
- If phase 1 is interrupted, nothing breaks (the old root still boots); running it again redoes
  the half-made subvolumes.
- `cleanup` lists the subvolumes it will delete and asks you to type `DELETE`; it refuses to touch
  `@`, `@home`, anything inside them or anything mounted, and removes the Rescue entry.
- The old Spanish subcommand names still work as aliases.

### `arch-update`

Based on Omarchy 4.0's update process. Run it as `sudo arch-update`; the menu and Settings →
Updates run it for you in a floating terminal.

| Option | Effect |
|---|---|
| `-y` | No questions (orphans are not removed) |
| `--no-aur` | Without the AUR |
| `--no-flatpak` | Without Flatpak |
| `--no-snapshot` | No snapshot |
| `--dry-run` | Shows what it would do |
| `--menu` | As launched from the menu: when done it waits for a **Close** button (or **Reboot now** / **Later**) and exits with 200, so the launcher (`scripts/update.sh`) knows not to wait again |

Steps: confirm → check 10 GiB free → `paccache -rk2` (before the snapshot, since the cache is
inside it) → snapshot (if it fails, **it aborts**) → `archlinux-keyring` → `pacman -Syu` →
`yay -Sua` as your user if there are AUR packages → Flatpak (`flatpak update` of the system
installation as root and of your `--user` one as you, then `--unused` runtimes are removed) →
orphans (asks) → checks that the UKI was
rebuilt and everything is signed (if not, it warns **not to reboot**; unsigned files already known
to sbctl are re-signed with `sbctl sign-all`) → restarts walker, elephant and the shell → offers a
reboot if the kernel or Hyprland changed. It runs inside `systemd-inhibit`, logs to
`/var/log/arch-update.log`, and speaks the shell's language. Questions are buttons: ←/→, Tab or
h/l to choose, Enter to accept, y/n as shortcuts, Escape for "no". Firmware (`fwupdmgr`) is
separate (menu → Update → Firmware). Needs `pacman-contrib`.

## Secure Boot (sbctl)

- Own keys: `sbctl create-keys`, enrolled with `sbctl enroll-keys -m` (`-m` keeps Microsoft's keys,
  needed for Windows and for GPU option ROMs).
- **Signed** (`sbctl sign -s`, so they are in sbctl's database): `/boot/EFI/BOOT/BOOTX64.EFI` and
  `BOOTIA32.EFI` (Limine) and `/boot/EFI/Linux/arch-linux.efi` (UKI). They are re-signed
  automatically: the UKI by sbctl's mkinitcpio post-hook, Limine by `zz-sbctl.hook` (after
  `99-limine.hook`). Snapshot UKIs are copies of the signed one.
- **UKI without an embedded cmdline** (`--no-cmdline` in `linux.preset`, no `/etc/kernel/cmdline`):
  with Secure Boot, a UKI with a `.cmdline` section ignores Limine's, and the snapshot entries would
  boot the normal system. So the command line always comes from `limine.conf`.
- Check: `sudo sbctl verify` (everything ✓ except `vmlinuz-linux`, which is not booted directly)
  and `sbctl status`.
- If something does not boot, disable Secure Boot in the firmware settings.

## Face recognition (Howdy)

Face unlock works on the shell's lock screen and in `sudo` (not in greetd's login, polkit or
hyprlock). It is optional and needs an IR camera. How the lock screen uses it:
[QUICKSHELL.md](QUICKSHELL.md#lock-screen).

- **Install:** `yay -S howdy-git` (Howdy 3, native PAM module `pam_howdy.so`; builds `python-dlib`,
  slow), then `sudo howdy add` (repeat with and without glasses, in different light). Also
  `sudo howdy list`, `sudo howdy remove <id>`, `sudo howdy test`. Settings → Personalization →
  QuickShell → Lock screen can install it and enroll your face too.
- **`/etc/howdy/config.ini`** (copy in `system/`), changes over the stock file marked
  `(dotfiles)`: `device_path` (a stable `/dev/v4l/by-path/…` path: **set your camera's**),
  `detection_notice = true`, `no_confirmation = true` and `dark_threshold = 95` (tuned for an IR
  emitter that lights alternate frames; see [HARDWARE.md](HARDWARE.md#ir-camera-howdy)).
  `abort_if_lid_closed = true` (stock) skips it with the lid closed.
- **Lock screen PAM:** `/etc/pam.d/quickshell-lock-face` = `-auth sufficient pam_howdy.so` +
  `include quickshell-lock`. The leading dash ignores the line if Howdy is not installed.
- **`sudo`:** `/etc/pam.d/sudo` (copy in `system/`) has `-auth sufficient pam_howdy.so` before
  `include system-auth`. It looks for your face for up to 4 s and then asks for the password as
  usual. Anything typed before the `[sudo] password` prompt is echoed. The file belongs to the
  `sudo` package: if an update brings a `/etc/pam.d/sudo.pacnew`, add the line again.
  - `workaround` stays `off`: it is global. `input` presses Enter through `/dev/uinput`, which the
    lock screen cannot use; `native` kills the prompt thread and Howdy itself marks it unstable.
  - **Security:** with face unlock in `sudo`, any program running as you can get root while you sit
    in front of the camera, without you typing anything (only the IR LED gives it away). To opt
    out, delete the `pam_howdy.so` line from `/etc/pam.d/sudo`.
- **Keyring:** with autologin, the GNOME keyring is unlocked by the password of the first unlock;
  a face unlock gives it no password, so the lock screen only offers the face once the keyring is
  unlocked.

## External monitor brightness (DDC/CI)

- Package `ddcutil`; module `i2c-dev` loaded on boot (`/etc/modules-load.d/i2c-dev.conf`); your
  user in the `i2c` group (the `services` module adds it; log in again afterwards); DDC/CI enabled
  in the monitor's own menu.
- The shell handles the rest: [QUICKSHELL.md](QUICKSHELL.md#brightness).

## Other

- **Terminal apps from Nautilus** (nvim, etc.): apps with `Terminal=true` are launched with
  `xdg-terminal-exec`, configured by `~/.config/xdg-terminals.list` (`Alacritty.desktop`). Without
  it, GLib only tries its own list of terminals.
- **Disks from Nautilus:** a drive's "open externally" button calls GNOME Disks over D-Bus
  (`org.gnome.DiskUtility`), so `gnome-disk-utility` is installed (with `dosfstools` and
  `exfatprogs` for FAT32/exFAT).
- **Default browser:** with chromium installed for web apps and no saved preference, xdg picks the
  first entry of `mimeinfo.cache` alphabetically (chromium). Set yours explicitly:
  ```sh
  xdg-settings set default-web-browser firefox.desktop
  xdg-mime default firefox.desktop text/html application/xhtml+xml application/pdf x-scheme-handler/http x-scheme-handler/https
  ```
  This is stored in `~/.config/mimeapps.list`, which is deliberately not in the repo (xdg-mime
  rewrites it and would break a symlink). Web apps use chromium unless your default browser is
  Chromium-based.
- **Spotify** runs as native Wayland (`~/.config/spotify-launcher.conf`, `--ozone-platform=wayland`).
