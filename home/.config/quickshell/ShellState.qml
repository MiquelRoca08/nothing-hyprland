pragma Singleton
// State shared between components.
import Quickshell
import Quickshell.Hyprland
import QtQuick

Singleton {
    property bool powerMenuOpen: false

    // Settings window: settingsPage is the key of a page in Config.settingsTree. It always opens
    // on Home, unless another one is asked for (openSettings(key), IPC `settings open <key>`)
    property bool settingsOpen: false
    property string settingsPage: "home"
    property string _settingsNext: ""
    // Data for the page being opened (e.g. Storage → Installed apps: the app to
    // select). The page reads it and clears it.
    property var settingsArg: null
    // A command launched from Settings has finished (IPC settings changed): pages reload
    signal settingsChanged()
    onSettingsOpenChanged: if (settingsOpen) {
        settingsPage = Config.settingsEntry(_settingsNext || "home").k
        _settingsNext = ""
    }
    // Notification history (in memory; lost when the shell restarts)
    property var notifications: []     // [{ app, summary, body, icon, time }], newest first
    property int unread: 0
    function addNotification(n) {
        notifications = [n].concat(notifications).slice(0, 50)
        unread++
    }
    function removeNotification(i) { notifications = notifications.filter((_, j) => j !== i) }
    function clearNotifications() { notifications = []; unread = 0 }

    function openSettings(page) {
        if (settingsOpen) { if (page) settingsPage = Config.settingsEntry(page).k; return }
        _settingsNext = page || ""
        settingsOpen = true
    }

    // Screen with the focus (for OSD, notifications and the power menu)
    readonly property var focusedScreen:
        Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
}
