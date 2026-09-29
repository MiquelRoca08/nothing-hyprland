// Settings → System → Language: the interface language is the system locale (LANG in
// /etc/locale.conf, read by I18n.qml and i18n/i18n.sh). Choosing one runs scripts/locale.sh in a
// terminal (it asks for the password), which generates the locale if needed and sets it.
import Quickshell
import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: I18n.tr("Language")
    subtitle: I18n.tr("Language of the system and the shell's interface")

    SettingsGroup {
        SettingsRow {
            text: I18n.tr("Language")
            description: I18n.systemLang ? I18n.tr("System locale: %1").arg(I18n.systemLang)
                                         : I18n.tr("No LANG in /etc/locale.conf")
            ChoiceChips {
                value: I18n.lang
                options: I18n.languages
                onChosen: v => {
                    if (v !== I18n.lang)
                        Terminal.run(I18n.tr("Language"), '"$1" set "$2"',
                                     [Quickshell.shellPath("scripts/locale.sh"), v])
                }
            }
        }
        BarText {
            Layout.fillWidth: true
            text: I18n.tr("It changes the system language (localectl, asks for the password). The shell, the system menu (walker), the keybind list and the scripts' messages change at once; other apps, after logging out and back in.")
            color: Theme.dim
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }
}
