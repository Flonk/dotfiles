import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property string tmuxSocket: "gloxwald-dev"
    property string session: "greeter"
    property bool active: true
    property color fg: "#e6e1cf"
    property color bg: "#0b0e14"
    property string fontFamily: "monospace"
    property real fontPointSize: 20

    readonly property real cellW: fm.advanceWidth("M")
    readonly property real cellH: fm.lineSpacing
    readonly property int cols: Math.max(20, Math.floor(width / cellW))
    readonly property int rows: Math.max(5, Math.floor(height / cellH))

    property var lines: []
    property int cursorX: 0
    property int cursorY: 0
    property bool cursorVisible: false
    property bool running: false

    activeFocusOnTab: true

    FontMetrics {
        id: fm
        font.family: root.fontFamily
        font.pointSize: root.fontPointSize
    }

    Rectangle {
        anchors.fill: parent
        color: root.bg
    }

    Repeater {
        model: root.rows
        Text {
            required property int index
            y: index * root.cellH
            height: root.cellH
            textFormat: Text.RichText
            font.family: root.fontFamily
            font.pointSize: root.fontPointSize
            color: root.fg
            text: root.lines[index] ?? ""
        }
    }

    Rectangle {
        visible: root.cursorVisible
        x: root.cursorX * root.cellW
        y: root.cursorY * root.cellH
        width: root.cellW
        height: root.cellH
        color: root.fg
        opacity: 0.6
    }

    Text {
        anchors.centerIn: parent
        visible: !root.running
        text: "greeter not running"
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

    readonly property var palette16: ["#000000", "#cd0000", "#00cd00", "#cdcd00", "#0000ee", "#cd00cd", "#00cdcd", "#e5e5e5", "#7f7f7f", "#ff0000", "#00ff00", "#ffff00", "#5c5cff", "#ff00ff", "#00ffff", "#ffffff"]

    function hex2(n) {
        return (n < 16 ? "0" : "") + n.toString(16);
    }

    function rgb(r, g, b) {
        return "#" + hex2(r) + hex2(g) + hex2(b);
    }

    function color256(n) {
        if (n < 16)
            return palette16[n];
        if (n < 232) {
            const c = n - 16, v = x => x === 0 ? 0 : 55 + x * 40;
            return rgb(v(Math.floor(c / 36)), v(Math.floor(c / 6) % 6), v(c % 6));
        }
        const g = 8 + (n - 232) * 10;
        return rgb(g, g, g);
    }

    function escapeText(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/ /g, "&nbsp;");
    }

    function applySgr(st, params) {
        const p = params.length ? params.split(/[;:]/).map(x => x === "" ? 0 : parseInt(x)) : [0];
        for (let i = 0; i < p.length; i++) {
            const c = p[i];
            if (c === 0) {
                st.fg = null; st.bg = null; st.bold = false; st.italic = false; st.under = false; st.rev = false; st.faint = false;
            } else if (c === 1) st.bold = true;
            else if (c === 2) st.faint = true;
            else if (c === 3) st.italic = true;
            else if (c === 4) st.under = true;
            else if (c === 7) st.rev = true;
            else if (c === 22) { st.bold = false; st.faint = false; }
            else if (c === 23) st.italic = false;
            else if (c === 24) st.under = false;
            else if (c === 27) st.rev = false;
            else if (c >= 30 && c <= 37) st.fg = palette16[c - 30];
            else if (c >= 90 && c <= 97) st.fg = palette16[c - 82];
            else if (c >= 40 && c <= 47) st.bg = palette16[c - 40];
            else if (c >= 100 && c <= 107) st.bg = palette16[c - 92];
            else if (c === 39) st.fg = null;
            else if (c === 49) st.bg = null;
            else if (c === 38 || c === 48) {
                let col = null;
                if (p[i + 1] === 5) { col = color256(p[i + 2]); i += 2; }
                else if (p[i + 1] === 2) { col = rgb(p[i + 2], p[i + 3], p[i + 4]); i += 4; }
                if (c === 38) st.fg = col; else st.bg = col;
            }
        }
    }

    function lineToHtml(line) {
        const st = { fg: null, bg: null, bold: false, italic: false, under: false, rev: false, faint: false };
        let out = "";
        const re = /\x1b\[([0-9;:?]*)([A-Za-z])/g;
        let last = 0, m;
        const emit = s => {
            if (!s)
                return;
            const fg = st.rev ? (st.bg ?? String(root.bg)) : st.fg;
            const bg = st.rev ? (st.fg ?? String(root.fg)) : st.bg;
            let style = "";
            if (fg) style += "color:" + fg + ";";
            if (bg) style += "background-color:" + bg + ";";
            if (st.bold) style += "font-weight:bold;";
            if (st.italic) style += "font-style:italic;";
            if (st.under) style += "text-decoration:underline;";
            const t = escapeText(s);
            out += style ? "<span style=\"" + style + "\">" + t + "</span>" : t;
        };
        while ((m = re.exec(line)) !== null) {
            emit(line.slice(last, m.index));
            if (m[2] === "m")
                applySgr(st, m[1]);
            last = re.lastIndex;
        }
        emit(line.slice(last));
        return out;
    }

    function parse(text) {
        const all = text.split("\n");
        const head = (all.shift() ?? "").split(" ");
        if (head.length < 4) {
            running = false;
            lines = [];
            return;
        }
        running = head[3] !== "1";
        cursorX = parseInt(head[0]);
        cursorY = parseInt(head[1]);
        cursorVisible = head[2] === "1";
        lines = all.slice(0, rows).map(lineToHtml);
    }

    Process {
        id: capture
        command: ["sh", "-c", "tmux -L " + root.tmuxSocket + " display -p -t " + root.session + " '#{cursor_x} #{cursor_y} #{cursor_flag} #{pane_dead}' && tmux -L " + root.tmuxSocket + " capture-pane -p -e -N -t " + root.session]
        stdout: StdioCollector {
            onStreamFinished: root.parse(this.text)
        }
    }

    Timer {
        interval: 80
        running: root.active
        repeat: true
        onTriggered: if (!capture.running) capture.running = true
    }

    property var keyQueue: []

    Process {
        id: sender
        onExited: root.flushKeys()
    }

    function flushKeys() {
        if (sender.running || keyQueue.length === 0)
            return;
        sender.command = ["tmux", "-L", tmuxSocket, "send-keys", "-t", session].concat(keyQueue);
        keyQueue = [];
        sender.running = true;
    }

    readonly property var specialKeys: ({
        [Qt.Key_Return]: "Enter",
        [Qt.Key_Enter]: "Enter",
        [Qt.Key_Backspace]: "BSpace",
        [Qt.Key_Tab]: "Tab",
        [Qt.Key_Backtab]: "BTab",
        [Qt.Key_Escape]: "Escape",
        [Qt.Key_Up]: "Up",
        [Qt.Key_Down]: "Down",
        [Qt.Key_Left]: "Left",
        [Qt.Key_Right]: "Right",
        [Qt.Key_Home]: "Home",
        [Qt.Key_End]: "End",
        [Qt.Key_Delete]: "DC",
        [Qt.Key_Insert]: "IC",
        [Qt.Key_PageUp]: "PPage",
        [Qt.Key_PageDown]: "NPage"
    })

    function keyName(event) {
        if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F12)
            return "F" + (event.key - Qt.Key_F1 + 1);
        if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return "C-" + String.fromCharCode(97 + event.key - Qt.Key_A);
        if (specialKeys[event.key])
            return specialKeys[event.key];
        const t = event.text;
        if (!t || t.charCodeAt(0) < 32)
            return null;
        if (t === " ")
            return "Space";
        if (t === ";")
            return "\\;";
        return t;
    }

    Keys.onPressed: event => {
        const k = keyName(event);
        if (k === null)
            return;
        keyQueue = keyQueue.concat([k]);
        flushKeys();
        event.accepted = true;
    }
}
