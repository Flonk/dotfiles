import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland

Flickable {
    id: root
    property int frameW: 1920
    property real zoom: 2
    property bool active: true

    contentHeight: col.implicitHeight + 48
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property var sectionItems: []

    function collect() {
        const bar = liveBar ? liveBar.item : null;
        if (!bar) {
            sectionItems = [];
            return;
        }
        const out = [];
        const walk = it => {
            for (const c of it.children) {
                if (c.objectName)
                    out.push(c);
                else
                    walk(c);
            }
        };
        walk(bar);
        out.sort((a, b) => a.mapToItem(bar, 0, 0).x - b.mapToItem(bar, 0, 0).x);
        if (out.length === sectionItems.length && out.every((x, i) => x === sectionItems[i]))
            return;
        sectionItems = out;
    }

    function reload() {
        liveBar.active = false;
        lockBar.active = false;
        liveBar.active = true;
        lockBar.active = true;
    }

    readonly property var specs: [
        { name: "BarSegment", file: "BarSegment.qml", props: { text: "SEGMENT 42", clickable: true } },
        { name: "BarText", file: "BarText.qml", props: { text: "bar text" } },
        { name: "WorkspacesDisplay", file: "WorkspacesDisplay.qml", props: { monitor: Hyprland.focusedMonitor } },
        { name: "WifiDisplay", file: "WifiDisplay.qml", props: {} },
        { name: "MediaControlDisplay", file: "MediaControlDisplay.qml", props: { width: 360 } },
        { name: "MarqueeText", file: "MarqueeText.qml", props: { width: 160, height: 20, text: "a very long scrolling title that does not fit into its lane", textColor: Theme.app600, scrolling: true } }
    ]

    readonly property var dataSources: ({
        SystemMonitor: SystemMonitor,
        VolumeWidget: VolumeWidget,
        BrightnessWidget: BrightnessWidget,
        HeadphonesWidget: HeadphonesWidget,
        MediaControlWidget: MediaControlWidget,
        WifiWidget: WifiWidget,
        LanguageWidget: LanguageWidget,
        Theme: Theme
    })

    function fmt(v) {
        if (v === null || v === undefined)
            return String(v);
        if (typeof v === "number")
            return Number.isInteger(v) ? String(v) : v.toFixed(3);
        if (typeof v === "boolean")
            return String(v);
        if (typeof v === "string")
            return JSON.stringify(v.length > 48 ? v.slice(0, 48) + "…" : v);
        if (Array.isArray(v)) {
            const s = JSON.stringify(v.map(x => typeof x === "number" && !Number.isInteger(x) ? +x.toFixed(2) : x));
            return "[" + v.length + "] " + (s.length > 48 ? s.slice(0, 48) + "…" : s);
        }
        const s = String(v);
        return s.length > 56 ? s.slice(0, 56) + "…" : s;
    }

    function snapshot(obj) {
        const rows = [];
        for (const k in obj) {
            if (k.startsWith("_") || k === "objectName" || k.endsWith("Changed"))
                continue;
            let v;
            try {
                v = obj[k];
            } catch (e) {
                continue;
            }
            if (typeof v === "function")
                continue;
            let s;
            try {
                s = fmt(v);
            } catch (e) {
                s = "[list]";
            }
            rows.push([k, s]);
        }
        return rows;
    }

    component GroupTitle: Text {
        color: "#66ffffff"
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 1.5
        font.capitalization: Font.AllUppercase
        topPadding: 18
        bottomPadding: 4
    }

    component Card: Rectangle {
        id: card
        property string title
        property string subtitle
        default property alias body: bodyItem.data
        property real bodyWidth: 160
        property real bodyHeight: 20
        width: Math.max(170, bodyWidth + 24)
        height: bodyHeight + 54
        radius: 6
        color: "#18181d"
        border.color: "#22ffffff"

        Text {
            id: titleText
            x: 12
            y: 10
            text: card.title
            color: "#ddffffff"
            font.pixelSize: 12
            font.bold: true
        }

        Text {
            anchors { left: titleText.right; leftMargin: 8; baseline: titleText.baseline }
            text: card.subtitle
            color: "#66ffffff"
            font.pixelSize: 11
            font.family: "monospace"
        }

        Item {
            id: bodyItem
            x: 12
            y: 34
            width: card.bodyWidth
            height: card.bodyHeight
        }
    }

    component BarStrip: Item {
        id: strip
        property alias loader: ld
        property Component bar
        property real s: 1
        property int h: 20
        width: root.frameW * s
        height: h * s

        Item {
            width: root.frameW
            height: strip.h
            scale: strip.s
            transformOrigin: Item.TopLeft

            Loader {
                id: ld
                anchors.fill: parent
                sourceComponent: strip.bar
            }
        }
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.collect()
    }

    Column {
        id: col
        x: 24
        y: 8
        width: root.width - 48
        spacing: 6

        GroupTitle { text: "header + bar  " + root.frameW + "px  @ " + root.zoom + "x" }

        Item {
            id: overview
            width: col.width
            height: Math.max(8, 20 * width / root.frameW)

            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: root.liveBar ? root.liveBar.item : null
                live: true
            }

            Rectangle {
                x: barScroll.contentWidth > 0 ? barScroll.contentX / barScroll.contentWidth * overview.width : 0
                width: barScroll.contentWidth > 0 ? Math.min(1, barScroll.width / barScroll.contentWidth) * overview.width : overview.width
                height: parent.height
                color: "#223aa8b8"
                border.color: "#3aa8b8"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function jump(mx) {
                    const max = Math.max(0, barScroll.contentWidth - barScroll.width);
                    barScroll.contentX = Math.max(0, Math.min(max, mx / overview.width * barScroll.contentWidth - barScroll.width / 2));
                }
                onPressed: m => jump(m.x)
                onPositionChanged: m => jump(m.x)
            }
        }

        Flickable {
            id: barScroll
            width: col.width
            height: stripCol.height + 16
            contentWidth: stripCol.width
            contentHeight: stripCol.height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AlwaysOn
            }

            Column {
                id: stripCol
                spacing: 8
                topPadding: 6

                BarStrip {
                    s: root.zoom
                    h: T3.band
                    bar: Component {
                        ChromeHeader {
                            screenSize: Qt.vector2d(root.frameW, T3.band)
                            monitor: Hyprland.focusedMonitor
                        }
                    }
                }

                Text {
                    x: barScroll.contentX
                    text: "BarContent (lockscreen bar)"
                    color: "#66ffffff"
                    font.pixelSize: 11
                }

                BarStrip {
                    s: root.zoom
                    bar: Component {
                        BarContent {
                            monitor: Hyprland.focusedMonitor
                        }
                    }
                    Component.onCompleted: root.liveBar = loader
                }

                Text {
                    x: barScroll.contentX
                    text: "BarContent, lockscreen variant"
                    color: "#66ffffff"
                    font.pixelSize: 11
                }

                BarStrip {
                    s: root.zoom
                    bar: Component {
                        BarContent {
                            lockscreen: true
                            interactive: false
                            authorText: "author credit"
                        }
                    }
                    Component.onCompleted: root.lockBar = loader
                }
            }
        }

        GroupTitle { text: "sections  " + root.sectionItems.length }

        Flow {
            width: col.width
            spacing: 10

            Repeater {
                model: root.sectionItems
                Card {
                    id: sc
                    required property var modelData
                    title: modelData.objectName
                    subtitle: modelData.visible ? Math.round(modelData.width) + "×" + Math.round(modelData.height) : "hidden"
                    bodyWidth: Math.max(1, modelData.width) * root.zoom
                    bodyHeight: Math.max(1, modelData.height) * root.zoom

                    ShaderEffectSource {
                        anchors.fill: parent
                        visible: sc.modelData.visible
                        sourceItem: sc.modelData
                        live: true
                        textureSize: Qt.size(width, height)
                    }
                }
            }
        }

        GroupTitle { text: "components  " + root.specs.length }

        Flow {
            width: col.width
            spacing: 10

            Repeater {
                model: root.specs
                Card {
                    id: cc
                    required property var modelData
                    readonly property Item it: ld.item
                    title: modelData.name
                    subtitle: ld.status === Loader.Error ? "failed to load" : it ? Math.round(it.width) + "×" + Math.round(it.height) : "…"
                    bodyWidth: it ? Math.max(1, it.width) * root.zoom : 160
                    bodyHeight: it ? Math.max(1, it.height) * root.zoom : 20

                    Item {
                        width: cc.it ? cc.it.width : 0
                        height: cc.it ? cc.it.height : 0
                        scale: root.zoom
                        transformOrigin: Item.TopLeft

                        Loader {
                            id: ld
                            Component.onCompleted: setSource(cc.modelData.file, cc.modelData.props)
                        }
                    }
                }
            }
        }

        GroupTitle { text: "data sources  " + Object.keys(root.dataSources).length }

        Flow {
            width: col.width
            spacing: 10

            Repeater {
                model: Object.keys(root.dataSources)
                Card {
                    id: dc
                    required property string modelData
                    property var rows: []
                    title: modelData
                    subtitle: rows.length + " props"
                    bodyWidth: 380
                    bodyHeight: rowsCol.implicitHeight

                    Timer {
                        interval: 1000
                        running: root.active
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: dc.rows = root.snapshot(root.dataSources[dc.modelData])
                    }

                    Column {
                        id: rowsCol
                        width: parent.width
                        Repeater {
                            model: dc.rows
                            Row {
                                required property var modelData
                                spacing: 8
                                Text {
                                    width: 150
                                    elide: Text.ElideRight
                                    text: modelData[0]
                                    color: "#99ffffff"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                }
                                Text {
                                    width: 222
                                    elide: Text.ElideRight
                                    text: modelData[1]
                                    color: "#ddffffff"
                                    font.family: "monospace"
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    property Loader liveBar: null
    property Loader lockBar: null
}
