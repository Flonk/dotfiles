import QtQuick
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

    readonly property var tabNames: ["bar", "lock", "greeter", "grub"]
    property int tab: Math.max(0, tabNames.indexOf(Quickshell.env("GLOXWALD_TAB") || "lock"))

    readonly property var resolutions: [[1920, 1200], [1920, 1080], [2560, 1440], [1280, 800]]
    property int resIndex: 0
    readonly property int frameW: resolutions[resIndex][0]
    readonly property int frameH: resolutions[resIndex][1]
    property bool fit: true
    property bool logOpen: true
    property bool logAll: false
    readonly property int sidebarWidth: 330
    readonly property var tabSources: [["dev", "theme"], ["dev", "theme", "shader"], ["dev", "theme", "greeter"], ["dev", "theme", "grub"]]
    property int sceneRev: 0

    property var theme: ({})
    readonly property var themeKeys: [["app100", "bg"], ["app150", "bg active"], ["app600", "fg"], ["wm800", "accent"]]

    onTabChanged: Qt.callLater(focusTab)
    onResIndexChanged: grubJob.kick()

    function focusTab() {
        if (tab === 2) term.forceActiveFocus();
        else if (tab === 3) grub.forceActiveFocus();
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
        if (tab === 0) {
            barLoader.active = false;
            barLoader.active = true;
        } else if (tab === 1) {
            sceneRev++;
            lockCtx.reset();
        } else if (tab === 2) {
            greeterJob.kick();
        } else {
            grubJob.kick();
        }
        log("dev", "reload " + tabNames[tab]);
    }

    function reloadAll() {
        barLoader.active = false;
        barLoader.active = true;
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
        function state(): string {
            return JSON.stringify({ tab: win.tabNames[win.tab], grubReady: grub.ready, greeterRunning: term.running, cols: term.cols, rows: term.rows });
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
    Shortcut { sequence: "Ctrl+R"; context: Qt.ApplicationShortcut; onActivated: win.reloadTab() }
    Shortcut { sequence: "Ctrl+Shift+R"; context: Qt.ApplicationShortcut; onActivated: win.reloadAll() }
    Shortcut { sequence: "Ctrl+L"; context: Qt.ApplicationShortcut; onActivated: win.logOpen = !win.logOpen }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; onActivated: win.fit = !win.fit }

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
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: win.sidebarWidth
        color: "#18181d"

        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: 1
            color: "#2affffff"
        }

        Flickable {
            id: sideScroll
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: logBox.top }
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
                    visible: win.tab === 0
                    Hint { text: "The real BarContent at the bottom of the frame; workspaces follow the focused Hyprland monitor." }
                }

                Column {
                    width: side.width
                    spacing: 10
                    visible: win.tab === 1
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
                    visible: win.tab === 2
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
                    visible: win.tab === 3
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
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; rightMargin: 1 }
            height: win.logOpen ? Math.round(sidebar.height * 0.34) : logHeader.height
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
                delegate: Text {
                    required property string src
                    required property string line
                    readonly property bool shown: win.logAll || win.tabSources[win.tab].includes(src)
                    width: logView.width
                    height: shown ? implicitHeight : 0
                    visible: shown
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    font.family: "monospace"
                    font.pixelSize: 11
                    color: ({ shader: "#3aa8b8", greeter: "#aad94c", grub: "#d9a530", theme: "#c792ea", dev: "#888888" })[src] ?? "#cccccc"
                    text: (win.logAll ? src.padEnd(8) : "") + line
                }
            }
        }
    }

    Item {
        id: stage
        anchors { left: sidebar.right; right: parent.right; top: parent.top; bottom: parent.bottom }
        focus: true

        Item {
            anchors.fill: parent
            visible: win.tab === 0

            Frame {
                Rectangle {
                    anchors.fill: parent
                    color: Theme.app100
                }

                Loader {
                    id: barLoader
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 20
                    sourceComponent: BarContent {
                        monitor: Hyprland.focusedMonitor
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            visible: win.tab === 1

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
            visible: win.tab === 2

            Frame {
                TermView {
                    id: term
                    anchors.fill: parent
                    active: win.tab === 2
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
            visible: win.tab === 3

            Frame {
                GrubView {
                    id: grub
                    anchors.fill: parent
                    devDir: win.devDir
                    active: win.tab === 3
                }
            }
        }
    }
}
