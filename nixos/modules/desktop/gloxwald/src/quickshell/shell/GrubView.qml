import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    required property string devDir
    property bool active: true
    onActiveChanged: syncRunState()

    function syncRunState() {
        if (ready)
            send({ execute: active ? "cont" : "stop" });
    }

    property bool ready: false
    property bool waiting: false
    property int shot: 0
    property Item front: imgA

    activeFocusOnTab: true

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Image {
        id: imgA
        anchors.fill: parent
        cache: false
        asynchronous: true
        visible: root.front === imgA
        onStatusChanged: if (status === Image.Ready) root.front = imgA
    }

    Image {
        id: imgB
        anchors.fill: parent
        cache: false
        asynchronous: true
        visible: root.front === imgB
        onStatusChanged: if (status === Image.Ready) root.front = imgB
    }

    Text {
        anchors.centerIn: parent
        visible: !root.ready
        text: "waiting for qemu…"
        color: "#88ffffff"
        font.pixelSize: 32
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 4
        border.color: root.activeFocus ? "#553aa8b8" : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.forceActiveFocus()
    }

    function send(obj) {
        qmp.write(JSON.stringify(obj) + "\n");
        qmp.flush();
    }

    function shotPath(n) {
        return devDir + "/grub-" + (n % 2) + ".png";
    }

    function onMessage(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (m.id === "caps") {
            ready = true;
            syncRunState();
        } else if (typeof m.id === "string" && m.id.startsWith("shot")) {
            waiting = false;
            if (m.return !== undefined) {
                const n = parseInt(m.id.slice(4));
                (front === imgA ? imgB : imgA).source = "file://" + shotPath(n) + "?" + n;
            }
        }
    }

    Socket {
        id: qmp
        path: root.devDir + "/qmp.sock"
        parser: SplitParser {
            onRead: data => root.onMessage(data)
        }
        onConnectedChanged: {
            root.ready = false;
            root.waiting = false;
            if (connected)
                root.send({ execute: "qmp_capabilities", id: "caps" });
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (root.ready)
                return;
            qmp.connected = false;
            qmp.connected = true;
        }
    }

    Timer {
        interval: 150
        running: root.active && root.ready
        repeat: true
        onTriggered: {
            if (root.waiting)
                return;
            root.shot++;
            root.waiting = true;
            root.send({ execute: "screendump", id: "shot" + root.shot, arguments: { filename: root.shotPath(root.shot), format: "png" } });
        }
    }

    function reset() {
        if (ready)
            send({ execute: "system_reset" });
    }

    readonly property var namedKeys: ({
        [Qt.Key_Return]: "ret",
        [Qt.Key_Enter]: "kp_enter",
        [Qt.Key_Escape]: "esc",
        [Qt.Key_Backspace]: "backspace",
        [Qt.Key_Tab]: "tab",
        [Qt.Key_Backtab]: "tab",
        [Qt.Key_Space]: "spc",
        [Qt.Key_Up]: "up",
        [Qt.Key_Down]: "down",
        [Qt.Key_Left]: "left",
        [Qt.Key_Right]: "right",
        [Qt.Key_Home]: "home",
        [Qt.Key_End]: "end",
        [Qt.Key_PageUp]: "pgup",
        [Qt.Key_PageDown]: "pgdn",
        [Qt.Key_Delete]: "delete",
        [Qt.Key_Minus]: "minus",
        [Qt.Key_Equal]: "equal",
        [Qt.Key_Comma]: "comma",
        [Qt.Key_Period]: "dot",
        [Qt.Key_Slash]: "slash",
        [Qt.Key_Semicolon]: "semicolon",
        [Qt.Key_Apostrophe]: "apostrophe",
        [Qt.Key_BracketLeft]: "bracket_left",
        [Qt.Key_BracketRight]: "bracket_right",
        [Qt.Key_Backslash]: "backslash"
    })

    function qcodes(event) {
        const k = event.key;
        let base = null;
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            base = String.fromCharCode(97 + k - Qt.Key_A);
        else if (k >= Qt.Key_0 && k <= Qt.Key_9)
            base = String.fromCharCode(48 + k - Qt.Key_0);
        else if (k >= Qt.Key_F1 && k <= Qt.Key_F12)
            base = "f" + (k - Qt.Key_F1 + 1);
        else
            base = namedKeys[k] ?? null;
        if (base === null)
            return null;
        const keys = [];
        if (event.modifiers & Qt.ControlModifier) keys.push("ctrl");
        if (event.modifiers & Qt.AltModifier) keys.push("alt");
        if ((event.modifiers & Qt.ShiftModifier) || k === Qt.Key_Backtab) keys.push("shift");
        keys.push(base);
        return keys;
    }

    Keys.onPressed: event => {
        const keys = qcodes(event);
        if (keys === null || !ready)
            return;
        send({ execute: "send-key", arguments: { keys: keys.map(d => ({ type: "qcode", data: d })) } });
        event.accepted = true;
    }
}
