// MarqueeText.qml - Text component that marquees on hover
import QtQuick

Item {
    id: root
    
    property alias text: textItem.text
    property alias font: textItem.font
    property alias textColor: textItem.color
    property alias textOpacity: textItem.opacity
    property alias elide: textItem.elide

    // Visual alignment inside the available width
    // Qt.AlignLeft, Qt.AlignRight, Qt.AlignHCenter
    property int alignment: Qt.AlignLeft
    
    // Marquee behavior: "pingpong" (back and forth) or "repeat" (continuous billboard)
    property string marqueeBehavior: "pingpong"
    
    property bool hovered: false
    property real marqueeSpeed: 30 // pixels per second
    property int marqueeDelay: 500
    property int repeatGap: 13

    function currentOverflow() {
        return Math.max(0, textItem.implicitWidth - root.width);
    }
    
    implicitWidth: textItem.implicitWidth
    implicitHeight: textItem.implicitHeight

    clip: true
    
    Text {
        id: textItem
        anchors.verticalCenter: parent.verticalCenter
        
        x: {
            var overflow = root.currentOverflow();

            // No overflow: honor alignment visually, no marquee
            if (overflow === 0) {
                if (root.alignment === Qt.AlignHCenter) {
                    return (root.width - textItem.implicitWidth) / 2;
                } else if (root.alignment === Qt.AlignRight) {
                    return root.width - textItem.implicitWidth;
                }
                return 0;
            }

            // Overflow: when not hovered, rest according to alignment
            if (!root.hovered) {
                if (root.alignment === Qt.AlignRight) {
                    return -overflow; // show end
                } else if (root.alignment === Qt.AlignHCenter) {
                    return -overflow / 2; // middle
                }
                // Left align
                return 0;
            }

            // Hovered with overflow: slide based on marquee offset
            return -marqueeAnimation.offset;
        }
        
        Behavior on x {
            enabled: !root.hovered
            NumberAnimation { duration: 200 }
        }
    }
    
    // Second copy of text for repeat/billboard mode
    Text {
        id: textItem2
        anchors.verticalCenter: parent.verticalCenter
        visible: root.marqueeBehavior === "repeat" && root.hovered && root.currentOverflow() > 0
        
        text: textItem.text
        font: textItem.font
        color: textItem.color
        opacity: textItem.opacity
        
        x: textItem.x + textItem.implicitWidth + root.repeatGap
    }
    
    QtObject {
        id: marqueeAnimation
        property real offset: 0
        property real maxOffset: root.currentOverflow()
        property real speed: root.marqueeSpeed // px per second
        
        property var animation: root.marqueeBehavior === "repeat" ? repeatAnimation : pingpongAnimation
        
        // Pingpong animation (back and forth)
        property var pingpongAnimation: SequentialAnimation {
            running: root.hovered && marqueeAnimation.maxOffset > 0 && root.marqueeBehavior === "pingpong"
            loops: Animation.Infinite

            // Wait before starting to scroll
            PauseAnimation { duration: root.marqueeDelay }

            // Scroll to the opposite edge
            NumberAnimation {
                id: forwardAnim
                target: marqueeAnimation
                property: "offset"
                to: (root.alignment === Qt.AlignRight ? 0 : marqueeAnimation.maxOffset)
                duration: 0
                easing.type: Easing.Linear
            }

            // Small pause at the far edge
            PauseAnimation { duration: root.marqueeDelay }

            // Scroll back to the starting edge
            NumberAnimation {
                id: backwardAnim
                target: marqueeAnimation
                property: "offset"
                to: (root.alignment === Qt.AlignRight ? marqueeAnimation.maxOffset : 0)
                duration: 0
                easing.type: Easing.Linear
            }
        }
        
        // Repeat/billboard animation (continuous scrolling)
        property var repeatAnimation: NumberAnimation {
            running: root.hovered && marqueeAnimation.maxOffset > 0 && root.marqueeBehavior === "repeat"
            loops: Animation.Infinite
            target: marqueeAnimation
            property: "offset"
            from: 0
            to: textItem.implicitWidth + root.repeatGap
            duration: (textItem.implicitWidth + root.repeatGap) / root.marqueeSpeed * 1000
            easing.type: Easing.Linear
        }
    }
    
    onHoveredChanged: {
        var overflow = root.currentOverflow();

        if (hovered && overflow > 0) {
            if (root.marqueeBehavior === "pingpong") {
                // Initialize offset to the resting position that matches alignment
                marqueeAnimation.offset = (alignment === Qt.AlignRight)
                        ? marqueeAnimation.maxOffset
                        : 0;
                // Ensure forward animation duration matches actual distance for first leg
                forwardAnim.duration = Math.abs(forwardAnim.to - marqueeAnimation.offset) / marqueeAnimation.speed * 1000;
                backwardAnim.duration = Math.abs(backwardAnim.to - forwardAnim.to) / marqueeAnimation.speed * 1000;
            } else {
                // Repeat mode: start at 0
                marqueeAnimation.offset = 0;
            }
        } else {
            // When leaving hover, reset based on alignment
            if (root.marqueeBehavior === "pingpong") {
                marqueeAnimation.offset = (alignment === Qt.AlignRight && overflow > 0)
                        ? marqueeAnimation.maxOffset
                        : 0;
            } else {
                marqueeAnimation.offset = 0;
            }
        }
    }
}
