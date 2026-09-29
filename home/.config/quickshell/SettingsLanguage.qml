// Settings → System → Language: the interface language (Config.options.language, read by I18n.qml).
import QtQuick
import QtQuick.Layouts

SettingsPage {
    title: I18n.tr("Language")
    subtitle: I18n.tr("Language of the shell's interface")

    SettingsGroup {
        SettingsRow {
            text: I18n.tr("Interface language")
            description: I18n.tr("Automatic follows the system language ($LANG): Spanish if it is Spanish, English otherwise.")
            ChoiceChips {
                value: Config.options.language
                options: I18n.languages.map(l => ({ v: l.v, label: l.v === "auto" ? I18n.tr(l.label) : l.label }))
                onChosen: v => Config.options.language = v
            }
        }
        BarText {
            Layout.fillWidth: true
            text: I18n.tr("It also applies to the system menu (walker), the keybind list and the messages of the scripts. Restart the shell or reopen the menu if something stays in the previous language.")
            color: Theme.dim
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }
}
