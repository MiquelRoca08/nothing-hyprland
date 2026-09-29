// Date and time (time in a dot matrix).
import Quickshell
import QtQuick

Row {
    spacing: 12
    SystemClock { id: clock; precision: Config.options.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    BarText {
        visible: Config.options.barDate
        anchors.verticalCenter: parent.verticalCenter
        text: clock.date.toLocaleString(I18n.locale, "ddd d MMM").toUpperCase()
        color: Theme.dim
        font.pixelSize: 12
        font.letterSpacing: 1
    }
    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: clock.date.toLocaleString(I18n.locale, Config.options.clockSeconds ? "HH:mm:ss" : "HH:mm")
        font.family: Theme.displayFont
        font.pixelSize: 22
        font.weight: Font.Black
    }
}
