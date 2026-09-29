// Rounded screen corners (like ii), concentric with the
// windows: radius = Theme.radius + Theme.gap. With the bar in "hug" mode,
// the top ones sit right below the bar. They take no clicks.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-corners"

    Canvas {
        anchors.fill: parent
        // Redraw when the size or appearance changes
        property var deps: [width, height, Theme.wallpaper, Theme.dot, Theme.screenRadius, Theme.barStyle, Theme.barHeight]
        onDepsChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const r = Theme.screenRadius, w = width, h = height
            const top = Theme.barStyle === "hug" ? Theme.barHeight : 0
            ctx.clearRect(0, 0, w, h)
            ctx.fillStyle = Theme.bg
            // Each corner: the r×r square minus the quarter circle
            const corner = (cx, cy, x0, y0, a0) => {
                ctx.beginPath()
                ctx.moveTo(x0, y0)
                ctx.arc(cx, cy, r, a0, a0 + Math.PI / 2)
                ctx.closePath()
                ctx.fill()
            }
            corner(r, top + r, 0, top, Math.PI)                // top left
            corner(w - r, top + r, w, top, -Math.PI / 2)       // top right
            corner(w - r, h - r, w, h, 0)                      // bottom right
            corner(r, h - r, 0, h, Math.PI / 2)                // bottom left
        }
    }
}
