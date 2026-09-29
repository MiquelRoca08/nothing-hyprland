// Settings → Keyboard and mouse. Saved in settings.json and applied by Config.qml to
// Hyprland (conf/shell-settings.lua), instantly. These options override conf/input.lua, which
// is left for gestures, specific devices and per-app rules («Advanced» opens it in nvim).
// The touchpad group only shows if Hyprland sees one (hyprctl devices).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Keyboard and mouse")
    subtitle: I18n.tr("Keyboard layout and repeat, mouse and touchpad")
    readonly property var o: Config.options

    // --- Devices (to show or hide the touchpad) ---
    property var mice: []
    readonly property var touchpads: mice.filter(n => /touchpad|trackpad|synaptics|glidepoint/i.test(n))
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { page.mice = (JSON.parse(text).mice ?? []).map(m => m.name) } catch (e) {} }
        }
    }

    // --- XKB options: Caps Lock's is picked with chips; the rest, by hand ---
    readonly property var capsChoices: [
        { v: "", label: I18n.tr("Normal") }, { v: "caps:escape", label: "Escape" },
        { v: "ctrl:nocaps", label: "Ctrl" }, { v: "caps:none", label: I18n.tr("Off") },
    ]
    readonly property var xkbList: o.kbOptions.split(",").map(s => s.trim()).filter(s => s !== "")
    readonly property string capsOpt: xkbList.find(s => capsChoices.some(c => c.v === s)) ?? ""
    readonly property string otherXkb: xkbList.filter(s => s !== capsOpt).join(",")
    function setXkb(caps, other) {
        o.kbOptions = [caps].concat(other.split(",").map(s => s.trim())).filter(s => s !== "").join(",")
    }

    readonly property var layouts: [
        { v: "es", label: I18n.tr("Spanish") }, { v: "latam", label: I18n.tr("Latin American") }, { v: "us", label: I18n.tr("English (US)") },
        { v: "gb", label: I18n.tr("English (UK)") }, { v: "fr", label: I18n.tr("French") }, { v: "de", label: I18n.tr("German") },
        { v: "it", label: I18n.tr("Italian") }, { v: "pt", label: I18n.tr("Portuguese") },
    ]

    SettingsGroup {
        label: I18n.tr("Keyboard")
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            BarText { text: I18n.tr("Layout") }
            ChoiceChips {
                Layout.fillWidth: true
                // one that is not in the list (set by hand) shows too, chosen
                options: page.layouts.some(l => l.v === page.o.kbLayout) ? page.layouts
                       : page.layouts.concat([{ v: page.o.kbLayout, label: page.o.kbLayout }])
                value: page.o.kbLayout
                onChosen: v => page.o.kbLayout = v
            }
        }
        SettingsRow {
            text: I18n.tr("Caps Lock")
            description: I18n.tr("What the key does")
            ChoiceChips {
                options: page.capsChoices
                value: page.capsOpt
                onChosen: v => page.setXkb(v, page.otherXkb)
            }
        }
        SettingsRow {
            text: I18n.tr("Num Lock on startup")
            Toggle { checked: page.o.numlock; onToggled: page.o.numlock = !page.o.numlock }
        }
    }

    SettingsGroup {
        label: I18n.tr("Key repeat")
        SettingsRow {
            text: I18n.tr("Delay")
            description: I18n.tr("How long a key has to be held until it repeats")
            SliderField { value: page.o.repeatDelay; from: 150; to: 800; stepSize: 10; suffix: " ms"; onMoved: v => page.o.repeatDelay = Math.round(v) }
        }
        SettingsRow {
            text: I18n.tr("Speed")
            description: I18n.tr("Repeats per second")
            SliderField { value: page.o.repeatRate; from: 10; to: 80; stepSize: 1; suffix: "/s"; onMoved: v => page.o.repeatRate = Math.round(v) }
        }
        WifiField {
            Layout.fillWidth: true
            placeholder: I18n.tr("Try it here: hold a key down")
        }
    }

    SettingsGroup {
        label: I18n.tr("Mouse")
        SettingsRow {
            text: I18n.tr("Sensitivity")
            description: I18n.tr("For every mouse and the touchpad")
            SliderField { value: page.o.mouseSensitivity; from: -1; to: 1; stepSize: 0.05; decimals: 2; onMoved: v => page.o.mouseSensitivity = v }
        }
        SettingsRow {
            text: I18n.tr("Acceleration")
            description: I18n.tr("Adaptive: the faster you move it, the further it goes")
            ChoiceChips {
                options: [{ v: "flat", label: I18n.tr("No acceleration") }, { v: "adaptive", label: I18n.tr("Adaptive") }]
                value: page.o.accelProfile
                onChosen: v => page.o.accelProfile = v
            }
        }
        SettingsRow {
            text: I18n.tr("Natural scrolling")
            description: I18n.tr("Reverses the wheel direction")
            Toggle { checked: page.o.mouseNaturalScroll; onToggled: page.o.mouseNaturalScroll = !page.o.mouseNaturalScroll }
        }
        SettingsRow {
            text: I18n.tr("Left-handed")
            description: I18n.tr("Swaps the left and right buttons")
            Toggle { checked: page.o.leftHanded; onToggled: page.o.leftHanded = !page.o.leftHanded }
        }
        SettingsRow {
            text: I18n.tr("Focus follows the mouse")
            description: I18n.tr("Which window gets the keyboard")
            ChoiceChips {
                options: [{ v: 1, label: I18n.tr("On hover") }, { v: 2, label: I18n.tr("On click") }, { v: 0, label: I18n.tr("Never") }]
                value: page.o.followMouse
                onChosen: v => page.o.followMouse = v
            }
        }
    }

    SettingsGroup {
        label: "Touchpad"
        visible: page.touchpads.length > 0
        SettingsRow {
            text: I18n.tr("Tap to click")
            Toggle { checked: page.o.tapToClick; onToggled: page.o.tapToClick = !page.o.tapToClick }
        }
        SettingsRow {
            text: I18n.tr("Natural scrolling")
            description: I18n.tr("The content follows the fingers")
            Toggle { checked: page.o.naturalScroll; onToggled: page.o.naturalScroll = !page.o.naturalScroll }
        }
        SettingsRow {
            text: I18n.tr("Scroll speed")
            SliderField { value: page.o.touchpadScroll; from: 0.05; to: 1.5; stepSize: 0.05; decimals: 2; onMoved: v => page.o.touchpadScroll = v }
        }
        SettingsRow {
            text: I18n.tr("Disable while typing")
            Toggle { checked: page.o.disableWhileTyping; onToggled: page.o.disableWhileTyping = !page.o.disableWhileTyping }
        }
    }

    SettingsGroup {
        label: I18n.tr("Touchpad clicks and dragging")
        visible: page.touchpads.length > 0
        SettingsRow {
            text: I18n.tr("Finger click")
            description: I18n.tr("Press with 1, 2 or 3 fingers: left, right or middle click")
            Toggle { checked: page.o.clickfinger; onToggled: page.o.clickfinger = !page.o.clickfinger }
        }
        SettingsRow {
            text: I18n.tr("Emulated middle click")
            description: I18n.tr("Press left and right at once")
            Toggle { checked: page.o.middleEmulation; onToggled: page.o.middleEmulation = !page.o.middleEmulation }
        }
        SettingsRow {
            text: I18n.tr("Multi-finger drag")
            ChoiceChips {
                options: [{ v: 1, label: I18n.tr("3 fingers") }, { v: 2, label: I18n.tr("4 fingers") }, { v: 0, label: I18n.tr("No") }]
                value: page.o.drag3fg
                onChosen: v => page.o.drag3fg = v
            }
        }
        SettingsRow {
            text: I18n.tr("Tap and drag")
            description: I18n.tr("Double tap keeping the finger down")
            Toggle { checked: page.o.tapAndDrag; onToggled: page.o.tapAndDrag = !page.o.tapAndDrag }
        }
        SettingsRow {
            text: I18n.tr("Drag lock")
            description: I18n.tr("Lifting the finger for a moment does not drop what you drag")
            Toggle { checked: page.o.dragLock; onToggled: page.o.dragLock = !page.o.dragLock }
        }
    }

    SettingsGroup {
        label: I18n.tr("Advanced")
        SettingsRow {
            text: I18n.tr("Layout variant")
            description: I18n.tr("Optional, e.g. «nodeadkeys». Enter to apply")
            WifiField {
                Layout.preferredWidth: 220
                placeholder: I18n.tr("none")
                Component.onCompleted: text = page.o.kbVariant
                onAccepted: page.o.kbVariant = text.trim()
            }
        }
        SettingsRow {
            text: I18n.tr("Other XKB options")
            description: I18n.tr("Comma-separated, e.g. «compose:ralt». Enter to apply")
            WifiField {
                Layout.preferredWidth: 220
                placeholder: I18n.tr("none")
                Component.onCompleted: text = page.otherXkb
                onAccepted: page.setXkb(page.capsOpt, text)
            }
        }
        SettingsRow {
            text: "input.lua"
            description: I18n.tr("Gestures, specific devices and per-app rules (~/.config/hypr/conf/input.lua)")
            Button {
                icon: ""; text: I18n.tr("Edit in nvim")
                onClicked: Terminal.open("input.lua", ["nvim", Quickshell.env("HOME") + "/.config/hypr/conf/input.lua"])
            }
        }
    }
}
