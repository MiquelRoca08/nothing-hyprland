//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
// Custom shell: floating bar, notifications, OSD, power menu and lock screen.
// Entry point: Hyprland starts it with `qs` (conf/autostart.lua).
import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    // Background and bar on each monitor
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    // Rounded corners of each screen
    Variants {
        model: Quickshell.screens
        ScreenCorners {}
    }

    Notifications {}
    Osd {}
    SharePicker {}
    PowerMenu {}
    SettingsWindow {}
    LockScreen {}

    // IPC for the system menu (~/.local/bin/menu):
    //   qs ipc call notifications dnd        → toggles Do Not Disturb
    //   qs ipc call wallpaper set <path>     → image background
    //   qs ipc call wallpaper dots           → dot background
    IpcHandler {
        target: "notifications"
        function dnd(): bool { Config.options.dnd = !Config.options.dnd; return Config.options.dnd }
    }
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { Config.options.wallpaperPath = path; Config.options.wallpaperMode = "image" }
        function dots(): void { Config.options.wallpaperMode = "dots" }
    }
}
