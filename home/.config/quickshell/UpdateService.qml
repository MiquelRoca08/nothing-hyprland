pragma Singleton
// Pending updates, for Settings → Home and Updates: repositories
// (checkupdates, from pacman-contrib), AUR (yay -Qua) and Flatpak, with the list of packages and versions. -1: checking · -2: cannot
// be known (the tool is missing). check(false) does not repeat if it checked less than 10 min ago.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int repo: -1
    property int aur: -1
    property int flatpak: -1
    // What will be updated: [{ name, from, to }]
    property var repoList: []
    property var aurList: []
    property var flatpakList: []
    property double checkedAt: 0
    readonly property bool checking: repoProc.running || aurProc.running || flatpakProc.running
    // Total of what is known (not counting the -2)
    readonly property int total: Math.max(repo, 0) + Math.max(aur, 0) + Math.max(flatpak, 0)

    function check(force) {
        if (checking || (!force && checkedAt && Date.now() - checkedAt < 600000)) return
        repo = -1; aur = -1; flatpak = -1
        repoList = []; aurList = []; flatpakList = []
        checkedAt = Date.now()
        repoProc.running = true; aurProc.running = true; flatpakProc.running = true
    }

    // «package version -> new» (checkupdates and yay -Qua) → [{ name, from, to }]
    function parse(text) {
        return text.split("\n").map(l => l.trim().split(/\s+/)).filter(p => p.length >= 4 && p[2] === "->")
                   .map(p => ({ name: p[0], from: p[1], to: p[3] }))
    }

    Process {
        id: repoProc
        command: ["sh", "-c", "command -v checkupdates >/dev/null || exit 3; checkupdates 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.repoList = root.parse(text); root.repo = root.repoList.length } }
        onExited: code => { if (code === 3) root.repo = -2 }
    }
    Process {
        id: aurProc
        command: ["sh", "-c", "command -v yay >/dev/null || exit 3; yay -Qua 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: { root.aurList = root.parse(text); root.aur = root.aurList.length } }
        onExited: code => { if (code === 3) root.aur = -2 }
    }
    // Flatpak does not give the installed version: only the new one
    Process {
        id: flatpakProc
        command: ["sh", "-c", "command -v flatpak >/dev/null || exit 3; flatpak remote-ls --updates --columns=name,application,version 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.flatpakList = text.split("\n").filter(l => l.includes("\t")).map(l => {
                    const p = l.split("\t")
                    return { name: p[0] || p[1], from: "", to: p[2] || "", id: p[1] }
                })
                root.flatpak = root.flatpakList.length
            }
        }
        onExited: code => { if (code === 3) root.flatpak = -2 }
    }
}
