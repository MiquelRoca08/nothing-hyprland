pragma Singleton
// Interface language. The texts in the code are in English, wrapped in I18n.tr("…"); each other
// language is a dictionary in i18n/<lang>.js (English text → translation; what is missing stays in
// English). Use %1, %2… for values: I18n.tr("%1 min left").arg(n). When one English text needs
// different translations, give it a context: I18n.tr("All", "apps") looks up "All|apps" first. Settings → System → Language
// chooses it (Config.options.language): "auto" follows the system locale ($LANG).
// tr() reads `lang`, so every binding that calls it is re-evaluated when the language changes.
import Quickshell
import QtQuick
import "i18n/es.js" as Es

Singleton {
    readonly property string setting: Config.options.language
    readonly property string lang: setting === "en" || setting === "es" ? setting
                                   : (Qt.locale().name.startsWith("es") ? "es" : "en")
    // For dates and numbers (toLocaleString)
    readonly property var locale: Qt.locale(lang === "es" ? "es_ES" : "en_GB")
    readonly property var languages: [
        { v: "auto", label: "Automatic" },
        { v: "en", label: "English" },
        { v: "es", label: "Español" },
    ]

    function tr(s, context) {
        if (lang === "es") return (context ? Es.strings[s + "|" + context] : undefined) ?? Es.strings[s] ?? s
        return s
    }
    // Count with singular and plural: I18n.trn(n, "%1 update", "%1 updates")
    function trn(n, one, many) { return tr(n === 1 ? one : many).arg(n) }
}
