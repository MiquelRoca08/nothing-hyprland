# System: changes, fixes and configuration

A log of what was configured and fixed on this Arch Linux (ROG Zephyrus G14 GA403GM, Hyprland 0.56
with a Lua config) since 23 September 2026: hardware, audio, boot, snapshots and Secure Boot. The
desktop is documented separately: [HYPRLAND.md](HYPRLAND.md), [QUICKSHELL.md](QUICKSHELL.md) and
[WALKER.md](WALKER.md).

Relevant hardware:

- **Screens:** `eDP-1`, built-in, 2880×1800 at 120 Hz, scale 1.8–2. `DP-9`, a 27" AOC Q27G4, 2560×1440 at 180 Hz, scale 1, connected to the NVIDIA GPU.
- **GPUs:** AMD Radeon 880M/890M (integrated, drives the laptop panel) and NVIDIA RTX 5060 (drives the external monitor).
- **Audio:** Realtek ALC285 with two Cirrus CS35L56 amplifiers.

---

## What lives where

| What | Where |
|---|---|
| **Everything above (dotfiles)** | `~/dotfiles/` (https://github.com/MiquelRoca08/nothing-hyprland; each machine's private files in `privado/`, not in git): real files in `home/`, symlinks in `$HOME`; `system/` keeps copies/templates of the files in `/etc`, `/boot`… |
| Hyprland, shell and launcher | See [HYPRLAND.md](HYPRLAND.md), [QUICKSHELL.md](QUICKSHELL.md) and [WALKER.md](WALKER.md) |
| Login | greetd (autologin) + the shell's lock screen on startup — `/etc/greetd/config.toml` |
| Lock / idle | The shell's lock screen ([QUICKSHELL.md](QUICKSHELL.md)), `~/.local/bin/bloquear`, `/etc/pam.d/quickshell-lock`, `~/.config/hypr/hypridle.conf`; `hyprlock.conf` stays as a fallback |
| Screen sharing | The shell's own picker ([QUICKSHELL.md](QUICKSHELL.md)): `~/.config/hypr/xdph.conf` (`custom_picker_binary`) → `~/.local/bin/compartir-pantalla`; if the shell does not answer, `hyprland-share-picker` |
| Boot (logo, no console) | `/usr/local/share/nothing/splash.bmp` (UKI), Limine background, options in `/boot/limine.conf`; Plymouth disabled (`/etc/plymouth/`, `/usr/share/plymouth/themes/nothing/`) |
| Updates and snapshots | `/usr/local/bin/arch-update`, `/etc/snapper/configs/root`, `/etc/default/limine`, `/etc/initcpio/*/btrfs-overlayfs` |
| Audio (speakers and headset mic) | `/etc/modprobe.d/g14-audio.conf` + `/usr/lib/firmware/g14-audio.fw` + `/var/lib/alsa/asound.state` |

---

## System theme (monochrome)

| What | Change |
|---|---|
| Hyprland | Border color from the theme on the active window, grey on inactive ones; 10 px gaps; rounding from Settings |
| Cursor | **Win11-Fluent-Dark** (26 Sep): [Windows 11 Fluent Cursors v2 Dark](https://www.deviantart.com/arteffect10520/art/Windows-11-Fluent-Cursors-v2-Dark-968625759) by Arteffect10520, rounder. It is a Windows package (`.cur`/`.ani`, from 32 to 96–128 px, so it is sharp at scale 2) and DeviantArt requires logging in to download it. **It cannot be redistributed, so it is not in the public repo:** once converted, it is kept in `privado/home/.local/share/icons/Win11-Fluent-Dark/` (7 MB, not in git) and `install.sh` links it when present. Without it, XCursor-Pro-Dark is used (`conf/env.lua` and gsettings pick whichever is there). To convert it: download it by hand and convert it with [win2xcur](https://github.com/quantum5/win2xcur): `python3 -m venv /tmp/w2x && /tmp/w2x/bin/pip install win2xcur && mkdir /tmp/fluent && /tmp/w2x/bin/win2xcurtheme -s -o /tmp/fluent <package>/Regular/Default/Install.inf` (`-s`: Windows-like shadow; the output folder must exist), and copy it to `~/.local/share/icons/Win11-Fluent-Dark/cursors/` with an `index.theme` that inherits from XCursor-Pro-Dark. **The hand (`pointer`) had no 64 px size** (only 32, 48, 96 and 128): on the laptop (scale 2, asks for 64) Hyprland used the 48 one without scaling it and the hand looked 25 % smaller than the arrow. On 27 Sep a 64 px one was added by downscaling the 96 one (area averaging, hotspot 17.2); if the package is converted again, repeat it. The other cursors already have 32, 48, 64 and 96. Package variants: Regular/Small (size) and Default/Classic (only the busy animation changes). XCursor-Pro-Dark ([ful1e5/XCursor-pro](https://github.com/ful1e5/XCursor-pro), the previous one; before that Bibata-Modern-Ice) is downloaded by `install.sh` as the fallback, into `~/.local/share/icons/`; `XCURSOR_THEME`/`HYPRCURSOR_THEME` and size 32 (`XCURSOR_SIZE`/`HYPRCURSOR_SIZE`, previously 24; it is the size they are drawn for, no rescaling) in `conf/env.lua` and gsettings (`cursor-theme`, `cursor-size`) |
| Doto font | `~/.local/share/fonts/doto/` |
| UI font | **JetBrainsMono Nerd Font 11** (27 Sep; previously NotoSans Nerd Font), gsettings `font-name`: the same as the shell and the terminal |
| gsettings | `install.sh` sets the GTK theme, `prefer-dark`, accent, cursor (theme and size) and the UI font |
| Wallpaper | The image (`~/Pictures/Wallpapers/`) **is not in the repo**; if the one in `settings.json` does not exist, the shell shows the dot grid |
| GTK 3/4 | `~/.config/gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` only import `tema.css`, the active theme's colors (generated); theme **`NothingOS`**, accent `slate`, `prefer-dark` (gsettings `org.gnome.desktop.interface`). NothingOS (26 Sep) is adw-gtk3-dark renamed: `~/.local/share/themes/NothingOS/` (in the dotfiles), whose `gtk.css` files import those in `/usr/share/themes/adw-gtk3-dark/`, so it updates with the `adw-gtk-theme` package (verified: GTK 3 and 4 load the same CSS). On a new system: `gsettings set org.gnome.desktop.interface gtk-theme NothingOS` |
| Alacritty | `~/.config/alacritty/alacritty.toml` imports the active theme's colors (`~/.local/share/quickshell/tema/alacritty.toml`, generated). Nothing's: black background, greys with **red accents** (26 Sep): Nothing red cursor, maroon selection, the palette's blue (folders in `ls`, the prompt's directory, accents in many programs) as coral red; pure red is still errors and deletions. Since 27 Sep green, yellow, magenta and cyan have color (muted: sage, amber, mauve and cyan) instead of greys. JetBrainsMono Nerd Font. The Shift+Enter binding is kept |
| Bash prompt | `~/.config/bash/prompt.sh` (27 Sep), loaded from `~/.bashrc` (added by `install.sh`). Two lines: folder with an icon (home or folder), `~` for `$HOME` and, if long, first folder + `…` + the last 3, with the parents in muted coral and the current one in bright bold coral; git branch in mauve with ⇡/⇣ (commits to push/pull), `+` staged, `~` modified, `!` conflicts and `?` untracked; Python environment, background jobs and `✘ code` if the last command failed. The `❯` arrow is green or red depending on the result. `user@host` only over SSH or as root. It also sets the window title and colors `ls`, `grep`, `diff`, `ip` and `man`. **`ls -l`/`-la`/`-lh`/`-lA`** (and `ll`, `la`) use **`eza`** when installed (`sudo pacman -S eza`): permissions letter by letter (r amber, w red, x green, `-` grey), your user in amber and others in grey, root in red, sizes in green, `long-iso` dates in cyan, git status and icons (`EZA_COLORS`). With other options (`-t`, `-S`, `-R`…), redirected or without eza, the usual `ls` |
| fastfetch | `~/.config/fastfetch/config.jsonc`: Arch logo and title in red, labels in coral red (without a config it uses cyan, which is grey in this palette). It carries the default module list: with a config file without `"modules"`, fastfetch only shows the logo |
| Lock screen | Big clock in Doto, date in grey and a rounded password field (formerly hyprlock, now the shell) |

Not themed: app icons, Qt/KDE apps and SDDM's login screen.

## Audio: speakers, headphones and the headset microphone

- **Symptoms:** the speakers sounded as if behind a low-pass filter and the volume keys changed nothing; a wired headset's microphone did not show up.
- **Cause:** kernel 7.2.6 lacks this laptop's quirk (GA403UM, ALC285 codec, SSID `1043:1044`). Without it, the second pair of speakers ("Bass Speaker", pin 0x17) goes to a DAC with no volume and the 3.5 mm jack's microphone pins (0x19, 0x1b) stay unconfigured. It was added upstream in August 2026 (commit 140fe610, «Fix speakers on ASUS ROG Zephyrus G14 GA403UM»), and it is the same as the GA403U's.
- **Solution:** apply that quirk with a driver patch.
  - `/usr/lib/firmware/g14-audio.fw`: for codec `0x10ec0285 0x10431044`, use model `1043:1b13` (GA403U → `ALC285_FIXUP_ASUS_GA403U_HEADSET_MIC`).
  - `/etc/modprobe.d/g14-audio.conf`: `options snd-hda-intel patch=g14-audio.fw,…` (the file only affects the Realtek codec).
  - Check: `journalctl -k -b | grep -E 'Mic=0x19|Mic=0x1b'` and, with a headset, `pactl list sources` shows the «Microphone» port.
  - **Once the kernel includes the quirk**, delete both files.
- **Previous fix, removed:** WirePlumber's `api.alsa.soft-mixer` (software volume) with Master/Speaker/PCM fixed at 100 %. With it, plugging in headphones left the «Headphone» control at 0 and nothing was heard, because PipeWire no longer touched the mixer. With the quirk it is not needed and was removed.
- **Monitor's headphone jack:** output only (audio arrives over DisplayPort, which has no input channel); the headset microphone only works on the laptop's jack.
- `/var/lib/alsa/asound.state` stores the mixer (`sudo alsactl store`); `alsa-restore.service` restores it on boot.

## External monitor brightness (DDC/CI)

- **Package:** `ddcutil`.
- **Module:** `/etc/modules-load.d/i2c-dev.conf` with `i2c-dev`, so it loads on every boot.
- **Permissions:** the user in the `i2c` group (`sudo gpasswd -a $USER i2c`).
- **Monitor:** DDC/CI enabled in its menu.

The brightness itself is handled by the shell: [QUICKSHELL.md](QUICKSHELL.md#brightness-scriptsbrillosh).

## Black login screen (SDDM) → greetd + lock screen

- **Symptom:** on boot the laptop panel stays black; the login is there, but invisible, and the password has to be typed blind.
- **Cause:** SDDM uses X11 (`DisplayServer=x11`), and X11 picked the NVIDIA GPU as primary. The laptop panel is on the AMD one. In `/var/log/Xorg.0.log`, the NVIDIA outputs all showed `disconnected` at boot, so the greeter was drawn on a GPU without visible screens. It was not a theme problem.
- **Failed attempt (reverted):** `/etc/X11/xorg.conf.d/10-amd-primaria.conf`, an `OutputClass` with `PrimaryGPU "yes"` for the AMD GPU. It made things worse: X could not draw on the AMD GPU (`modeset(G0): Failed to create pixmap` in the log) and the greeter stopped accepting the password, so not even a blind login worked. It was removed from a tty with `sudo rm ... && sudo systemctl restart sddm`. **Do not repeat it.**
- **Final solution:** autologin with **greetd** and a lock screen on startup. SDDM and X11 are out of the boot.
  - `/etc/greetd/config.toml` (template in `system/`):
    - `initial_session`: logs in automatically as your user (install.sh fills in the template) with `uwsm start -e -D Hyprland hyprland.desktop`.
    - `default_session`: after logging out, a text login with `agreety`.
  - `~/.config/hypr/conf/autostart.lua`: the first thing it runs is `bloquear`, so the session is locked as soon as the shell loads (if it does not load within 5 s, with hyprlock). If locking failed, Hyprland stays locked (Wayland lock protocol).
  - **26 Sep:** hyprlock was replaced by the shell's lock screen ([QUICKSHELL.md](QUICKSHELL.md)); hyprlock stays installed as a fallback.
  - GNOME keyring: `/etc/pam.d/greetd` starts it (`pam_gnome_keyring.so auto_start`) and `/etc/pam.d/quickshell-lock` (and `/etc/pam.d/hyprlock`, for the fallback) unlocks it with the password (`-auth optional pam_gnome_keyring.so`).
  - SDDM stays installed but disabled. To go back: `sudo systemctl disable greetd && sudo systemctl enable sddm`.
  - If Hyprland does not start: greetd's text login, or `Ctrl+Alt+F3` for a tty.

## 27" monitor (DP-9) without picture after a reboot

It has happened several times, with different causes:

1. **The kernel did not detect it** (23 Sep): `card0-DP-9` showed `disconnected` and the boot log said `nvidia ... Cannot find any crtc or sizes`, i.e. nothing was connected at boot. It was physical (cable, input or the monitor's deep sleep). The monitor config was fine.
2. **Detected, but no picture** (24 Sep): the kernel and Hyprland saw it connected and active (2560×1440 at 180 Hz, with the bar drawn) and Hyprland's log had no errors, but the monitor showed nothing.
   - **Fix:** turn its signal off and on so the link renegotiates:
     ```
     hyprctl dispatch 'hl.dsp.dpms({ action = "disable", monitor = "DP-9" })'
     hyprctl dispatch 'hl.dsp.dpms({ action = "enable", monitor = "DP-9" })'
     ```
     When turned off, the monitor disconnects for a few seconds and comes back by itself; afterwards it showed a picture.
   - **If it happens often:** automate that cycle at login (in `conf/autostart.lua`).
   - **Another suspect:** `monitors.lua` asks for 10-bit color at 180 Hz, a lot of DisplayPort bandwidth. If it causes problems, try 8 bits or 165 Hz.
3. **Plymouth** (28 Sep): with Plymouth enabled the monitor had no picture and Hyprland's log repeated `Cannot commit when a page-flip is awaiting` — see «What happened with Plymouth» below.

Quick diagnosis:

- **Does the kernel see it?** `cat /sys/class/drm/card*-DP-9/status`. If it says `disconnected`, it is something physical.
- **Does Hyprland use it?** `hyprctl monitors`.
- **Hyprland's log:** `$XDG_RUNTIME_DIR/hypr/*/hyprland.log` (look for `DP-9` and `page-flip`).

## Limine: Windows and the Nothing theme

- **Files:** `/boot/limine.conf` and `/boot/EFI/BOOT/limine-nothing.png` (template and image in `system/boot/`). The config goes at the root of the partition and **not** in `/EFI/BOOT/`: Limine tries `/EFI/BOOT/limine.conf` (next to its `.EFI`) first and then the root, but limine-snapper-sync only looks at `$ESP_PATH/limine.conf`. Do not leave any `limine.conf` in `/boot/EFI/BOOT/`, because it would take priority and would not carry the snapshots. Installed by `./install.sh` (module `sistema`), which fills in `@MACHINE_ID@` and `@PARTUUID_RAIZ@` from the machine it runs on.
- **Windows:** on its own EFI partition; the entry (commented out in the template) loads `guid(<PARTUUID>):/EFI/Microsoft/Boot/bootmgfw.efi` — fill in your own PARTUUID (`lsblk -o NAME,PARTUUID,LABEL`).
- **Theme:** a dot grid like the shell's, with a rounded black box and the «NOTHING OS LINUX» dot logo («OS» in red) at the bottom left. The box is 72 px from the edge and the menu text 132 (`term_margin`), with a transparent terminal background (`term_background: ff000000`). The image is made for `2880x1800`; if Limine starts at another resolution, it is stretched.
- **Redoing the image:** the background was made with `magick` (56 px grid, `#303030` dots on `#1a1a1a`, `#000000` box with a `#2e2e2e` border, radius 36); `scripts/logo-arranque.py` draws the logo on top (see «Quiet boot»).
- **No enrolled config hash** (see Secure Boot): `limine.conf` can be edited freely. The `99-limine.hook` hook only copies the `.EFI` files on updates, it does not touch the config.

## Quiet boot (logo; Plymouth disabled)

From the Limine menu to the lock screen not a single console line shows: Limine's menu over a plain background (dot grid and a black box, with no logo, machine name or branding text since 29 Sep), the «NOTHING OS LINUX» logo (dots like Nothing's logo, «OS» in red) when the UKI loads, then black until the lock screen. **Plymouth is disabled** (`plymouth.enable=0`) because it left the NVIDIA monitor without a picture (see below).

- **Logo:** `scripts/logo-arranque.py` (Pillow) draws it with the grid of Nothing's logo (5×5-dot letters; L, U and X drawn in the same style) and writes two files: `system/usr/local/share/nothing/splash.bmp` and `system/usr/share/plymouth/themes/nothing/logo.png`. It only needs to run again if the logo changes.
- **1. Limine:** background `limine-nothing.png` (dot grid, black box and a red dot) and `interface_branding:` empty. Until 29 Sep it had the logo and «ROG ZEPHYRUS G14» at the bottom left and «archlinux» at the top; the `arranque` module of `install.sh` also empties `interface_branding` in an existing `/boot/limine.conf` (which it does not overwrite, because of the snapshots).
- **2. UKI:** systemd-stub shows `/usr/local/share/nothing/splash.bmp` as soon as it loads (`--splash` in `/etc/mkinitcpio.d/linux.preset`; previously the Arch logo, `splash-arch.bmp`). It stays until `amdgpu` changes the display mode.
- **3. Until the lock screen:** black, no messages or cursor (options below). Hyprland draws black (`misc.background_color`) until the shell sets the wallpaper and the lock screen.
- **Kernel options** (on every `cmdline:` of `/boot/limine.conf`, the snapshots' too): `quiet splash loglevel=3 rd.udev.log_level=3 udev.log_level=3 systemd.show_status=false rd.systemd.show_status=false vt.global_cursor_default=0 plymouth.enable=0`. `./install.sh` (module `arranque`) adds the missing ones to `/boot/limine.conf` and fixes the value of those set differently (without removing anything); limine-snapper-sync copies them to new snapshots. `systemd.show_status=false` and not `auto`: with `auto`, systemd prints the status as soon as something is slow («A start job is running…»).
- **Plymouth (kept, unused):** the package stays installed, but without a hook in `/etc/mkinitcpio.conf`, with `plymouth.enable=0` (which also disables its systemd services) and with `plymouth-start.service` masked (`install.sh`), so that a typo on the kernel line cannot bring it back: without both, `plymouth-start.service` would start it anyway after mounting the root. To try it again: `sudo systemctl unmask plymouth-start.service`. The `nothing` theme (`/usr/share/plymouth/themes/nothing/`) and `/etc/plymouth/plymouthd.conf` (`DeviceScale=1`) are kept in case it is tried again.

### What happened with Plymouth (28 Sep)

- **Boot stuck on the logo** («A start job is running for Hold until boot process finishes up … / no limit»): a drop-in made greetd close Plymouth (`Conflicts=plymouth-quit.service`, like GDM), but `greetd.service` is `After=plymouth-quit-wait.service`, which waits for Plymouth to close: they waited for each other.
- **Logo twice as big:** Plymouth applies HiDPI scaling (×2 at 2880×1800); `DeviceScale=1` was not enough at the end of the boot and `plymouth.force-scale=1` was needed.
- **27" monitor (DP-9, NVIDIA) without a picture:** the kernel and Hyprland saw it connected at 2560×1440@180, but Hyprland's log repeated `drm: Cannot commit when a page-flip is awaiting` on DP-9, and neither the DPMS cycle nor dropping `--retain-splash` fixed it. Booting with `plymouth.enable=0` brought the picture back: Plymouth also draws on the NVIDIA output (`nvidia-drm` loads after the root is mounted and Plymouth picks it up) and leaves it in a state Hyprland does not recover from. Fix: Plymouth disabled. `install.sh` removes the test drop-ins from `/etc` (`greetd.service.d/plymouth.conf`, `plymouth-quit.service.d/retener.conf`).
- **It came back through a typo** (28 Sep, later): DP-9 without a picture again, with the same `page-flip` messages. `/boot/limine.conf` had `plymouth.enable)0` (with `)`), the kernel did not understand it and Plymouth started (`journalctl -b | grep -i plymouth`: «Starting Show Plymouth Boot Screen»). Fix: the typo corrected in `/boot/limine.conf` and `plymouth-start.service` masked, so as not to depend on the kernel option alone. Check with `cat /proc/cmdline` and `systemctl is-enabled plymouth-start.service` (`masked`).
- **To try it again**, Plymouth would have to be kept off the NVIDIA GPU (laptop panel only), and the 27" monitor checked after every boot.

### If something fails

- **See the messages:** in Limine, `E` on the entry and remove `quiet` from the `cmdline` line (for that boot only, `F10`), or `journalctl -b`.
- **If it does not boot:** boot a snapshot and fix the real root by mounting it separately (changes inside the snapshot are lost on shutdown): `dev=$(findmnt -no SOURCE /home | sed 's/\[.*//'); sudo mount -o subvolid=5 "$dev" /mnt`, change the files in `/mnt/@/…` and `sudo umount /mnt`.

## Snapshots (snapper + Limine)

- **How it works:** `arch-update` (`/usr/local/bin/arch-update`, copy in `system/usr/local/bin/`) creates a «Pre-update …» snapshot with `snapper -c root` before updating. It is the only thing that creates snapshots (no snap-pac, no timeline snapshots) and only one is kept: creating the new one deletes the previous one (`NUMBER_LIMIT=1`, `NUMBER_MIN_AGE=0`, `snapper cleanup number`). It is there to go back to the state before the last update if something goes wrong.
- **`arch-update`** (follows Omarchy 4.0's process): run as `sudo arch-update` (`-y` without questions, `--no-aur` repos only, `--no-snapshot`, `--dry-run`, `--menu`). The questions are **buttons** (27 Sep): ←/→, Tab or h/l to choose, Enter or space to accept, `s`/`n` as shortcuts and Escape (or `q`) for «no»; anything typed before the question is discarded. «Update?» defaults to yes; orphans and reboot, to no. From the menu it runs with **`--menu`**: when it ends (fine, with errors or interrupted) the terminal does not close by itself, it waits for the «Cerrar» (close) button or, if a reboot is needed, «Reiniciar ahora» / «Más tarde» (reboot now / later); if it is cancelled at the start, it closes. In both cases it exits with 200, which is what the launcher checks (`~/.config/quickshell/scripts/actualizar.sh`, used by the walker menu and Settings → Updates) so it does not wait again; with any other exit code the launcher waits for a key itself. Steps: question → 10 GiB free → `paccache -rk2` (before the snapshot, because the cache is inside it) → snapshot `create -c number` + `cleanup number` (if it fails, **it aborts**) → `archlinux-keyring` → `pacman -Syu` → `yay -Sua --cleanafter` as the user if there are AUR packages → orphans (asks; with `-y` it does not remove them) → checks that the UKI was built and is signed (hooks in `pacman.log` + `sbctl verify`; if not, it warns **not to reboot**) → restarts walker/elephant and `qs` → offers a reboot if the kernel or Hyprland changed. Everything runs inside `systemd-inhibit` and the output goes to `/var/log/arch-update.log`. Needs `pacman-contrib`. Firmware (`fwupd`) is separate.
- **Fix:** an earlier version of the script created the snapshot without `-c number` and without `cleanup`, so they piled up (and with them, Limine entries). If that happened, delete them with `sudo snapper -c root delete <n>` (`snapper -c root list`). `limine-snapper-sync` (AUR) adds each snapshot to Limine's «Snapshots» group, with a copy of the UKI of that moment.
- **btrfs layout:** root in `@` and home in `@home` (your `/etc/fstab`, not managed by the repo, and `rootflags=subvol=/@` in `limine.conf`); snapper stores in `@/.snapshots`. The root used to be the whole volume, without subvolumes; `scripts/snapshots-setup.sh` does the migration in phases (`fase1` → reboot → `fase2` → `yay -S limine-snapper-sync` → `fase3`, and `limpiar` (clean up) once everything works). It detects the disk's UUIDs by itself.
- **Booting a snapshot:** they are read-only; the initramfs hook `btrfs-overlayfs` (`/etc/initcpio/`, added to `HOOKS` in `/etc/mkinitcpio.conf`) mounts a RAM overlay on top, so the system boots normally and changes are lost on shutdown. To go back to that state permanently, limine-snapper-sync offers a restore.
- **`limine.conf`:** limine-snapper-sync rewrites `/boot/limine.conf` to add the snapshots; the dotfiles copy is the template (theme and main entry). The format it needs: `/+Arch Linux` with `comment: machine-id=…`, the UKI in `//linux` and `//Snapshots`. The tool's config: `/etc/default/limine`.
- **If phase 1 is interrupted** (it happened the first time: `rm --one-file-system` does not delete nested subvolumes, which show as empty directories in the copy), nothing breaks: the old root is still the one that boots, and running `fase1` again deletes the half-made `@`/`@home` and redoes them.
- **Incident with `limpiar` (24 Sep 2026):** the first version looked for the old root's nested subvolumes with `btrfs subvolume list -o "$TOP/<dir>"`. For a normal directory (`etc`, `usr`…) that lists the children of the subvolume containing it, which is the top level: `@`, `@home`… came out, and it deleted `@home` while mounted. Symptoms: `findmnt /home` showed `[/@home//deleted]`, everything written to `/home` ended up as 0-byte files (that is how `yay -S walker` failed), though what was already written could still be read. Recovery: with the top level mounted on `/mnt/btrfs-raiz`, a new `@home`, a copy of all of `~` from the still-live mount (verified with `diff` and `git fsck`) and a reboot. What was written between the deletion (21:53) and the copy was lost: parts of the Firefox profile, `~/.cargo/registry`, elephant's cache and some Steam and Discord files (all regenerated). **Fix:** it now lists every subvolume once, keeps those that hang from the old root by path, shows them before asking for «BORRAR», and aborts if any is `@`, `@home`, inside them or mounted. `@` was most likely saved only because it contains the `.snapshots` subvolume and a subvolume with others inside cannot be deleted (a deduction, not confirmed in the log).
- **«Rescate» entry removed (24 Sep 2026)** by hand from `/boot/limine.conf` (`sudo sed -i '/^# Temporal: arranca la raíz antigua/,$d' /boot/limine.conf`): after the incident the old root may be half deleted and not boot. The old root (~3 GB) is still in the top level; `limpiar` would delete it (it no longer finds the entry to remove, which is fine).
- **Space in /boot:** 1 GiB and the UKI weighs ~170 MiB. Each distinct UKI version used by the snapshots takes space (identical ones are shared); above 85 % the oldest entries are removed.

## Secure Boot (sbctl)

- **Own keys** created with `sbctl create-keys` and enrolled with `sbctl enroll-keys -m` (`-m` adds Microsoft's: Windows and the NVIDIA GPU's option ROMs keep booting).
- **Signed** (`sbctl sign -s`, kept in sbctl's database): `/boot/EFI/BOOT/BOOTX64.EFI` and `BOOTIA32.EFI` (Limine) and `/boot/EFI/Linux/arch-linux.efi` (UKI). They are re-signed automatically: the UKI by sbctl's mkinitcpio post-hook and Limine by `zz-sbctl.hook`, which runs after `99-limine.hook`. The UKI copies limine-snapper-sync keeps for each snapshot come from the already signed UKI.
- **UKI without an embedded cmdline** (`--no-cmdline` in `/etc/mkinitcpio.d/linux.preset`, no `/etc/kernel/cmdline`): with Secure Boot, a UKI with `.cmdline` ignores Limine's, and the snapshot and «Rescate» entries would boot the normal system. This way the command line always comes from `limine.conf`.
- **No config hash in Limine** (`limine enroll-config`): limine-snapper-sync rewrites `limine.conf` on every snapshot and the hash would stop matching.
- **27 Sep: Limine showed up unsigned** (`BOOTX64.EFI` and `BOOTIA32.EFI`) on the first real run of `arch-update`, with no packages updated: something rewrote it without going through `zz-sbctl.hook` (suspect: limine-snapper-sync or limine-entry-tool when creating the snapshot, to be confirmed). Since then `arch-update`, if it sees unsigned files, runs `sbctl sign-all` (it only signs those already in sbctl's database) and only reports the failure if they are still unsigned.
- **Check:** `sudo sbctl verify` (all ✓ except `vmlinuz-linux`, which is not used to boot) and `sbctl status`.
- **If something does not boot:** turn Secure Boot off in the BIOS and everything boots as before.

## Face recognition (Howdy)

On the shell's lock screen and in `sudo` (not on greetd's login, polkit or hyprlock). How the lock
screen uses it: [QUICKSHELL.md](QUICKSHELL.md).

- **Camera:** the G14 has an IR camera («ASUS IR camera», `/dev/video2` and `video3`; the regular one is `video0`). It gives 360×360 grey at 15 fps. **The IR emitter turns on by itself**, on alternate frames (one lit, one dark), so `linux-enable-ir-emitter` is not needed; Howdy skips the dark frames (`dark_threshold`).
- **Package:** `howdy-git` from the AUR (Howdy 3: native PAM module `pam_howdy.so`). It depends on `python-dlib` (AUR, compiled) and `python-opencv`. Dropped: `howdy` 2.6.1 (Python PAM, old) and `howdy-beta-git` (abandoned). The package adds `polkit-agent-helper@.service.d/10-howdy.conf` (lets the polkit helper use the camera; it does not enable the face in polkit).
- **`/etc/howdy/config.ini`** (copy in `system/`): four changes over the stock file, marked `(dotfiles)`: `device_path` by fixed path (`/dev/v4l/by-path/pci-0000:65:00.4-usb-0:1:1.2-video-index0`, the G14's IR camera, because the `/dev/videoN` number can change — on another machine, set yours), `detection_notice = true` (to show the «looking for your face» message), `no_confirmation = true` and `dark_threshold = 95`. The latter because Howdy discards a frame if more than that % of pixels fall in the darkest 1/8 of the histogram: with a dark background, the lit frames give 80–87 % and the dark ones 100 %, so with the stock 60 `howdy add` failed with «All frames were too dark». With 95 the lit ones get in and the dark ones stay out. `abort_if_lid_closed = true` (stock): with the lid closed it goes straight to the password.
- **PAM:** `/etc/pam.d/quickshell-lock-cara` = `-auth sufficient pam_howdy.so` + `include quickshell-lock`. The leading dash makes the line be ignored instead of failing if `pam_howdy.so` is missing.
- **`sudo`** (26 Sep, tested: with the face the log says `pam_howdy: Login approved`; covering the camera, it asks for the password and gets in): `/etc/pam.d/sudo` (copy in `system/`) has `-auth sufficient pam_howdy.so` before `include system-auth`. It prints «Attempting facial authentication», looks for the face for up to 4 s and, if it does not recognize it («Failure, timeout reached»), asks for the password as usual: **the password still works**, you just wait for the prompt. Anything typed **before** `[sudo] password` appears is shown on screen (the terminal still has echo on). With the lid closed or over SSH it goes straight to the password. The file belongs to the `sudo` package: if an update brings a new one, it arrives as `/etc/pam.d/sudo.pacnew` and the line has to be added again.
  - **`workaround` stays `off`:** it is global (cannot be chosen per service). With `input` or `native`, Howdy asks for the password while looking for the face, but when it recognizes it, it has to cancel that prompt: `input` presses Enter with a virtual keyboard (`/dev/uinput`), which the lock screen (without root) cannot use and would keep waiting for Enter; `native` kills the thread forcibly and Howdy itself marks it as unstable (it can leave the terminal without echo).
  - **Security:** with the face in `sudo`, any program running as your user can get root without you typing anything while you are in front of the camera (only the IR LED gives it away). With a password, you would see the prompt. To remove it: delete the `pam_howdy.so` line from `/etc/pam.d/sudo`.
- **Keyring:** with autologin, the GNOME keyring is unlocked with the password of the first unlock. A face unlock gives it no password, so the lock screen only uses the face once the keyring is unlocked.
- **Enrolled face:** `sudo howdy add` (can be repeated, with and without glasses, with different light); `sudo howdy list`, `sudo howdy remove <id>`, `sudo howdy test` (a window with what the camera sees).

## Other

- **Opening nvim (or other terminal apps) from Nautilus:** apps with `Terminal=true` are launched with `xdg-terminal-exec`; without it, GLib only tries terminals from its own list (gnome-terminal, xterm…) and Alacritty is not there. Fix: `sudo pacman -S xdg-terminal-exec` + `~/.config/xdg-terminals.list` with `Alacritty.desktop` (in the dotfiles).
- **Nautilus: «There was an error launching the app… ServiceUnknown: The name is not activatable»** (28 Sep) when pressing the open-externally button (↗) in a disk's or USB drive's properties. That button opens «Disks» over D-Bus (`org.gnome.DiskUtility`) and it was not installed. Fix: `sudo pacman -S gnome-disk-utility` (now in `paquetes.txt`, with `dosfstools` and `exfatprogs` for formatting FAT32/exFAT); nothing needs restarting.
- **Default browser: Firefox** (26 Sep). After installing chromium (for web apps) it started opening links and PDFs: there was no saved preference and, without one, xdg takes the first one in `/usr/share/applications/mimeinfo.cache`, which is alphabetical (`chromium` before `firefox`). Fix: `xdg-settings set default-web-browser firefox.desktop` + `xdg-mime default firefox.desktop text/html application/xhtml+xml application/pdf x-scheme-handler/http x-scheme-handler/https`, which store it in `~/.config/mimeapps.list` (outside the repo: xdg-mime rewrites it and would break a symlink). Web apps still use chromium: `webapp` only uses the default browser if it is Chromium-based.

## Pending / to check

- **27" monitor:** confirm after a reboot that it has a picture with `plymouth-start.service` masked. If it loses the picture again without Plymouth involved, automate the DPMS cycle (see «27" monitor»).
- **Snapshots after the `limpiar` incident:** Limine lists snapshot 4 («Pre-update 2026-09-24 21:51:32»), but it still has to be confirmed that it exists with `sudo snapper -c root list` and that `/etc/snapper/configs/root` still has `NUMBER_LIMIT=1` and `NUMBER_MIN_AGE=0`.
- **Old root in the top level (~3 GB):** state unknown after the incident. Delete it with `sudo scripts/snapshots-setup.sh limpiar` (fixed version) to get the space back; check the list it shows before typing «BORRAR».
- **New `arch-update`:** installed, not yet tried with a full real update.
