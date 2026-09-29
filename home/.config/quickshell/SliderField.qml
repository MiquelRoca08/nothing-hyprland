// Slider with a value that can be edited by hand: drag it or type the
// number and press Enter (or leave the field). The value is clamped to [from, to] and
// snapped to the step. Emits moved(value); the value is up to whoever uses it.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root
    property real value
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property int decimals: 0
    property string suffix: ""        // unit shown after the number
    property string zeroText: ""      // text instead of 0 (e.g. "Never")
    property int sliderWidth: 220
    property bool fill: false         // the slider takes all the available width
    signal moved(real value)

    Layout.fillWidth: fill
    spacing: 12

    function clampStep(v) {
        v = Math.max(from, Math.min(to, v))
        if (stepSize > 0) v = from + Math.round((v - from) / stepSize) * stepSize
        return Number(v.toFixed(decimals))
    }

    Slider {
        Layout.preferredWidth: root.fill ? -1 : root.sliderWidth
        Layout.fillWidth: root.fill
        from: root.from; to: root.to; stepSize: root.stepSize
        value: root.value
        onMoved: v => root.moved(root.clampStep(v))
    }

    // Editable field: number + unit
    Rectangle {
        implicitWidth: Math.max(64, input.implicitWidth + unit.implicitWidth + 18)
        implicitHeight: 28
        radius: 6
        color: input.activeFocus ? Theme.control : "transparent"
        border.color: input.activeFocus ? Theme.sel : hover.hovered ? Theme.border : "transparent"
        border.width: 1
        HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

        Row {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 2
            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                selectByMouse: true
                selectionColor: Theme.sel
                selectedTextColor: Theme.selText
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: RegularExpressionValidator { regularExpression: /-?[0-9]*[.,]?[0-9]*/ }
                // The text is assigned by hand (not with a binding): when editing, an assignment
                // would break the binding and the field would stop following the slider.
                function refresh() {
                    text = root.zeroText && root.value === 0 ? root.zeroText : root.value.toFixed(root.decimals)
                }
                Component.onCompleted: refresh()
                Connections {
                    target: root
                    function onValueChanged() { if (!input.activeFocus) input.refresh() }
                }
                onActiveFocusChanged: {
                    if (activeFocus) { text = root.value.toFixed(root.decimals); selectAll() }
                    else refresh()
                }
                onEditingFinished: {
                    const v = parseFloat(text.replace(",", "."))
                    if (!isNaN(v)) root.moved(root.clampStep(v))
                    focus = false
                    refresh()
                }
                Keys.onEscapePressed: { focus = false; refresh() }
            }
            BarText {
                id: unit
                anchors.verticalCenter: parent.verticalCenter
                visible: !(root.zeroText && root.value === 0 && !input.activeFocus)
                text: root.suffix
                color: Theme.dim
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: input.forceActiveFocus()
            // Lets mouse selection through once inside the field
            enabled: !input.activeFocus
        }
    }
}
