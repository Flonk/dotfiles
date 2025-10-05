// XorShaderWidget.qml - A simple animated XOR texture shader widget
import QtQuick

Rectangle {
    id: root
    
    // Default size (barHeight x barHeight)
    width: 30
    height: 30
    
    color: "transparent"
    
    ShaderEffect {
        id: shader
        anchors.fill: parent
        
        property real iTime: 0
        property vector2d iResolution: Qt.vector2d(width, height)
        
        fragmentShader: "xor_texture.frag.qsb"
        
        // Animation timer
        Timer {
            interval: 16 // ~60 fps
            running: true
            repeat: true
            onTriggered: {
                shader.iTime += 0.016
            }
        }
    }
}
