import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property string phase: ""
    property string fifo: ""
    property string hover: ""
    property string target: ""
    property bool shift: false
    property bool full: false
    property bool advanced: false
    property var sel: null
    property var cam: null
    property var lastCam: null
    property int count: 0
    property int frames: 0
    property bool sawSession: false
    property var sink: null
    property bool optCam: false
    property bool optMic: false
    property bool optSys: true
    property bool optLive: false
    property bool livePending: false
    readonly property bool previewing: livePending || (Theme.twitch && optLive && (phase === "adjust" || phase === "wait" || phase === "count"))
    property string title: ""
    property bool titleFetched: false

    readonly property bool ready: frames >= 10
    readonly property bool interactive: phase === "pick" || phase === "adjust"
    readonly property bool framed: phase === "adjust" || phase === "wait" || phase === "count"
    readonly property bool focused: interactive || phase === "wait" || phase === "count"

    function pick(path) {
        if (phase !== "") {
            write(path, { cancel: true, busy: true });
            return;
        }
        fifo = path;
        sel = null;
        cam = null;
        lastCam = null;
        full = false;
        shift = false;
        sawSession = false;
        target = "";
        phase = "pick";
    }

    function write(path, obj) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "sh", JSON.stringify(obj), path]);
    }

    function reset() {
        tick.stop();
        phase = "";
        cam = null;
        sel = null;
        shift = false;
    }

    function cancel() {
        if (fifo)
            write(fifo, { cancel: true });
        fifo = "";
        reset();
    }

    function screenOf(name) {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    function defaultCam(r) {
        const m = Math.min(r.w, r.h);
        const s = Math.round(Math.min(m, Math.max(64, m * (full ? 0.22 : 0.3))));
        const pad = Math.min(full ? 32 : 16, Math.max(0, Math.floor((m - s) / 2)));
        return { x: r.x + r.w - s - pad, y: r.y + pad, s: s };
    }

    function toggleCam() {
        optCam = !optCam;
        if (phase !== "adjust")
            return;
        if (optCam)
            cam = fitCam(lastCam, sel) ?? defaultCam(sel);
        else {
            lastCam = cam;
            cam = null;
        }
    }

    function toggleLive() {
        optLive = !optLive;
        if (optLive && !titleFetched) {
            titleFetched = true;
            titleFetch.running = true;
        }
    }

    function whole(advanced) {
        const scr = screenOf(hover) ?? Quickshell.screens[0];
        region({ x: 0, y: 0, w: scr.width, h: scr.height }, scr.name, advanced, true);
    }

    function region(r, screenName, advanced, isFull) {
        target = screenName;
        full = !!isFull;
        root.advanced = advanced;
        sel = r;
        if (advanced) {
            cam = optCam ? defaultCam(r) : null;
            phase = "adjust";
        } else {
            cam = null;
            finish();
        }
    }

    function fitCam(c, r) {
        if (!c)
            return null;
        const s = Math.max(Math.min(48, r.w, r.h), Math.min(c.s, r.w, r.h));
        return {
            x: Math.max(r.x, Math.min(r.x + r.w - s, c.x)),
            y: Math.max(r.y, Math.min(r.y + r.h - s, c.y)),
            s: s
        };
    }

    function reshape(start, dx, dy, edge, W, H) {
        const min = 48;
        let x = start.x, y = start.y, r = start.x + start.w, b = start.y + start.h;
        if (edge === "move") {
            x = Math.max(0, Math.min(W - start.w, x + dx));
            y = Math.max(0, Math.min(H - start.h, y + dy));
            r = x + start.w;
            b = y + start.h;
        } else {
            if (edge.includes("l"))
                x = Math.max(0, Math.min(r - min, x + dx));
            if (edge.includes("r"))
                r = Math.max(x + min, Math.min(W, r + dx));
            if (edge.includes("t"))
                y = Math.max(0, Math.min(b - min, y + dy));
            if (edge.includes("b"))
                b = Math.max(y + min, Math.min(H, b + dy));
        }
        const old = sel;
        const n = { x: Math.round(x), y: Math.round(y), w: Math.round(r - x), h: Math.round(b - y) };
        sel = n;
        full = n.x === 0 && n.y === 0 && n.w === W && n.h === H;
        if (cam) {
            const moved = edge === "move" ? { x: cam.x + n.x - old.x, y: cam.y + n.y - old.y, s: cam.s } : cam;
            cam = fitCam(moved, n);
        }
    }

    function confirm() {
        if (phase !== "adjust")
            return;
        phase = "wait";
        go();
    }

    function go() {
        if (phase === "wait" && (cam === null || ready)) {
            phase = "count";
            count = 3;
            tick.restart();
        }
    }

    function finish() {
        const scr = screenOf(target);
        const r = sel;
        const c = cam;
        const out = {
            output: target,
            full: full,
            x: Math.round(scr.x + r.x),
            y: Math.round(scr.y + r.y),
            w: Math.round(r.w),
            h: Math.round(r.h),
            mic: advanced ? optMic : false,
            sys: advanced ? optSys : true,
            live: advanced && optLive && Theme.twitch,
            title: title,
            cam: c ? { x: Math.round(scr.x + c.x), y: Math.round(scr.y + c.y), s: Math.round(c.s) } : null
        };
        livePending = out.live;
        if (out.live)
            pending.restart();
        phase = c ? "rec" : "hand";
        handoff.payload = out;
        handoff.restart();
    }

    onReadyChanged: go()

    Binding {
        target: TwitchMode
        property: "preview"
        value: root.previewing
    }

    Timer {
        id: pending
        interval: 20000
        onTriggered: root.livePending = false
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.count -= 1;
            if (root.count <= 0) {
                stop();
                root.finish();
            }
        }
    }

    Timer {
        id: handoff
        property var payload: null
        interval: 250
        onTriggered: {
            root.write(root.fifo, payload);
            root.fifo = "";
            if (root.phase === "hand")
                root.reset();
            else
                orphan.restart();
        }
    }

    Timer {
        id: orphan
        interval: 20000
        onTriggered: if (root.phase === "rec" && !root.sawSession) root.reset()
    }

    Process {
        id: feed
        running: true
        command: ["mosquitto_sub", "-h", "127.0.0.1", "-t", "screen/record/state"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().startsWith("{"))
                    root.livePending = false;
                if (root.phase !== "rec")
                    return;
                if (data.trim().startsWith("{"))
                    root.sawSession = true;
                else if (root.sawSession)
                    root.reset();
            }
        }
        onExited: retry.start()
    }

    Timer {
        id: retry
        interval: 5000
        onTriggered: feed.running = true
    }

    Process {
        id: titleFetch
        command: ["t3os", "twitch", "title"]
        stdout: StdioCollector {
            onStreamFinished: if (root.title === "") root.title = text.trim()
        }
    }

    MediaDevices {
        id: devices
    }

    CaptureSession {
        id: capture
        camera: Camera {
            id: camera
            cameraDevice: devices.videoInputs.find(d => !d.description.startsWith("Intel IPU6 ISYS")) ?? devices.defaultVideoInput
            active: root.cam !== null || (root.phase === "pick" && root.shift && root.optCam)
            onActiveChanged: if (!active) root.frames = 0
        }
    }

    Connections {
        target: root.sink
        function onVideoFrameChanged() {
            if (camera.active && root.frames < 100)
                root.frames += 1;
        }
    }

    IpcHandler {
        target: "recorder"
        function pick(fifo: string): void { root.pick(fifo); }
        function cancel(): void { root.cancel(); }
    }

    component Label: Text {
        color: T3.ink
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
    }

    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string hint: ""
        property bool on: false
        property string tone: "toggle"
        signal clicked

        readonly property bool lit: tone === "go" || (tone === "toggle" && on)
        readonly property color base: lit ? Theme.wm800 : T3.lighten(T3.ink, 0.12)

        width: pillRow.implicitWidth + 2 * 12
        height: 32
        radius: 7
        color: pillArea.containsMouse ? T3.lighten(base, 0.15) : base
        border.width: 1
        border.color: lit ? T3.lighten(Theme.wm800, 0.3) : T3.lighten(T3.ink, 0.25)

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            Label {
                visible: pill.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: pill.icon
                color: pill.lit ? T3.ink : T3.cream
                opacity: pill.lit ? 1 : 0.6
                font.pixelSize: Math.round(T3.labelSize * 1.3)
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                color: pill.lit ? T3.ink : T3.cream
                opacity: pill.lit || pill.tone !== "toggle" ? 1 : 0.6
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.hint
                color: pill.lit ? T3.ink : T3.cream
                opacity: 0.45
            }
        }

        MouseArea {
            id: pillArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property string name: modelData.name
            readonly property bool mine: root.target === name
            readonly property bool owner: root.phase === "pick" ? root.hover === name || (root.hover === "" && modelData === Quickshell.screens[0]) : mine
            readonly property var r: mine ? root.sel : null
            readonly property var c: mine ? root.cam : null
            property point press
            property point cursor
            property bool dragging: false
            readonly property var drag: dragging ? {
                x: Math.min(press.x, cursor.x),
                y: Math.min(press.y, cursor.y),
                w: Math.abs(cursor.x - press.x),
                h: Math.abs(cursor.y - press.y)
            } : null
            readonly property var hole: root.phase === "pick" ? drag : r

            screen: modelData
            visible: root.phase === "pick" || (root.phase !== "" && mine)
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: root.interactive ? null : nothing
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "t3-desktop-recorder-picker"
            WlrLayershell.keyboardFocus: root.focused && (root.phase === "pick" || mine) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            onOwnerChanged: attach()
            Component.onCompleted: attach()

            function attach() {
                if (!owner)
                    return;
                root.sink = vo.videoSink;
                capture.videoOutput = vo;
            }
            onVisibleChanged: if (visible) keys.forceActiveFocus()

            Region {
                id: nothing
            }

            Item {
                id: keys
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Shift) {
                        root.shift = true;
                        return;
                    }
                    if (event.key === Qt.Key_Escape)
                        root.cancel();
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.phase === "pick")
                            root.whole((event.modifiers & Qt.ShiftModifier) !== 0);
                        else
                            root.confirm();
                    } else if (root.phase === "adjust" && event.key === Qt.Key_W)
                        root.toggleCam();
                    else if (root.phase === "adjust" && event.key === Qt.Key_M)
                        root.optMic = !root.optMic;
                    else if (root.phase === "adjust" && event.key === Qt.Key_S)
                        root.optSys = !root.optSys;
                    else if (root.phase === "adjust" && Theme.twitch && event.key === Qt.Key_L)
                        root.toggleLive();
                    else
                        return;
                    event.accepted = true;
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Shift)
                        root.shift = false;
                }
            }

            Item {
                anchors.fill: parent
                visible: root.phase === "pick" || root.framed

                readonly property color veil: root.phase === "pick" ? "#33ffffff" : "#59000000"
                readonly property var h: win.hole

                Rectangle {
                    visible: !parent.h
                    anchors.fill: parent
                    color: parent.veil
                }
                Rectangle {
                    visible: !!parent.h
                    x: 0; y: 0
                    width: parent.width
                    height: parent.h ? parent.h.y : 0
                    color: parent.veil
                }
                Rectangle {
                    visible: !!parent.h
                    x: 0
                    y: parent.h ? parent.h.y + parent.h.h : 0
                    width: parent.width
                    height: parent.h ? parent.height - y : 0
                    color: parent.veil
                }
                Rectangle {
                    visible: !!parent.h
                    x: 0
                    y: parent.h ? parent.h.y : 0
                    width: parent.h ? parent.h.x : 0
                    height: parent.h ? parent.h.h : 0
                    color: parent.veil
                }
                Rectangle {
                    visible: !!parent.h
                    x: parent.h ? parent.h.x + parent.h.w : 0
                    y: parent.h ? parent.h.y : 0
                    width: parent.h ? parent.width - x : 0
                    height: parent.h ? parent.h.h : 0
                    color: parent.veil
                }
                Rectangle {
                    visible: !!parent.h && !root.full
                    x: parent.h ? parent.h.x - 2 : 0
                    y: parent.h ? parent.h.y - 2 : 0
                    width: parent.h ? parent.h.w + 4 : 0
                    height: parent.h ? parent.h.h + 4 : 0
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.wm800
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.phase === "pick"
                hoverEnabled: true
                cursorShape: Qt.CrossCursor
                onEntered: root.hover = win.name
                onPositionChanged: mouse => {
                    root.hover = win.name;
                    win.cursor = Qt.point(mouse.x, mouse.y);
                    root.shift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                }
                onPressed: mouse => {
                    win.press = Qt.point(mouse.x, mouse.y);
                    win.cursor = win.press;
                    win.dragging = true;
                }
                onReleased: mouse => {
                    const d = win.drag;
                    win.dragging = false;
                    if (!d || d.w < 8 || d.h < 8)
                        return;
                    root.region(d, win.name, (mouse.modifiers & Qt.ShiftModifier) !== 0);
                }
            }

            Item {
                id: editor
                anchors.fill: parent
                visible: root.phase === "adjust" && !!win.r
                property var start: null
                property point origin

                function begin(item, mouse) {
                    start = root.sel;
                    origin = item.mapToItem(editor, mouse.x, mouse.y);
                }

                function drag(item, mouse, edge) {
                    if (!start)
                        return;
                    const p = item.mapToItem(editor, mouse.x, mouse.y);
                    root.reshape(start, p.x - origin.x, p.y - origin.y, edge, win.width, win.height);
                }

                MouseArea {
                    id: moveArea
                    x: win.r ? win.r.x : 0
                    y: win.r ? win.r.y : 0
                    width: win.r ? win.r.w : 0
                    height: win.r ? win.r.h : 0
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeAllCursor
                    onPressed: mouse => editor.begin(moveArea, mouse)
                    onPositionChanged: mouse => editor.drag(moveArea, mouse, "move")
                }

                Repeater {
                    model: ["tl", "t", "tr", "r", "br", "b", "bl", "l"]

                    Rectangle {
                        id: handle
                        required property string modelData
                        readonly property real hx: !win.r ? 0 : modelData.includes("l") ? win.r.x : modelData.includes("r") ? win.r.x + win.r.w : win.r.x + win.r.w / 2
                        readonly property real hy: !win.r ? 0 : modelData.includes("t") ? win.r.y : modelData.includes("b") ? win.r.y + win.r.h : win.r.y + win.r.h / 2
                        x: Math.round(hx - width / 2)
                        y: Math.round(hy - height / 2)
                        width: 12
                        height: 12
                        color: Theme.wm800
                        border.width: 2
                        border.color: T3.ink

                        MouseArea {
                            id: handleArea
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: handle.modelData === "tl" || handle.modelData === "br" ? Qt.SizeFDiagCursor
                                : handle.modelData === "tr" || handle.modelData === "bl" ? Qt.SizeBDiagCursor
                                : handle.modelData === "t" || handle.modelData === "b" ? Qt.SizeVerCursor
                                : Qt.SizeHorCursor
                            onPressed: mouse => editor.begin(handleArea, mouse)
                            onPositionChanged: mouse => editor.drag(handleArea, mouse, handle.modelData)
                        }
                    }
                }
            }

            Rectangle {
                id: tip
                visible: root.phase === "pick" && root.hover === win.name && !win.dragging
                x: win.cursor.x + 18 + width > win.width ? win.cursor.x - 18 - width : win.cursor.x + 18
                y: win.cursor.y + 22 + height > win.height ? win.cursor.y - 22 - height : win.cursor.y + 22
                width: tipCol.implicitWidth + 2 * 12
                height: tipCol.implicitHeight + 2 * 9
                radius: 8
                color: root.shift ? Theme.wm800 : T3.accent2
                border.width: 1
                border.color: T3.lighten(color, 0.25)

                Column {
                    id: tipCol
                    anchors.centerIn: parent
                    spacing: 4

                    Label { text: "pick region" }
                    Label { text: "enter · whole screen"; opacity: 0.75 }
                    Label { text: root.shift ? "\u{f0493}  advanced mode" : "hold shift · advanced mode"; opacity: root.shift ? 1 : 0.75 }
                }
            }

            Rectangle {
                id: square
                visible: !!win.c
                x: win.c ? win.c.x : 0
                y: win.c ? win.c.y : 0
                width: win.c ? win.c.s : 0
                height: width
                color: T3.ink
                border.width: T3.windowBorder
                border.color: Theme.wm800

                VideoOutput {
                    id: vo
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    fillMode: VideoOutput.PreserveAspectCrop
                    clip: true
                    visible: root.ready
                    transform: Scale { origin.x: vo.width / 2; xScale: -1 }
                }

                Label {
                    visible: !root.ready
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "camera warming up"
                    color: T3.cream
                    opacity: 0.4 + 0.6 * Math.abs(Math.sin(pulse.t))
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.phase === "adjust"
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    property point grab
                    onPressed: mouse => grab = Qt.point(mouse.x, mouse.y)
                    onPositionChanged: mouse => {
                        const r = win.r, c = root.cam;
                        const nx = Math.max(r.x, Math.min(r.x + r.w - c.s, c.x + mouse.x - grab.x));
                        const ny = Math.max(r.y, Math.min(r.y + r.h - c.s, c.y + mouse.y - grab.y));
                        root.cam = { x: nx, y: ny, s: c.s };
                    }
                    onWheel: wheel => {
                        const r = win.r, c = root.cam;
                        const max = Math.min(r.w, r.h);
                        const s = Math.max(48, Math.min(max, c.s * Math.pow(1.1, wheel.angleDelta.y / 120)));
                        const cx = c.x + c.s / 2, cy = c.y + c.s / 2;
                        root.cam = {
                            x: Math.max(r.x, Math.min(r.x + r.w - s, cx - s / 2)),
                            y: Math.max(r.y, Math.min(r.y + r.h - s, cy - s / 2)),
                            s: s
                        };
                    }
                }

                Rectangle {
                    visible: root.phase === "adjust"
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 18
                    height: 18
                    color: Theme.wm800
                    border.width: 2
                    border.color: T3.ink

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.SizeFDiagCursor
                        onPositionChanged: mouse => {
                            const r = win.r, c = root.cam;
                            const p = mapToItem(square.parent, mouse.x, mouse.y);
                            const want = Math.max(p.x - c.x, p.y - c.y);
                            const s = Math.max(48, Math.min(r.x + r.w - c.x, r.y + r.h - c.y, want));
                            root.cam = { x: c.x, y: c.y, s: s };
                        }
                    }
                }
            }

            QtObject {
                id: pulse
                property real t: 0
                property NumberAnimation anim: NumberAnimation {
                    target: pulse
                    property: "t"
                    from: 0
                    to: Math.PI
                    duration: 1400
                    loops: Animation.Infinite
                    running: square.visible && !root.ready
                }
            }

            Rectangle {
                id: panel
                visible: root.phase === "adjust" && !!win.r
                readonly property real below: win.r ? win.r.y + win.r.h + 12 : 0
                readonly property real above: win.r ? win.r.y - 12 - height : 0
                x: win.r ? Math.max(8, Math.min(win.width - width - 8, win.r.x + (win.r.w - width) / 2)) : 0
                y: below + height <= win.height - 8 ? below : above >= 8 ? above : (win.r ? win.r.y + win.r.h - height - 24 : 0)
                width: panelCol.implicitWidth + 2 * 6
                height: panelCol.implicitHeight + 2 * 6
                radius: 10
                color: T3.ink
                border.width: 1
                border.color: T3.lighten(T3.ink, 0.25)

                Column {
                    id: panelCol
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        visible: Theme.twitch && root.optLive
                        width: panelRow.implicitWidth
                        height: 32
                        radius: 7
                        color: T3.lighten(T3.ink, 0.12)
                        border.width: 1
                        border.color: titleInput.activeFocus ? Theme.wm800 : T3.lighten(T3.ink, 0.25)

                        Label {
                            id: titleLabel
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "title"
                            color: T3.cream
                            opacity: 0.45
                        }

                        TextInput {
                            id: titleInput
                            anchors.left: titleLabel.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.title
                            color: T3.cream
                            selectionColor: Theme.wm800
                            selectedTextColor: T3.ink
                            clip: true
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(T3.labelSize * 1.2)
                            onTextEdited: root.title = text
                            onAccepted: root.confirm()
                            Keys.onEscapePressed: root.cancel()
                        }
                    }

                    Row {
                        id: panelRow
                        spacing: 6

                        Pill {
                            icon: root.optCam ? "\u{f0567}" : "\u{f0568}"
                            label: "webcam"
                            hint: "w"
                            on: root.optCam
                            onClicked: root.toggleCam()
                        }
                        Pill {
                            icon: root.optMic ? "\u{f036c}" : "\u{f036d}"
                            label: "microphone"
                            hint: "m"
                            on: root.optMic
                            onClicked: root.optMic = !root.optMic
                        }
                        Pill {
                            icon: root.optSys ? "\u{f057e}" : "\u{f0581}"
                            label: "system audio"
                            hint: "s"
                            on: root.optSys
                            onClicked: root.optSys = !root.optSys
                        }
                        Pill {
                            icon: "\u{f0543}"
                            visible: Theme.twitch
                            label: "go live"
                            hint: "l"
                            on: root.optLive
                            onClicked: root.toggleLive()
                        }

                        Item { width: 10; height: 1 }

                        Pill {
                            label: "cancel"
                            hint: "esc"
                            tone: "plain"
                            onClicked: root.cancel()
                        }
                        Pill {
                            label: Theme.twitch && root.optLive ? "go live" : "ok"
                            hint: "enter"
                            tone: "go"
                            onClicked: root.confirm()
                        }
                    }
                }

                Connections {
                    target: root
                    function onPhaseChanged() {
                        if (win.mine && root.phase === "adjust" && root.optLive)
                            titleInput.forceActiveFocus();
                    }
                    function onOptLiveChanged() {
                        if (!win.mine || root.phase !== "adjust")
                            return;
                        if (root.optLive)
                            titleInput.forceActiveFocus();
                        else
                            keys.forceActiveFocus();
                    }
                }
            }

            Text {
                id: numeral
                visible: root.phase === "count" && !!win.r
                text: String(root.count)
                x: win.r ? win.r.x + (win.r.w - width) / 2 : 0
                y: win.r ? win.r.y + (win.r.h - height) / 2 : 0
                color: T3.cream
                style: Text.Outline
                styleColor: T3.ink
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: win.r ? Math.round(Math.max(64, Math.min(260, Math.min(win.r.w, win.r.h) * 0.35))) : 64

                onTextChanged: pop.restart()

                SequentialAnimation {
                    id: pop
                    ParallelAnimation {
                        NumberAnimation { target: numeral; property: "scale"; from: 1.35; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: numeral; property: "opacity"; from: 0; to: 1; duration: 160 }
                    }
                    PauseAnimation { duration: 520 }
                    NumberAnimation { target: numeral; property: "opacity"; to: 0.15; duration: 200 }
                }
            }
        }
    }
}
