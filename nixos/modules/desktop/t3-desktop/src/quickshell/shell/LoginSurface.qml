import QtQuick
import Quickshell

Item {
    id: root
    required property var context

    readonly property real contentCenterY: (T3.band + height - T3.border) / 2
    readonly property int dots: context.currentText.length

    ChromeSurface {
        anchors.fill: parent
        plain: 1
        markRect: Qt.vector4d(root.width / 2 - T3.markSize / 2, (T3.band - T3.markSize) / 2, T3.markSize, T3.markSize)
    }

    Column {
        id: prompt
        x: (root.width - width) / 2
        y: root.contentCenterY - height / 2
        spacing: 14

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Quickshell.env("USER") ?? ""
            color: T3.cream
            font.family: Theme.fontFamily
            font.pixelSize: T3.labelSize + 2
            font.weight: Font.Bold
            font.letterSpacing: T3.labelTracking
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            id: field
            width: 300
            height: 40
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: root.context.showFailure ? Theme.error400 : Qt.rgba(1, 1, 1, 0.2)

            Row {
                anchors.centerIn: parent
                spacing: 7
                visible: root.dots > 0

                Repeater {
                    model: Math.min(root.dots, 24)

                    Rectangle {
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Theme.wm800
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.dots === 0
                text: root.context.unlockInProgress ? "…" : "password"
                color: T3.cream
                opacity: 0.35
                font.family: Theme.fontFamily
                font.pixelSize: T3.labelSize
                font.weight: Font.Bold
                font.letterSpacing: T3.labelTracking
                font.capitalization: Font.AllUppercase
            }

            SequentialAnimation on x {
                id: shake
                running: false
                loops: 1
                NumberAnimation { to: 10; duration: 40 }
                NumberAnimation { to: -10; duration: 60 }
                NumberAnimation { to: 6; duration: 50 }
                NumberAnimation { to: 0; duration: 50 }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.showFailure ? "wrong password" : " "
            color: Theme.error400
            font.family: Theme.fontFamily
            font.pixelSize: T3.labelSize
            font.weight: Font.Bold
            font.letterSpacing: T3.labelTracking
            font.capitalization: Font.AllUppercase
        }
    }

    Connections {
        target: root.context
        function onShowFailureChanged() {
            if (root.context.showFailure)
                shake.restart();
        }
    }

    TextInput {
        id: passwordInput
        focus: true
        echoMode: TextInput.Password
        visible: false

        text: root.context.currentText
        onTextChanged: {
            if (text !== root.context.currentText)
                root.context.currentText = text;
        }

        Keys.onReturnPressed: root.context.tryUnlock()
        Keys.onEnterPressed: root.context.tryUnlock()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: passwordInput.forceActiveFocus()
    }
}
