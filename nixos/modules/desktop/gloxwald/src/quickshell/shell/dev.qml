import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

FloatingWindow {
    id: win
    title: "gloxwald dev"
    implicitWidth: 1600
    implicitHeight: 1000
    color: "#101014"

    readonly property string rootDir: Quickshell.env("GLOXWALD_ROOT")
    readonly property string devDir: Quickshell.env("GLOXWALD_DEV")

    readonly property var tabNames: ["desktop", "bar", "lock", "greeter", "grub"]
    readonly property string tabName: tabNames[tab]
    property int tab: Math.max(0, tabNames.indexOf(Quickshell.env("GLOXWALD_TAB") || "desktop"))

    readonly property var resolutions: [[1920, 1200], [1920, 1080], [2560, 1440], [1280, 800]]
    property int resIndex: 0
    readonly property int frameW: resolutions[resIndex][0]
    readonly property int frameH: resolutions[resIndex][1]
    property bool fit: true
    property bool logOpen: true
    property bool logAll: false
    property real barZoom: 2
    property bool mockWindows: true
    property string dock: "left"
    property string lastWheel: ""
    readonly property int sidebarWidth: 330
    readonly property var tabSources: ({ desktop: ["dev", "theme"], bar: ["dev", "theme"], lock: ["dev", "theme", "shader"], greeter: ["dev", "theme", "greeter"], grub: ["dev", "theme", "grub"] })
    property int sceneRev: 0

    property var theme: ({})
    readonly property var themeKeys: [["app100", "bg"], ["app150", "bg active"], ["app600", "fg"], ["wm800", "accent"]]

    onTabChanged: Qt.callLater(focusTab)
    onResIndexChanged: grubJob.kick()

    function focusTab() {
        if (tabName === "greeter") term.forceActiveFocus();
        else if (tabName === "grub") grub.forceActiveFocus();
        else stage.forceActiveFocus();
    }

    function log(src, line) {
        logModel.append({ src: src, line: String(line) });
        if (logModel.count > 1000)
            logModel.remove(0, logModel.count - 1000);
    }

    function setThemeKey(key, value) {
        const t = Object.assign({}, theme);
        t[key] = value;
        theme = t;
        themeFile.setText(JSON.stringify(t, null, 2) + "\n");
        themeDebounce.restart();
    }

    function reloadTab() {
        if (tabName === "bar") {
            gallery.reload();
        } else if (tabName === "lock") {
            sceneRev++;
            lockCtx.reset();
        } else if (tabName === "greeter") {
            greeterJob.kick();
        } else if (tabName === "grub") {
            grubJob.kick();
        } else {
            desktopLoader.active = false;
            desktopLoader.active = true;
        }
        log("dev", "reload " + tabNames[tab]);
    }

    function reloadAll() {
        gallery.reload();
        desktopLoader.active = false;
        desktopLoader.active = true;
        shaderJob.kick();
        lockCtx.reset();
        greeterJob.kick();
        grubJob.kick();
    }

    ListModel {
        id: logModel
    }

    component Job: Process {
        id: job
        property string name
        property bool pending: false
        function kick() {
            if (running) {
                pending = true;
                return;
            }
            win.log(name, "▶ " + command.slice(1).join(" "));
            running = true;
        }
        stdout: SplitParser {
            onRead: data => win.log(job.name, data)
        }
        stderr: SplitParser {
            onRead: data => win.log(job.name, data)
        }
        onExited: (code, status) => {
            win.log(job.name, code === 0 ? "✓ done" : "✗ exit " + code);
            if (pending) {
                pending = false;
                kick();
            }
        }
    }

    Job {
        id: shaderJob
        name: "shader"
        command: ["bash", win.rootDir + "/src/quickshell/lockscreen/convert-shaders.sh"]
    }

    Job {
        id: greeterJob
        name: "greeter"
        command: ["bash", win.rootDir + "/dev/greeter.sh", "restart", String(term.cols), String(term.rows)]
    }

    Job {
        id: greeterResize
        name: "greeter"
        command: ["bash", win.rootDir + "/dev/greeter.sh", "resize", String(term.cols), String(term.rows)]
    }

    Job {
        id: grubJob
        name: "grub"
        command: ["bash", win.rootDir + "/dev/grub.sh", "restart", String(win.frameW), String(win.frameH)]
    }

    Job {
        id: greeterEnsure
        name: "greeter"
        command: ["bash", win.rootDir + "/dev/greeter.sh", "ensure", String(term.cols), String(term.rows)]
    }

    Job {
        id: grubEnsure
        name: "grub"
        command: ["bash", win.rootDir + "/dev/grub.sh", "ensure", String(win.frameW), String(win.frameH)]
    }

    IpcHandler {
        target: "dev"
        function tab(name: string): void {
            const i = win.tabNames.indexOf(name);
            if (i >= 0)
                win.tab = i;
        }
        function reload(): void {
            win.reloadTab();
        }
        function dock(mode: string): void {
            win.dock = mode;
        }
        function zoom(z: real): void {
            if (z <= 0)
                deskView.fit();
            else
                deskView.zoomTo(z, deskView.width / 2, deskView.height / 2);
        }
        function state(): string {
            return JSON.stringify({ tab: win.tabNames[win.tab], tabName: win.tabName, desktopReady: desktopLoader.status === Loader.Ready, dock: win.dock, logOpen: win.logOpen, lastWheel: win.lastWheel, desk: { zoom: +deskView.zoom.toFixed(3), fit: deskView.fitMode, x: Math.round(deskView.contentX), y: Math.round(deskView.contentY), view: [deskView.width, deskView.height] }, geo: [sidebar, sideScroll, logBox, stage].map(i => [Math.round(i.x), Math.round(i.y), Math.round(i.width), Math.round(i.height)]), grubReady: grub.ready, greeterRunning: term.running, cols: term.cols, rows: term.rows });
        }
    }

    Job {
        id: themeResetJob
        name: "theme"
        command: ["cp", (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickshell-theme.json", win.devDir + "/theme.json"]
    }

    FileView {
        id: themeFile
        path: win.devDir + "/theme.json"
        watchChanges: true
        property bool seen: false
        onFileChanged: reload()
        onLoaded: {
            try {
                win.theme = JSON.parse(text());
            } catch (e) {
                win.log("theme", "bad theme.json: " + e);
                return;
            }
            if (seen)
                themeDebounce.restart();
            seen = true;
        }
    }

    Timer {
        id: themeDebounce
        interval: 800
        onTriggered: {
            greeterJob.kick();
            grubJob.kick();
        }
    }

    FileView {
        path: win.devDir + "/events/shader"
        watchChanges: true
        onFileChanged: shaderJob.kick()
    }

    FileView {
        path: win.devDir + "/events/greeter"
        watchChanges: true
        onFileChanged: greeterJob.kick()
    }

    FileView {
        path: win.devDir + "/events/grub"
        watchChanges: true
        onFileChanged: grubJob.kick()
    }

    FileView {
        path: win.rootDir + "/src/quickshell/shell/shaders/scenes/yamp.qml"
        watchChanges: true
        onFileChanged: sceneDebounce.restart()
    }

    Timer {
        id: sceneDebounce
        interval: 300
        onTriggered: win.sceneRev++
    }

    Timer {
        id: termResize
        interval: 300
        onTriggered: if (term.running) greeterResize.kick()
    }

    Timer {
        interval: 500
        running: true
        onTriggered: {
            greeterEnsure.kick();
            grubEnsure.kick();
            win.focusTab();
        }
    }

    LockContext {
        id: lockCtx
        fakeAuth: true
        onUnlocked: relock.restart()
        Component.onCompleted: reset()
    }

    Timer {
        id: relock
        interval: 1200
        onTriggered: lockCtx.reset()
    }

    Shortcut { sequence: "Ctrl+1"; context: Qt.ApplicationShortcut; onActivated: win.tab = 0 }
    Shortcut { sequence: "Ctrl+2"; context: Qt.ApplicationShortcut; onActivated: win.tab = 1 }
    Shortcut { sequence: "Ctrl+3"; context: Qt.ApplicationShortcut; onActivated: win.tab = 2 }
    Shortcut { sequence: "Ctrl+4"; context: Qt.ApplicationShortcut; onActivated: win.tab = 3 }
    Shortcut { sequence: "Ctrl+5"; context: Qt.ApplicationShortcut; onActivated: win.tab = 4 }
    Shortcut { sequence: "Ctrl+R"; context: Qt.ApplicationShortcut; onActivated: win.reloadTab() }
    Shortcut { sequence: "Ctrl+Shift+R"; context: Qt.ApplicationShortcut; onActivated: win.reloadAll() }
    Shortcut { sequence: "Ctrl+L"; context: Qt.ApplicationShortcut; onActivated: win.logOpen = !win.logOpen }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; onActivated: win.fit = !win.fit }
    Shortcut { sequence: "Ctrl+D"; context: Qt.ApplicationShortcut; onActivated: win.dock = win.dock === "left" ? "bottom" : "left" }
    Shortcut { sequence: "Ctrl+0"; context: Qt.ApplicationShortcut; enabled: win.tabName === "desktop"; onActivated: deskView.fit() }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; context: Qt.ApplicationShortcut; enabled: win.tabName === "desktop"; onActivated: deskView.zoomTo(deskView.zoom * 1.5, deskView.width / 2, deskView.height / 2) }
    Shortcut { sequence: "Ctrl+-"; context: Qt.ApplicationShortcut; enabled: win.tabName === "desktop"; onActivated: deskView.zoomTo(deskView.zoom / 1.5, deskView.width / 2, deskView.height / 2) }

    component SectionTitle: Text {
        color: "#66ffffff"
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.5
        font.capitalization: Font.AllUppercase
        topPadding: 10
        bottomPadding: 2
    }

    component Hint: Text {
        width: parent ? parent.width : 0
        wrapMode: Text.WordWrap
        color: "#88ffffff"
        font.pixelSize: 11
    }

    component ThemeField: Item {
        id: tf
        required property var modelData
        readonly property string key: modelData[0]
        width: parent ? parent.width : 0
        height: 26

        Rectangle {
            id: swatch
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 4
            color: win.theme[tf.key] ?? "#000000"
            border.color: "#55ffffff"
        }

        Text {
            anchors { left: swatch.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
            width: 72
            text: tf.modelData[1]
            color: "#aaffffff"
            font.pixelSize: 12
        }

        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 96
            height: 24
            radius: 4
            color: "#1affffff"
            border.color: input.activeFocus ? "#3aa8b8" : "transparent"

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 5
                color: acceptableInput ? "white" : "#ff8f40"
                font.family: "monospace"
                font.pixelSize: 12
                selectByMouse: true
                text: win.theme[tf.key] ?? ""
                validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
                onEditingFinished: {
                    if (acceptableInput && text !== win.theme[tf.key])
                        win.setThemeKey(tf.key, text);
                    win.focusTab();
                }
                Connections {
                    target: win
                    function onThemeChanged() {
                        if (!input.activeFocus)
                            input.text = win.theme[tf.key] ?? "";
                    }
                }
            }
        }
    }

    component Frame: Item {
        id: fr
        default property alias content: inner.data
        anchors.fill: parent
        clip: true
        readonly property real s: win.fit ? Math.min(width / win.frameW, height / win.frameH) : 1

        Item {
            id: inner
            width: win.frameW
            height: win.frameH
            scale: fr.s
            transformOrigin: Item.TopLeft
            x: (fr.width - width * fr.s) / 2
            y: (fr.height - height * fr.s) / 2
        }
    }

    Rectangle {
        id: sidebar
        readonly property bool atBottom: win.dock === "bottom"
        x: 0
        y: atBottom ? parent.height - height : 0
        width: atBottom ? parent.width : win.sidebarWidth
        height: atBottom ? 340 : parent.height
        color: "#18181d"

        Rectangle {
            x: sidebar.atBottom ? 0 : parent.width - 1
            width: sidebar.atBottom ? parent.width : 1
            height: sidebar.atBottom ? 1 : parent.height
            color: "#2affffff"
        }

        Flickable {
            id: sideScroll
            width: win.sidebarWidth
            height: sidebar.atBottom ? parent.height : parent.height - logBox.height
            contentHeight: side.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: side
                x: 14
                y: 6
                width: sideScroll.width - 28
                spacing: 6

                SectionTitle { text: "view" }

                DevButton {
                    width: side.width
                    label: "dock " + (win.dock === "left" ? "bottom" : "left") + "   ctrl+d"
                    accent: "#d9a530"
                    onClicked: win.dock = win.dock === "left" ? "bottom" : "left"
                }

                Repeater {
                    model: win.tabNames
                    DevButton {
                        required property string modelData
                        required property int index
                        width: side.width
                        height: 28
                        label: modelData + "   ctrl+" + (index + 1)
                        active: win.tab === index
                        onClicked: win.tab = index
                    }
                }

                SectionTitle { text: win.tabNames[win.tab] }

                Column {
                    width: side.width
                    spacing: 6
                    visible: win.tabName === "desktop"
                    Hint { text: "The whole screen at the frame resolution: the static T3 chrome and ground, the live header, and two mock tiled windows. Sizes and colours live in T3.qml." }
                    DevButton {
                        label: "mock windows"
                        active: win.mockWindows
                        onClicked: win.mockWindows = !win.mockWindows
                    }
                    Hint { text: "Ctrl+scroll or pinch to zoom; scroll, shift+scroll or drag to pan; double-click to fit.  zoom " + Math.round(deskView.zoom * 100) + "%" }
                    Flow {
                        width: side.width
                        spacing: 4
                        DevButton {
                            label: "fit  ctrl+0"
                            accent: "#d9a530"
                            active: deskView.fitMode
                            onClicked: deskView.fit()
                        }
                        Repeater {
                            model: [1, 2, 4, 8]
                            DevButton {
                                required property int modelData
                                label: modelData + "x"
                                accent: "#d9a530"
                                active: !deskView.fitMode && Math.abs(deskView.zoom - modelData) < 0.001
                                onClicked: deskView.zoomTo(modelData, deskView.width / 2, deskView.height / 2)
                            }
                        }
                    }
                }

                Column {
                    width: side.width
                    spacing: 6
                    visible: win.tabName === "bar"
                    Hint { text: "The live bar at the frame width, its lockscreen variant, a zoomed crop of every named section (objectName in BarContent), each reusable component on its own, and the live state of every data singleton." }
                    Flow {
                        width: side.width
                        spacing: 4
                        Repeater {
                            model: [1, 2, 3, 4]
                            DevButton {
                                required property int modelData
                                label: "zoom " + modelData + "x"
                                active: win.barZoom === modelData
                                onClicked: win.barZoom = modelData
                            }
                        }
                    }
                }

                Column {
                    width: side.width
                    spacing: 10
                    visible: win.tabName === "lock"
                    Hint { text: "Password gloxwald unlocks, anything else fails. Click the stage to type." }
                    LockSceneTools {
                        context: lockCtx
                        showRelock: true
                        mapColumns: 2
                        flowWidth: side.width
                        onRestart: win.sceneRev++
                    }
                    LockScenePicker {
                        context: lockCtx
                        columns: 2
                        buttonWidth: (side.width - 2) / 2
                    }
                }

                Column {
                    width: side.width
                    spacing: 6
                    visible: win.tabName === "greeter"
                    Hint { text: "gloxwaldgreet --test in tmux. Any password logs in and restarts it; F6/F7 restart it too. Click the stage to type." }
                    Hint { text: "cells: " + term.cols + "×" + term.rows }
                    DevButton {
                        label: "rebuild greeter"
                        onClicked: greeterJob.kick()
                    }
                }

                Column {
                    width: side.width
                    spacing: 6
                    visible: win.tabName === "grub"
                    Hint { text: "generate-assets.sh on a BIOS ISO in headless QEMU. Click the stage to send arrows, enter, e and c." }
                    Flow {
                        width: side.width
                        spacing: 4
                        DevButton {
                            label: "reboot vm"
                            onClicked: grub.reset()
                        }
                        DevButton {
                            label: "rebuild iso"
                            onClicked: grubJob.kick()
                        }
                    }
                }

                SectionTitle { text: "frame" }

                Flow {
                    width: side.width
                    spacing: 4
                    Repeater {
                        model: win.resolutions
                        DevButton {
                            required property var modelData
                            required property int index
                            label: modelData[0] + "×" + modelData[1]
                            accent: "#d9a530"
                            active: win.resIndex === index
                            onClicked: win.resIndex = index
                        }
                    }
                    DevButton {
                        label: win.fit ? "fit" : "1:1"
                        accent: "#d9a530"
                        active: !win.fit
                        onClicked: win.fit = !win.fit
                    }
                }

                SectionTitle { text: "theme" }

                Repeater {
                    model: win.themeKeys
                    ThemeField {}
                }

                DevButton {
                    label: "reset to installed theme"
                    onClicked: themeResetJob.kick()
                }

                SectionTitle { text: "actions" }

                Flow {
                    width: side.width
                    spacing: 4
                    DevButton {
                        label: "reload " + win.tabNames[win.tab] + "  ctrl+r"
                        onClicked: win.reloadTab()
                    }
                    DevButton {
                        label: "reload all"
                        onClicked: win.reloadAll()
                    }
                }
            }
        }

        Rectangle {
            id: logBox
            x: sidebar.atBottom ? win.sidebarWidth : 0
            y: sidebar.atBottom ? 1 : parent.height - height
            width: sidebar.atBottom ? parent.width - win.sidebarWidth : parent.width - 1
            height: sidebar.atBottom ? parent.height - 1 : win.logOpen ? Math.round(parent.height * 0.34) : logHeader.height
            color: "#0f0f13"

            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: "#2affffff"
            }

            Item {
                id: logHeader
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14 }
                height: 36

                SectionTitle {
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: 0
                    bottomPadding: 0
                    text: "log"
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    DevButton {
                        label: win.logAll ? "all" : win.tabNames[win.tab]
                        visible: win.logOpen
                        onClicked: win.logAll = !win.logAll
                    }
                    DevButton {
                        label: "clear"
                        visible: win.logOpen
                        onClicked: logModel.clear()
                    }
                    DevButton {
                        label: win.logOpen ? "hide" : "show"
                        onClicked: win.logOpen = !win.logOpen
                    }
                }
            }

            ListView {
                id: logView
                anchors { left: parent.left; right: parent.right; top: logHeader.bottom; bottom: parent.bottom; margins: 10; topMargin: 0 }
                visible: win.logOpen
                clip: true
                model: logModel
                onCountChanged: Qt.callLater(positionViewAtEnd)
                Connections {
                    target: win
                    function onLogAllChanged() { Qt.callLater(logView.positionViewAtEnd); }
                    function onTabChanged() { Qt.callLater(logView.positionViewAtEnd); }
                }
                delegate: Item {
                    id: entry
                    required property string src
                    required property string line
                    readonly property bool shown: win.logAll || win.tabSources[win.tabName].includes(src)
                    width: logView.width
                    height: shown ? entryText.implicitHeight : 0
                    visible: shown

                    Text {
                        id: entryText
                        width: parent.width
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        font.family: "monospace"
                        font.pixelSize: 11
                        color: ({ shader: "#3aa8b8", greeter: "#aad94c", grub: "#d9a530", theme: "#c792ea", dev: "#888888" })[entry.src] ?? "#cccccc"
                        text: (win.logAll ? entry.src.padEnd(8) : "") + entry.line
                    }
                }
            }
        }
    }

    Item {
        id: stage
        x: sidebar.atBottom ? 0 : sidebar.width
        width: parent.width - x
        height: sidebar.atBottom ? parent.height - sidebar.height : parent.height
        focus: true

        Item {
            anchors.fill: parent
            visible: win.tabName === "desktop"

            Flickable {
                id: deskView
                anchors.fill: parent
                clip: true
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                readonly property real fitScale: Math.min(width / win.frameW, height / win.frameH)
                property real zoom: fitScale
                property bool fitMode: true
                property real pinchBase: 1
                onFitScaleChanged: if (fitMode) zoom = fitScale
                contentWidth: win.frameW * zoom
                contentHeight: win.frameH * zoom
                leftMargin: Math.max(0, (width - contentWidth) / 2)
                rightMargin: leftMargin
                topMargin: Math.max(0, (height - contentHeight) / 2)
                bottomMargin: topMargin

                function fit() {
                    fitMode = true;
                    zoom = fitScale;
                    contentX = -leftMargin;
                    contentY = -topMargin;
                }

                function panTo(x, y) {
                    contentX = Math.max(-leftMargin, Math.min(x, contentWidth - width + rightMargin));
                    contentY = Math.max(-topMargin, Math.min(y, contentHeight - height + bottomMargin));
                }

                function zoomTo(z, px, py) {
                    z = Math.max(fitScale * 0.5, Math.min(16, z));
                    const cx = (contentX + px) / zoom;
                    const cy = (contentY + py) / zoom;
                    fitMode = false;
                    zoom = z;
                    contentX = Math.max(-leftMargin, Math.min(cx * z - px, contentWidth - width + rightMargin));
                    contentY = Math.max(-topMargin, Math.min(cy * z - py, contentHeight - height + bottomMargin));
                }

                QQC.ScrollBar.horizontal: QQC.ScrollBar {}
                QQC.ScrollBar.vertical: QQC.ScrollBar {}

                Item {
                    width: win.frameW
                    height: win.frameH
                    scale: deskView.zoom
                    transformOrigin: Item.TopLeft

                Loader {
                    id: desktopLoader
                    anchors.fill: parent
                    sourceComponent: Item {
                        readonly property vector2d screenSize: Qt.vector2d(win.frameW, win.frameH)
                        readonly property rect content: Qt.rect(T3.border, T3.band, win.frameW - 2 * T3.border, win.frameH - T3.band - T3.border)
                        readonly property int bleed: T3.windowBorder

                        ChromeSurface {
                            anchors.fill: parent
                            screenSize: parent.screenSize
                        }

                        Repeater {
                            model: win.mockWindows ? 2 : 0
                            Rectangle {
                                required property int index
                                readonly property rect c: parent.content
                                readonly property real w: (c.width + 2 * parent.bleed) / 2
                                x: c.x - parent.bleed + index * w
                                y: c.y - parent.bleed
                                width: w
                                height: c.height + 2 * parent.bleed
                                color: "#1c1a16"
                                border.color: "#43413d"
                                border.width: parent.bleed
                            }
                        }

                        ChromeSurface {
                            anchors.fill: parent
                            screenSize: parent.screenSize
                            overlayMode: 1
                        }

                        ChromeHeader {
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            height: T3.band
                            screenSize: parent.screenSize
                            monitor: Hyprland.focusedMonitor
                        }
                    }
                }
                }
            }

            Item {
                anchors.fill: deskView

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        win.lastWheel = "mods=" + wheel.modifiers + " angle=" + wheel.angleDelta.x + "," + wheel.angleDelta.y + " pixel=" + wheel.pixelDelta.x + "," + wheel.pixelDelta.y;
                        if (wheel.modifiers & Qt.ControlModifier) {
                            const d = wheel.angleDelta.y || wheel.pixelDelta.y;
                            deskView.zoomTo(deskView.zoom * Math.pow(1.25, d / 120), wheel.x, wheel.y);
                            return;
                        }
                        let dx = wheel.pixelDelta.x || wheel.angleDelta.x / 2;
                        let dy = wheel.pixelDelta.y || wheel.angleDelta.y / 2;
                        if ((wheel.modifiers & Qt.ShiftModifier) && dx === 0)
                            [dx, dy] = [dy, 0];
                        deskView.panTo(deskView.contentX - dx, deskView.contentY - dy);
                    }
                }

                PinchHandler {
                    target: null
                    onActiveChanged: if (active) deskView.pinchBase = deskView.zoom
                    onActiveScaleChanged: if (active) deskView.zoomTo(deskView.pinchBase * activeScale, centroid.position.x, centroid.position.y)
                }

                TapHandler {
                    onDoubleTapped: deskView.fit()
                }

                DragHandler {
                    target: null
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    property point start
                    cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                    onActiveChanged: if (active) start = Qt.point(deskView.contentX, deskView.contentY)
                    onActiveTranslationChanged: if (active) deskView.panTo(start.x - activeTranslation.x, start.y - activeTranslation.y)
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: win.tabName === "bar"

            BarGallery {
                id: gallery
                anchors.fill: parent
                frameW: win.frameW
                zoom: win.barZoom
                active: win.tabName === "bar"
            }
        }

        Item {
            anchors.fill: parent
            visible: win.tabName === "lock"

            Frame {
                LockSurface {
                    anchors.fill: parent
                    context: lockCtx
                    sceneRev: win.sceneRev
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: win.tabName === "greeter"

            Frame {
                TermView {
                    id: term
                    anchors.fill: parent
                    active: win.tabName === "greeter"
                    fg: Theme.app600
                    bg: Theme.app100
                    fontFamily: win.theme.fontFamily ?? "monospace"
                    onColsChanged: termResize.restart()
                    onRowsChanged: termResize.restart()
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: win.tabName === "grub"

            Frame {
                GrubView {
                    id: grub
                    anchors.fill: parent
                    devDir: win.devDir
                    active: win.tabName === "grub"
                }
            }
        }
    }
}
