import QtQuick

Item {
    id: meter

    property var values: []
    property var rings: []
    property string label
    property color color: T3.accent2
    property color warnColor: "#e6c34a"
    property color fullColor: Theme.error400
    property int barWidth: 2
    property int padding: 3
    property int rightPadding: 8
    property int ringSize: 10
    property int ringGap: 4
    property int barsGap: 6
    property Item frame: null

    readonly property int inset: T3.radius
    readonly property int span: height - 2 * T3.radius
    readonly property color textColor: T3.lighten(color, 0.35)

    readonly property vector4d cutout: {
        x; y; width; height; visible; parent?.x; parent?.y; parent?.parent?.x; parent?.parent?.y; frame?.width;
        if (!frame || !visible)
            return Qt.vector4d(0, 0, 0, 0);
        const p = mapToItem(frame, 0, 0);
        return Qt.vector4d(Math.round(p.x) + 1, Math.round(p.y), width - 2, height);
    }

    function tint(v) {
        const percent = Math.round(v * 100);
        return percent >= 100 ? fullColor : percent > 80 ? warnColor : color;
    }

    implicitWidth: 2 + padding + rightPadding + content.implicitWidth
    implicitHeight: T3.band

    component Label: Text {
        color: meter.textColor
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
    }

    TextMetrics {
        id: widest
        font.family: Theme.fontFamily
        font.pixelSize: T3.labelSize
        font.weight: Font.Bold
        font.letterSpacing: T3.labelTracking
        font.capitalization: Font.AllUppercase
        text: "MEM 100"
    }

    Row {
        id: content
        x: 1 + meter.padding
        height: meter.height
        spacing: 5

        Column {
            y: Math.floor((meter.height - meter.rings.length * meter.ringSize - (meter.rings.length - 1) * meter.ringGap) / 2)
            spacing: meter.ringGap

            Repeater {
                model: meter.rings.length

                Label {
                    required property int index
                    readonly property var modelData: meter.rings[index]
                    width: widest.advanceWidth
                    height: meter.ringSize
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: modelData.label + " " + Math.round(modelData.value * 100)
                }
            }
        }

        Column {
            y: Math.floor((meter.height - meter.rings.length * meter.ringSize - (meter.rings.length - 1) * meter.ringGap) / 2)
            spacing: meter.ringGap

            Repeater {
                model: meter.rings.length

                Canvas {
                    id: ring
                    required property int index
                    readonly property var modelData: meter.rings[index]
                    readonly property real level: Math.max(0, Math.min(1, modelData.value))
                    readonly property color ink: meter.tint(level)
                    width: meter.ringSize
                    height: meter.ringSize
                    onLevelChanged: requestPaint()
                    onInkChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const c = width / 2, r = width / 2 - 1;
                        ctx.lineWidth = 2;
                        ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.25);
                        ctx.beginPath();
                        ctx.arc(c, c, r, 0, 2 * Math.PI);
                        ctx.stroke();
                        if (level <= 0)
                            return;
                        ctx.strokeStyle = ink;
                        ctx.beginPath();
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * level);
                        ctx.stroke();
                    }
                }
            }
        }

        Item {
            width: meter.barsGap - content.spacing
            height: 1
        }

        Item {
            width: Math.max(1, meter.values.length) * (meter.barWidth + 1) - 1
            height: meter.height

            Repeater {
                model: meter.values.length

                Rectangle {
                    required property int index
                    readonly property real usage: Math.max(0, Math.min(1, meter.values[index] ?? 0))
                    x: index * (meter.barWidth + 1)
                    y: meter.height - meter.inset - height
                    width: meter.barWidth
                    height: Math.max(1, Math.round(meter.span * usage))
                    color: meter.tint(usage)

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: meter.height - meter.inset
                height: meter.inset
                leftPadding: T3.labelTracking
                verticalAlignment: Text.AlignVCenter
                text: meter.label
            }
        }
    }
}
