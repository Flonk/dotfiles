import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property var queue: []
    readonly property var current: queue.length > 0 ? queue[0] : null

    function ask(prompt, channel, secret) {
        queue = queue.concat([{ prompt: prompt.trim(), channel: channel, secret: secret, output: Hyprland.focusedMonitor?.name ?? "" }]);
    }

    function dismiss(channel) {
        queue = queue.filter(r => r.channel !== channel);
    }

    function answer(line) {
        const r = current;
        if (!r)
            return;
        writer.createObject(root, { channel: r.channel, line: line });
        dismiss(r.channel);
    }

    Component {
        id: writer

        Process {
            required property string channel
            required property string line

            command: ["sh", "-c", "cat > \"$1\"", "sh", channel]
            stdinEnabled: true
            running: true
            onStarted: {
                write(line + "\n");
                stdinEnabled = false;
            }
            onExited: destroy()
        }
    }

    IpcHandler {
        target: "askpass"
        function ask(prompt: string, channel: string, secret: bool): void { root.ask(prompt, channel, secret); }
        function dismiss(channel: string): void { root.dismiss(channel); }
    }

    component Label: Text {
        color: T3.ink
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
            readonly property var r: root.current
            readonly property bool here: r !== null && (r.output === modelData.name || (r.output === "" && modelData === Quickshell.screens[0]))

            screen: modelData
            visible: here
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: card.width
            implicitHeight: card.height
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "t3-desktop-askpass"
            WlrLayershell.keyboardFocus: here ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onRChanged: {
                input.text = "";
                if (here)
                    input.forceActiveFocus();
            }

            Rectangle {
                id: card
                width: 380
                height: col.implicitHeight + 2 * 14
                radius: T3.radius
                color: T3.accent2
                border.width: 1
                border.color: T3.lighten(T3.accent2, 0.25)

                Column {
                    id: col
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Row {
                        width: parent.width
                        spacing: 8

                        Label {
                            text: win.r && win.r.secret ? "\u{f0306}  password" : "\u{f02fd}  confirm"
                        }

                        Label {
                            visible: root.queue.length > 1
                            text: "+" + (root.queue.length - 1)
                            opacity: 0.55
                        }
                    }

                    Text {
                        width: parent.width
                        text: win.r ? win.r.prompt : ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        color: T3.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: T3.titleSize
                    }

                    Rectangle {
                        width: parent.width
                        height: 30
                        radius: 6
                        color: T3.ink
                        border.width: 1
                        border.color: input.activeFocus ? T3.cream : T3.lighten(T3.ink, 0.25)

                        TextInput {
                            id: input
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            focus: win.here
                            echoMode: win.r && win.r.secret ? TextInput.Password : TextInput.Normal
                            passwordCharacter: "•"
                            color: T3.cream
                            selectionColor: T3.accent2
                            font.family: Theme.fontFamily
                            font.pixelSize: T3.titleSize
                            Keys.onReturnPressed: root.answer("+" + text)
                            Keys.onEnterPressed: root.answer("+" + text)
                            Keys.onEscapePressed: root.answer("-")
                        }
                    }

                    Label {
                        text: "enter submits · esc cancels"
                        opacity: 0.55
                    }
                }
            }
        }
    }
}
