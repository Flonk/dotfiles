import QtQuick

Item {
    id: meter

    property var values: []
    property color color: T3.accent2
    property int columnWidth: 34
    property int rowsPerColumn: 16
    property Item frame: null

    readonly property int columns: Math.max(1, Math.ceil(values.length / rowsPerColumn))
    readonly property int rows: Math.min(values.length, rowsPerColumn)
    readonly property int pitch: Math.max(2, Math.floor((height + 1) / Math.max(1, rows)))
    readonly property int pad: Math.floor((height + 1 - pitch * rows) / 2)
    readonly property vector4d cutout: {
        x; y; width; height; parent?.x; parent?.y; parent?.parent?.x; parent?.parent?.y; frame?.width;
        if (!frame)
            return Qt.vector4d(0, 0, 0, 0);
        const p = mapToItem(frame, 0, 0);
        return Qt.vector4d(Math.round(p.x), Math.round(p.y), width, height);
    }

    implicitWidth: columns * columnWidth + columns - 1 + 4
    implicitHeight: T3.band

    Repeater {
        model: meter.columns

        Item {
            id: column
            required property int index
            x: 2 + index * (meter.columnWidth + 1)
            width: meter.columnWidth
            height: meter.height

            Repeater {
                model: meter.rows

                Rectangle {
                    required property int index
                    readonly property real usage: Math.max(0, Math.min(1, meter.values[column.index * meter.rowsPerColumn + index] ?? 0))
                    visible: column.index * meter.rowsPerColumn + index < meter.values.length
                    y: meter.pad + index * meter.pitch
                    width: Math.max(1, Math.round(column.width * usage))
                    height: meter.pitch - 1
                    color: meter.color

                    Behavior on width {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
