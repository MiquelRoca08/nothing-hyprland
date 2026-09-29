pragma Singleton
// Desktop theme: background layers, texts and an accent for what is active (selected, on,
// main button) and what is critical. The colors come from the active theme (tc, JSON from scripts/tema.sh);
// without a theme, Nothing's: black, whites and Nothing red. Doto (dot matrix) for
// the clock and large figures. Do not put loose colors in other files: use these.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    // Active theme (Settings → Personalization → Themes; written by scripts/tema.sh aplicar). It is
    // reread when it changes; if there is none, Nothing's (temas/nothing.json)
    property var tc: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.local/share/quickshell/tema/actual.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { const j = JSON.parse(text()); if (j.colors) tc = j.colors } catch (e) {} }
        onLoadFailed: tc = ({})
    }
    // Blacks and greys, from back to front
    readonly property color bg:         tc.bg ?? "#000000"          // window and panel background
    readonly property color bgAlt:      tc.bgAlt ?? "#0a0a0a"       // Settings sidebar
    readonly property color surface:    tc.surface ?? "#141414"     // cards (SettingsGroup)
    readonly property color control:    tc.control ?? "#1e1e1e"     // controls on a card: buttons, chips, fields, tracks
    readonly property color controlHi:  tc.controlHi ?? "#282828"   // control hover
    readonly property color border:     tc.border ?? "#2a2a2a"
    // Whites
    readonly property color fg:         tc.fg ?? "#ffffff"          // main text
    readonly property color fgSoft:     tc.fgSoft ?? "#b3b3b3"      // secondary text that must read well
    readonly property color dim:        tc.dim ?? "#6e6e6e"         // descriptions and hints
    // Reds (in other themes, the theme's accent)
    readonly property color red:        tc.red ?? "#d71921"         // Nothing red: critical
    readonly property color sel:        tc.sel ?? "#d71921"         // active: selected, on, main button
    readonly property color selHi:      tc.selHi ?? "#ee2a33"       // hover of red things
    readonly property color selSoft:    tc.selSoft ?? "#240a0c"     // tinted background (selected row)
    readonly property color selText:    tc.selText ?? "#ffffff"     // text on red
    // Bar accent (workspaces, OSD, power menu)
    readonly property color accent:     tc.accent ?? "#ffffff"
    readonly property color accentText: tc.accentText ?? "#000000"
    readonly property int controlRadius: 8
    readonly property int cardRadius: 14
    // Dot background: the theme's background lightened towards the text according to the tone (grey in Nothing)
    readonly property color wallpaper: Qt.tint(bg, Qt.rgba(fg.r, fg.g, fg.b, Config.options.wallpaperTone / 255))
    readonly property color dot:        tc.dot ?? "#303030"         // background dots

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string displayFont: "Doto"
    readonly property int fontSize: 13

    // "hug": bar attached at the top, full width, with the screen corners
    // rounded right below it (like ii). "float": floating bar with a margin.
    readonly property string barStyle: Config.options.barStyle
    readonly property int barHeight: 36
    readonly property int gap: Config.options.gap          // = Hyprland's gaps_out (synced automatically)
    readonly property int radius: Config.options.radius    // = Hyprland's rounding (synced automatically)
    // Screen corners
    readonly property int screenRadius: Config.options.screenRadius
}
