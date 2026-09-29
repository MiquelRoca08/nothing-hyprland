pragma Singleton
// Interface language. The texts in the code are in English, wrapped in I18n.tr("…"); each other
// language is a dictionary in i18n/<lang>.js (English text → translation; what is missing stays in
// English). Use %1, %2… for values: I18n.tr("%1 min left").arg(n). When one English text needs
// different translations, give it a context: I18n.tr("All", "apps") looks up "All|apps" first.
// The language is the system locale: LANG in /etc/locale.conf, read from the file (watched) so it
// changes at once; Settings → System → Language sets it (scripts/locale.sh). Spanish if es_*.
// tr() reads `lang`, so every binding that calls it is re-evaluated when the language changes.
import Quickshell
import Quickshell.Io
import QtQuick
import "i18n/es.js" as Es

Singleton {
    id: root
    // LANG of /etc/locale.conf; without it, the one the shell was started with
    property string systemLang: ""
    readonly property string lang: (systemLang || Qt.locale().name).startsWith("es") ? "es" : "en"
    // For dates and numbers (toLocaleString)
    readonly property var locale: Qt.locale(lang === "es" ? "es_ES" : "en_GB")
    readonly property var languages: [
        { v: "en", label: "English" },
        { v: "es", label: "Español" },
    ]

    function tr(s, context) {
        if (lang === "es") return (context ? Es.strings[s + "|" + context] : undefined) ?? Es.strings[s] ?? s
        return s
    }
    // Count with singular and plural: I18n.trn(n, "%1 update", "%1 updates")
    function trn(n, one, many) { return tr(n === 1 ? one : many).arg(n) }

    FileView {
        id: localeFile
        path: "/etc/locale.conf"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.systemLang = (text().match(/^LANG=["']?([^"'\n]*)/m) ?? [])[1] ?? ""
        onLoadFailed: root.systemLang = ""
    }
    // localectl replaces the file: reread it too when a Settings terminal finishes (scripts/locale.sh)
    Connections {
        target: ShellState
        function onSettingsChanged() { localeFile.reload() }
    }
}
