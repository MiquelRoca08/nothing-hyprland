pragma Singleton
// MPRIS players and which one is controlled. By default, the one playing (or the
// first); if one is chosen in the panel, it stays while it exists.
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root
    readonly property var players: Mpris.players.values
    property string chosenId: ""        // dbusName of the player chosen by hand
    readonly property var player: players.find(p => p.dbusName === chosenId)
        ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    function choose(p) { chosenId = p ? p.dbusName : "" }

    // Readable app name ("Spotify", "Mozilla Firefox"…)
    function appName(p) {
        return p ? (p.identity || p.desktopEntry || p.dbusName.replace("org.mpris.MediaPlayer2.", "")) : ""
    }

    // 125 → "2:05"
    function formatTime(s) {
        s = Math.max(0, Math.floor(s))
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`
    }
}
