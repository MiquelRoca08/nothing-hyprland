// Wheel and touchpad scrolling for a Flickable (put it inside, with flick: the Flickable).
// Qt's is very slow on Linux: each wheel step moves a few pixels and the touchpad even
// less. Here a wheel step scrolls `step` px and the touchpad follows the finger (pixelDelta × `touch`).
import QtQuick

WheelHandler {
    id: root
    property Flickable flick
    property real step: 110          // px per wheel step (120 angleDelta units)
    property real touch: 1.6         // touchpad multiplier
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
        if (!flick) return
        const dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y * touch : event.angleDelta.y / 120 * step
        const max = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(max, flick.contentY - dy))
        event.accepted = true
    }
}
