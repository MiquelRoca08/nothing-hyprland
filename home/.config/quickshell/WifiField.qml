// Text field for Settings and the Wi-Fi forms (password, eduroam user…).
// search: true turns it into a search box: magnifier on the left and, with text, an X on the right that
// clears it (emits cleared()). Escape drops the focus (without clearing) and emits cancelled(); in a
// search box, Enter too (after emitting accepted()); a click outside, likewise (SettingsWindow).
import QtQuick

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property bool password: false
    property bool search: false
    signal accepted()
    signal cancelled()
    signal cleared()
    function focusInput() { input.forceActiveFocus() }
    readonly property alias inputItem: input

    implicitHeight: 36
    radius: 8
    color: Theme.control
    border.width: 1
    border.color: input.activeFocus ? Theme.sel : Theme.border

    BarText {
        id: lupa
        visible: root.search
        anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
        text: "󰍉"
        color: input.activeFocus ? Theme.fg : Theme.dim
    }

    TextInput {
        id: input
        anchors {
            fill: parent
            leftMargin: root.search ? lupa.implicitWidth + 22 : 10
            rightMargin: root.search ? 36 : 10
        }
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.password ? TextInput.Password : TextInput.Normal
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        selectByMouse: true
        selectionColor: Theme.sel
        selectedTextColor: Theme.selText
        clip: true
        onAccepted: { root.accepted(); if (root.search) input.focus = false }
        Keys.onEscapePressed: event => { input.focus = false; event.accepted = true; root.cancelled() }

        BarText {
            visible: !input.text
            text: root.placeholder
            color: Theme.dim
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            elide: Text.ElideRight
        }
    }

    // Clear (only in search boxes with text). IconButton keeps the click (MouseArea): it does not reach
    // the window's one that drops the focus
    IconButton {
        visible: root.search && input.text !== ""
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        icon: "󰅖"; size: 24
        onClicked: { input.text = ""; input.forceActiveFocus(); root.cleared() }
    }
}
