// CavaWidget.qml - Singleton system audio provider
pragma Singleton
import QtQuick
import Quickshell
import CavaPlugin 1.0

Singleton {
    id: root
    
    property alias bars: provider.bars
    property alias noiseReduction: provider.noiseReduction
    property alias enableMonstercatFilter: provider.enableMonstercatFilter
    property alias values: provider.values
    
    CavaProvider {
        id: provider
        bars: 40  // Default, can be overridden
    }
}