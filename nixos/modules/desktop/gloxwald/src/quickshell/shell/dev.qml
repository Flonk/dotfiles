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
            greeterJob.kick();
            grubJob.kick();
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

    component Sep: Rectangle {
        width: 1
        height: 22
        color: "#33ffffff"
    }

    component ThemeField: Row {
        id: tf
        required property var modelData
        readonly property string key: modelData[0]
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 3
            color: win.theme[tf.key] ?? "#000000"
            border.color: "#55ffffff"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: tf.modelData[1]
            color: "#99ffffff"
            font.pixelSize: 11
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 74
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
        id: toolbar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: tools.implicitHeight + 16
        color: "#18181d"

        Flow {
            id: tools
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
            spacing: 6

            Repeater {
                model: win.tabNames
                DevButton {
                    required property string modelData
                    required property int index
                    label: (index + 1) + " " + modelData
                    active: win.tab === index
                    onClicked: win.tab = index
                }
            }

            Sep {}

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

            Sep {}

            Repeater {
                model: win.themeKeys
                ThemeField {}
            }

            DevButton {
                label: "reset theme"
                onClicked: themeResetJob.kick()
            }

            Sep {}

            DevButton {
                label: "reload " + win.tabNames[win.tab]
                onClicked: win.reloadTab()
            }

            DevButton {
                label: "reload all"
                onClicked: win.reloadAll()
            }

            DevButton {
                label: "log"
                active: win.logOpen
                onClicked: win.logOpen = !win.logOpen
            }
        }
    }

    Item {
        id: stage
        anchors { left: parent.left; right: parent.right; top: toolbar.bottom; bottom: logPane.top }
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

            LockDevPanel {
                anchors.fill: parent
                context: lockCtx
                showRelock: true
                onRestart: win.sceneRev++
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

    Rectangle {
        id: logPane
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: win.logOpen ? 180 : 0
        visible: win.logOpen
        color: "#0a0a0d"

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1
            color: "#33ffffff"
        }

        ListView {
            id: logView
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            model: logModel
            onCountChanged: positionViewAtEnd()
            delegate: Text {
                required property string src
                required property string line
                width: logView.width
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "monospace"
                font.pixelSize: 12
                color: ({ shader: "#3aa8b8", greeter: "#aad94c", grub: "#d9a530", theme: "#c792ea", dev: "#888888" })[src] ?? "#cccccc"
                text: src.padEnd(8) + line
            }
        }
    }
}
