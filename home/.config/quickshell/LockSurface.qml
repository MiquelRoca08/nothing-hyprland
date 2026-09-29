// Lock screen content on each monitor (created by LockScreen): time in
// Doto, date, password field and PAM messages, like the old hyprlock.
// The password is shared between monitors (ctx.buffer).
import Quickshell
import QtQuick

Item {
    id: surface
    required property var ctx    // LockScreen

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // No cursor (like hyprlock's hide_cursor); moving it counts as activity
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
        onPositionChanged: surface.ctx.activity()
        onClicked: input.forceActiveFocus()
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -150 }
        text: clock.date.toLocaleString(I18n.locale, "HH:mm")
        color: Theme.fg
        font.family: Theme.displayFont
        font.weight: Font.Black
        font.pixelSize: 140
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -40 }
        text: clock.date.toLocaleString(I18n.locale, "dddd d MMMM").toUpperCase()
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 18
        font.letterSpacing: 2
    }

    Rectangle {
        id: field
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: 60 }
        width: 300
        height: 48
        radius: height / 2
        color: Theme.bg
        border.width: 1
        border.color: surface.ctx.busy ? Theme.fg
                    : surface.ctx.statusIsError && input.text === "" ? Theme.red
                    : Theme.border

        TextInput {
            id: input
            anchors { fill: parent; leftMargin: 24; rightMargin: 24 }
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Password
            passwordCharacter: "●"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 16
            font.letterSpacing: 4
            focus: true
            readOnly: surface.ctx.busy
            clip: true

            Component.onCompleted: forceActiveFocus()
            onTextChanged: if (surface.ctx.buffer !== text) surface.ctx.buffer = text
            onAccepted: surface.ctx.submit()
            Keys.onPressed: event => { surface.ctx.activity(); event.accepted = false }   // the key goes on its way
            Keys.onEscapePressed: text = ""

            Text {
                anchors.centerIn: parent
                visible: input.text === ""
                text: I18n.tr("PASSWORD")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 14
                font.letterSpacing: 2
            }
        }

        // The password is typed on one monitor and shown on all of them
        Connections {
            target: surface.ctx
            function onBufferChanged() { if (input.text !== surface.ctx.buffer) input.text = surface.ctx.buffer }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: field.bottom; topMargin: 20 }
        width: 420
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: surface.ctx.status
        color: surface.ctx.statusIsError ? Theme.red : Theme.dim
        font.family: Theme.font
        font.pixelSize: 13
    }
}
