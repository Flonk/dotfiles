import QtQuick
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
        { name: "Section", file: "Section.qml", props: { width: 120, height: 20, backgroundColor: Theme.app150 } },
        { name: "AppLauncherDisplay", file: "AppLauncherDisplay.qml", props: { height: 20, interactive: false } },
        { name: "WorkspacesDisplay", file: "WorkspacesDisplay.qml", props: { monitor: Hyprland.focusedMonitor, height: 20 } },
        { name: "WifiDisplay", file: "WifiDisplay.qml", props: { height: 20, wifiIconColor: Theme.app600, arrowIconColor: Theme.app600, speedColor: Theme.app600, ipColor: Theme.app700, ipHoverColor: Theme.app900 } },
        { name: "MediaControlDisplay", file: "MediaControlDisplay.qml", props: { width: 360, height: 20, textColor: Theme.app600 } },
        { name: "MarqueeText", file: "MarqueeText.qml", props: { width: 160, height: 20, text: "a very long scrolling title that does not fit into its lane", textColor: Theme.app600 } },
        { name: "KeyValuePair", file: "KeyValuePair.qml", props: { label: "CPU", value: "42%" } },
        { name: "DropDown", file: "DropDown.qml", props: { label: "dropdown", width: 160 } }
    ]

    readonly property var dataSources: ({
        SystemMonitor: SystemMonitor,
        VolumeWidget: VolumeWidget,
        BrightnessWidget: BrightnessWidget,
        HeadphonesWidget: HeadphonesWidget,
        MediaControlWidget: MediaControlWidget,
        MprisWidget: MprisWidget,
        WifiWidget: WifiWidget,
        LanguageWidget: LanguageWidget,
        LockWidget: LockWidget,
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
        readonly property real s: width / root.frameW
        height: 20 * s

        Item {
            width: root.frameW
            height: 20
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

        GroupTitle { text: "bar  " + root.frameW + "px" }

        BarStrip {
            width: col.width
            bar: Component {
                BarContent {
                    monitor: Hyprland.focusedMonitor
                }
            }
            Component.onCompleted: root.liveBar = loader
        }

        GroupTitle { text: "lockscreen variant" }

        BarStrip {
            width: col.width
            bar: Component {
                BarContent {
                    lockscreen: true
                    interactive: false
                    authorText: "author credit"
                }
            }
            Component.onCompleted: root.lockBar = loader
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
