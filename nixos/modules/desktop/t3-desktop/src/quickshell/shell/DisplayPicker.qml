import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool open: false
    property string output: ""
    property string mode: ""
    property int selected: 0
    property bool confirming: false
    property int left: 0
    readonly property int grace: 15

    readonly property var choices: [
        { icon: "\u{f037a}", label: "extend right", hint: "external right of laptop", args: ["extend", "right"], mode: "extend" },
        { icon: "\u{f037a}", label: "extend left", hint: "external left of laptop", args: ["extend", "left"], mode: "" },
        { icon: "\u{f037a}", label: "extend above", hint: "external above laptop", args: ["extend", "above"], mode: "" },
        { icon: "\u{f11fd}", label: "mirror", hint: "everything shows the laptop", args: ["mirror"], mode: "mirror" },
        { icon: "\u{f06e7}", label: "external only", hint: "laptop screen off", args: ["external"], mode: "external" },
        { icon: "\u{f0322}", label: "laptop only", hint: "external screens off", args: ["internal"], mode: "internal" },
        { icon: "\u{f06b0}", label: "saved layout", hint: "restore the layout saved for these screens", args: ["restore"], mode: "" }
    ]

    function toggle() {
        if (confirming)
            return;
        if (open) {
            open = false;
            return;
        }
        output = Hyprland.focusedMonitor?.name ?? "";
        mode = "";
        selected = 0;
        probe.running = true;
        open = true;
    }

    function pick(i) {
        if (i < 0 || i >= choices.length)
            return;
        open = false;
        apply.command = ["sh", "-c", "t3os settings display snapshot && exec t3os settings display \"$@\" -n", "sh"].concat(choices[i].args);
        apply.running = true;
    }

    function keep() {
        confirming = false;
        countdown.stop();
    }

    function revert() {
        confirming = false;
        countdown.stop();
        Quickshell.execDetached(["t3os", "settings", "display", "undo", "-n"]);
    }

    Process {
        id: apply
        onExited: code => {
            if (code !== 0)
                return;
            root.left = root.grace;
            root.confirming = true;
            countdown.restart();
        }
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.left -= 1;
            if (root.left <= 0)
                root.revert();
        }
    }

    Process {
        id: probe
        command: ["t3os", "settings", "display", "status"]
        stdout: SplitParser {
            onRead: data => {
                const m = /^mode: (\S+)/.exec(data);
                if (!m)
                    return;
                root.mode = m[1];
                const i = root.choices.findIndex(c => c.mode === m[1]);
                if (i >= 0)
                    root.selected = i;
            }
        }
    }

    IpcHandler {
        target: "display"
        function toggle(): void { root.toggle(); }
    }

    component Label: Text {
        color: T3.accent2
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool here: root.open && (root.output === modelData.name || (root.output === "" && modelData === Quickshell.screens[0]))

            screen: modelData
            visible: here
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: card.width
            implicitHeight: card.height
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "t3-desktop-display-picker"
            WlrLayershell.keyboardFocus: here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onHereChanged: if (here) keys.forceActiveFocus()

            Rectangle {
                id: card
                width: 380
                height: col.implicitHeight + 2 * 14
                radius: T3.radius
                color: Theme.app100
                border.width: 2
                border.color: T3.accent2

                Item {
                    id: keys
                    focus: win.here
                    Keys.onPressed: event => {
                        const n = parseInt(event.text);
                        if (n >= 1 && n <= root.choices.length)
                            root.pick(n - 1);
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab)
                            root.selected = (root.selected + 1) % root.choices.length;
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab)
                            root.selected = (root.selected + root.choices.length - 1) % root.choices.length;
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                            root.pick(root.selected);
                        else if (event.key === Qt.Key_Escape)
                            root.open = false;
                        else
                            return;
                        event.accepted = true;
                    }
                }

                Column {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 4

                    Label {
                        text: "\u{f0379}  displays" + (root.mode ? "  ·  now " + root.mode : "")
                        bottomPadding: 6
                    }

                    Repeater {
                        model: root.choices.length

                        Rectangle {
                            id: row
                            required property int index
                            readonly property var c: root.choices[index]
                            readonly property bool active: root.selected === index
                            width: col.width
                            height: 34
                            radius: 6
                            color: active ? Theme.app150 : "transparent"
                            border.width: 1
                            border.color: active ? T3.accent2 : "transparent"

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                spacing: 10

                                Label {
                                    text: String(row.index + 1)
                                    opacity: 0.55
                                    width: 10
                                }

                                Text {
                                    text: row.c.icon
                                    color: T3.accent2
                                    width: 20
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.round(T3.labelSize * 1.4)
                                }

                                Column {
                                    Label {
                                        text: row.c.label
                                    }

                                    Text {
                                        text: row.c.hint
                                        color: T3.accent2
                                        opacity: 0.55
                                        font.family: Theme.fontFamily
                                        font.pixelSize: T3.labelSize - 1
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selected = row.index
                                onClicked: root.pick(row.index)
                            }
                        }
                    }

                    Label {
                        topPadding: 6
                        text: "1-7 or enter picks · esc closes"
                        opacity: 0.55
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ask
            required property var modelData
            readonly property bool focusHere: modelData.name === (Hyprland.focusedMonitor?.name ?? "")

            screen: modelData
            visible: root.confirming
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: prompt.width
            implicitHeight: prompt.height
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "t3-desktop-display-confirm"
            WlrLayershell.keyboardFocus: root.confirming && focusHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onVisibleChanged: if (visible) answer.forceActiveFocus()
            onFocusHereChanged: if (visible && focusHere) answer.forceActiveFocus()

            Rectangle {
                id: prompt
                width: 380
                height: lines.implicitHeight + 2 * 14
                radius: T3.radius
                color: Theme.app100
                border.width: 2
                border.color: T3.accent2

                Item {
                    id: answer
                    focus: root.confirming
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Y)
                            root.keep();
                        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_N || event.key === Qt.Key_Backspace)
                            root.revert();
                        else
                            return;
                        event.accepted = true;
                    }
                }

                Column {
                    id: lines
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Label {
                        text: "\u{f037a}  keep this layout?"
                    }

                    Text {
                        width: parent.width
                        text: "Reverting in " + root.left + "s"
                        color: T3.accent2
                        font.family: Theme.fontFamily
                        font.pixelSize: T3.titleSize
                    }

                    Rectangle {
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.app150

                        Rectangle {
                            width: parent.width * root.left / root.grace
                            height: parent.height
                            radius: 2
                            color: T3.accent2
                            Behavior on width {
                                NumberAnimation { duration: 1000 }
                            }
                        }
                    }

                    Row {
                        spacing: 8

                        Repeater {
                            model: [["keep", "enter"], ["revert", "esc"]]

                            Rectangle {
                                required property var modelData
                                width: 120
                                height: 30
                                radius: 6
                                color: Theme.app150
                                border.width: 1
                                border.color: keepHover.containsMouse ? T3.accent2 : Theme.app700

                                Label {
                                    anchors.centerIn: parent
                                    text: parent.modelData[0] + "  ·  " + parent.modelData[1]
                                }

                                MouseArea {
                                    id: keepHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.modelData[0] === "keep" ? root.keep() : root.revert()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
