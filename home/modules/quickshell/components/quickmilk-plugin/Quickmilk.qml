import QtQml
import Quickmilk 1.0

QtObject {
    id: root

    property QuickmilkHub hub: QuickmilkHub { id: hubInstance }
    
    property alias maxBars: hubInstance.maxBars
    property alias enableMonstercatFilter: hubInstance.enableMonstercatFilter
    property alias gravityDecay: hubInstance.gravityDecay
    property alias systemVisualizer: hubInstance.systemVisualizer
    property alias microphoneVisualizer: hubInstance.microphoneVisualizer
}
