// Settings → Personalization → Wallpaper: dot grid (with its tone) or an image from
// ~/Pictures/Wallpapers (import copies the one chosen with zenity there), and search Wallhaven (public
// API v1, SFW only, no key): clicking a thumbnail downloads it to ~/Pictures/Wallpapers and
// sets it. Saved in settings.json (Config.qml).
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import QtQuick
import QtQuick.Layouts

SettingsPage {
    id: page
    title: I18n.tr("Wallpaper")
    subtitle: I18n.tr("Dot grid, an image from ~/Pictures/Wallpapers or one from Wallhaven")
    readonly property var o: Config.options
    readonly property string wallDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // Import: file picker (zenity) and copy to ~/Pictures/Wallpapers
    Process {
        id: importProc
        command: ["sh", "-c",
            "f=$(zenity --file-selection --title=\"$1\" " +
            "--filename=\"$HOME/Pictures/\" " +
            "--file-filter=\"$2 | *.png *.jpg *.jpeg *.webp *.PNG *.JPG *.JPEG *.WEBP\") || exit 1; " +
            "d=\"$HOME/Pictures/Wallpapers\"; mkdir -p \"$d\"; " +
            "case \"$f\" in \"$d\"/*) echo \"$f\" ;; *) cp -n \"$f\" \"$d/\" && echo \"$d/$(basename \"$f\")\" ;; esac",
            "sh", I18n.tr("Import wallpaper"), I18n.tr("Images")]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path) { page.o.wallpaperPath = path; page.o.wallpaperMode = "image" }
            }
        }
    }
    // --- Wallhaven ---
    property string whQuery: ""
    property string whSort: "toplist"      // toplist | date_added | random | relevance
    property string whCat: "110"           // categories (general, anime, people): 111 all
    property bool whFit: true              // at least the resolution of the largest screen
    property var whItems: []               // [{ id, thumb, full, res, size }]
    property int whPage: 0
    property int whLastPage: 1
    property string whSeed: ""             // «random» pages with the same seed
    property bool whLoading: false
    property string whError: ""
    property string whGetting: ""          // id being downloaded
    property int whMore: 0                 // pages still to fetch for «Load more»
    property var whXhr: null               // request in progress (cut if another search arrives)
    // Physical resolution of the largest screen
    readonly property string screenRes: {
        let w = 0, h = 0
        for (const sc of Quickshell.screens) {
            const sw = Math.round(sc.width * (sc.devicePixelRatio || 1)), sh = Math.round(sc.height * (sc.devicePixelRatio || 1))
            if (sw * sh > w * h) { w = sw; h = sh }
        }
        return w && h ? w + "x" + h : "1920x1080"
    }
    // more: the next page. «Load more» asks for 3 in a row (the API gives 24 per page without a key)
    function whLoadMore() { whMore = 2; whSearch(true) }
    function whSearch(more) {
        const pageN = more ? whPage + 1 : 1
        if (whXhr) { whXhr.onreadystatechange = null; whXhr.abort(); whXhr = null }
        if (!more) { whItems = []; whSeed = ""; whMore = 0 }
        const sort = whSort === "relevance" && !whQuery ? "toplist" : whSort
        let url = "https://wallhaven.cc/api/v1/search?purity=100&categories=" + whCat + "&sorting=" + sort + "&page=" + pageN
        if (sort === "toplist") url += "&topRange=1y"
        if (whQuery) url += "&q=" + encodeURIComponent(whQuery)
        if (whFit) url += "&atleast=" + screenRes
        if (sort === "random" && whSeed) url += "&seed=" + whSeed
        whLoading = true; whError = ""
        const xhr = new XMLHttpRequest()
        whXhr = xhr
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            whXhr = null
            whLoading = false
            if (xhr.status !== 200) { whError = xhr.status === 429 ? I18n.tr("Too many searches in a row: wait a minute") : I18n.tr("Could not connect to Wallhaven (%1)").arg(xhr.status); return }
            try {
                const r = JSON.parse(xhr.responseText)
                whItems = whItems.concat((r.data || []).map(d => ({ id: d.id, thumb: d.thumbs.small, full: d.path, res: d.resolution, size: d.file_size })))
                whPage = r.meta?.current_page ?? pageN
                whLastPage = r.meta?.last_page ?? pageN
                if (r.meta?.seed) whSeed = r.meta.seed
                if (whMore > 0 && whPage < whLastPage) { whMore--; whSearch(true) } else whMore = 0
            } catch (e) { whError = I18n.tr("Invalid response from Wallhaven"); whMore = 0 }
        }
        xhr.open("GET", url)
        xhr.send()
    }
    // While typing: almost instantly (0.25 s); the previous search is cut
    Timer { id: whTyping; interval: 250; onTriggered: page.whSearch(false) }
    // Downloads to ~/Pictures/Wallpapers/wallhaven-<id>.<ext> (if already there, it is not downloaded again) and sets it
    Process {
        id: whGet
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path) { page.o.wallpaperPath = path; page.o.wallpaperMode = "image" }
                else page.whError = I18n.tr("Could not download the image")
                page.whGetting = ""
            }
        }
    }
    function whDownload(item) {
        whGetting = item.id
        whGet.command = ["sh", "-c",
            'd="$HOME/Pictures/Wallpapers"; mkdir -p "$d"; f="$d/wallhaven-$1.${2##*.}"; ' +
            'if [ ! -s "$f" ]; then curl -fsSL -o "$f.part" "$2" && mv -f "$f.part" "$f" || rm -f "$f.part"; fi; ' +
            '[ -s "$f" ] && echo "$f"',
            "sh", item.id, item.full]
        whGet.running = true
    }

    // Deletes a wallpaper from ~/Pictures/Wallpapers (to the trash: it can be recovered). If it was the current one,
    // the dot grid comes back. The list updates by itself (FolderListModel watches the folder)
    Process { id: trashProc }
    function trashWallpaper(path) {
        if (o.wallpaperPath === path) { o.wallpaperMode = "dots"; o.wallpaperPath = "" }
        trashProc.command = ["gio", "trash", "--", path]
        trashProc.running = true
    }

    FolderListModel {
        id: walls
        folder: "file://" + page.wallDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.PNG", "*.JPG", "*.JPEG", "*.WEBP"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    SettingsGroup {
        SettingsRow {
            text: I18n.tr("Type")
            description: I18n.tr("Dot grid (default) or an image")
            ChoiceChips {
                value: o.wallpaperMode === "image" ? "image" : "dots"
                options: [{ v: "dots", label: I18n.tr("Dots") }, { v: "image", label: I18n.tr("Image") }]
                onChosen: v => {
                    if (v === "dots") o.wallpaperMode = "dots"
                    else if (o.wallpaperPath) o.wallpaperMode = "image"
                    else importProc.running = true
                }
            }
        }
        SettingsRow {
            visible: o.wallpaperMode !== "image"
            text: I18n.tr("Tone")
            description: I18n.tr("From black to grey")
            RowLayout {
                spacing: 12
                SliderField { value: o.wallpaperTone; from: 0; to: 60; onMoved: v => o.wallpaperTone = Math.round(v) }
                Rectangle { implicitWidth: 28; implicitHeight: 28; radius: 6; color: Theme.wallpaper; border.color: Theme.border; border.width: 1 }
            }
        }

        // Images from ~/Pictures/Wallpapers + import
        Flow {
            visible: o.wallpaperMode === "image"
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: walls
                delegate: Rectangle {
                    id: tile
                    required property string filePath
                    readonly property bool selected: o.wallpaperPath === filePath
                    width: 132; height: 76; radius: 8
                    color: Theme.control
                    border.color: selected ? Theme.sel : Theme.border
                    border.width: selected ? 2 : 1
                    clip: true
                    Image {
                        anchors { fill: parent; margins: parent.border.width }
                        source: "file://" + parent.filePath
                        sourceSize: Qt.size(264, 152)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { o.wallpaperPath = tile.filePath; o.wallpaperMode = "image" }
                    }
                    // HoverHandler (not the MouseArea's containsMouse): it stays active with the pointer over
                    // the trash button, which would otherwise disappear when going to click it
                    HoverHandler { id: tileHover }
                    // Delete (to the trash): top right, on hover
                    IconButton {
                        visible: tileHover.hovered
                        anchors { top: parent.top; right: parent.right; margins: 5 }
                        overlay: true; danger: true; size: 24
                        onClicked: page.trashWallpaper(tile.filePath)
                    }
                }
            }
            Rectangle {
                width: 132; height: 76; radius: 8
                color: Theme.control
                border.color: Theme.border
                border.width: 1
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    BarText { anchors.horizontalCenter: parent.horizontalCenter; text: importProc.running ? "…" : "󰋩"; font.pixelSize: 20 }
                    BarText { anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Import…"); font.pixelSize: 11 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: importProc.running = true }
            }
        }
        BarText {
            visible: o.wallpaperMode === "image"
            text: I18n.tr("They are saved in ~/Pictures/Wallpapers")
            color: Theme.dim
            font.pixelSize: 11
        }
    }

    // --- Wallhaven ---
    SettingsGroup {
        label: "Wallhaven"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            WifiField {
                Layout.fillWidth: true
                search: true
                placeholder: I18n.tr("Search wallpapers (e.g. «mountains», «minimal», «space»…)")
                onTextChanged: { page.whQuery = text.trim(); if (page.whQuery && page.whSort === "toplist") page.whSort = "relevance"; whTyping.restart() }
                onAccepted: { whTyping.stop(); page.whSearch(false) }
                onCleared: { whTyping.stop(); page.whSort = "toplist"; page.whSearch(false) }
            }
            Button {
                kind: "primary"; icon: "󰍉"; text: page.whItems.length ? I18n.tr("Search") : I18n.tr("Browse wallpapers")
                busy: page.whLoading && page.whItems.length === 0
                onClicked: page.whSearch(false)
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 16
            ChoiceChips {
                value: page.whSort
                options: [{ v: "toplist", label: I18n.tr("Popular") }, { v: "date_added", label: I18n.tr("Recent") },
                          { v: "random", label: I18n.tr("Random") }].concat(page.whQuery ? [{ v: "relevance", label: I18n.tr("Relevance") }] : [])
                onChosen: v => { page.whSort = v; page.whSearch(false) }
            }
            ChoiceChips {
                value: page.whCat
                options: [{ v: "111", label: I18n.tr("All") }, { v: "110", label: I18n.tr("General and anime") }, { v: "100", label: I18n.tr("General") }]
                onChosen: v => { page.whCat = v; page.whSearch(false) }
            }
            ChoiceChips {
                value: page.whFit
                options: [{ v: true, label: I18n.tr("For my screen (%1)").arg(page.screenRes) }, { v: false, label: I18n.tr("Any size") }]
                onChosen: v => { page.whFit = v; page.whSearch(false) }
            }
        }
        BarText {
            visible: page.whError !== "" || (page.whPage > 0 && !page.whLoading && page.whItems.length === 0)
            text: page.whError || I18n.tr("Nothing with those filters")
            color: page.whError ? Theme.red : Theme.dim
            font.pixelSize: 12
        }
        // Thumbnails: click = download and set
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: page.whItems
                delegate: Rectangle {
                    id: wh
                    required property var modelData
                    readonly property bool current: page.o.wallpaperPath.endsWith("/wallhaven-" + modelData.id + "." + modelData.full.split(".").pop())
                    width: 150; height: 100; radius: 8
                    color: Theme.control
                    border.color: current ? Theme.sel : whHover.hovered ? Theme.fgSoft : Theme.border
                    border.width: current ? 2 : 1
                    clip: true
                    Image {
                        anchors { fill: parent; margins: parent.border.width }
                        source: wh.modelData.thumb
                        sourceSize: Qt.size(300, 200)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    // Resolution and size on hover; «…» while downloading
                    Rectangle {
                        visible: whHover.hovered || page.whGetting === wh.modelData.id
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: parent.border.width }
                        height: 22
                        color: "#cc000000"
                        BarText {
                            anchors.centerIn: parent
                            text: page.whGetting === wh.modelData.id ? I18n.tr("Downloading…") : wh.modelData.res + " · " + (wh.modelData.size / 1048576).toFixed(1) + " MB"
                            font.pixelSize: 10
                        }
                    }
                    HoverHandler { id: whHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { enabled: page.whGetting === ""; onTapped: page.whDownload(wh.modelData) }
                }
            }
        }
        RowLayout {
            visible: page.whItems.length > 0
            Layout.fillWidth: true
            BarText {
                Layout.fillWidth: true
                text: I18n.tr("Click one to download it to ~/Pictures/Wallpapers and set it · wallhaven.cc")
                color: Theme.dim; font.pixelSize: 11
            }
            Button {
                visible: page.whPage < page.whLastPage
                text: I18n.tr("Load more")
                busy: page.whLoading
                onClicked: page.whLoadMore()
            }
        }
    }
}
