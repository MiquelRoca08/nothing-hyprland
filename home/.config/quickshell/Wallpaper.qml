// Full-screen background, as set in Settings → Appearance:
//   dots  → grey with a dot grid (Nothing style)
//   image → static image (cropped to fill the screen); if it cannot be loaded (e.g. on
//           another machine, where it does not exist), dots
// The rounded corners are drawn on top by ScreenCorners.qml.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool wantImage: Config.options.wallpaperMode === "image" && Config.options.wallpaperPath !== ""
    readonly property bool useImage: wantImage && img.status !== Image.Error

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.wallpaper
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "qs-wallpaper"

    Canvas {
        anchors.fill: parent
        visible: !win.useImage
        // Redraw when the size or appearance changes
        property var deps: [width, height, visible, Theme.wallpaper, Theme.dot]
        onDepsChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const step = 28, r = 1.4
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Theme.dot
            // Centred grid: the same margin on both sides (starting at step/2, the last dot
            // fell wherever it did and there was spare space on the right and bottom)
            const x0 = (width - (Math.floor(width / step) - 1) * step) / 2
            const y0 = (height - (Math.floor(height / step) - 1) * step) / 2
            for (let y = y0; y < height; y += step)
                for (let x = x0; x < width; x += step) {
                    ctx.beginPath(); ctx.arc(x, y, r, 0, 2 * Math.PI); ctx.fill()
                }
        }
    }

    Image {
        id: img
        anchors.fill: parent
        visible: win.useImage
        source: win.wantImage ? "file://" + Config.options.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        // Physical resolution of the screen (sharp at scale 2)
        sourceSize: Qt.size(width * (win.screen?.devicePixelRatio ?? 1), height * (win.screen?.devicePixelRatio ?? 1))
    }
}
