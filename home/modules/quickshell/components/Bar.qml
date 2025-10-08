// Bar.qml - Orchestrator for per-screen bar components
import Quickshell
import QtQuick

Scope {
  Variants {
    model: Quickshell.screens

    Item {
      required property var modelData

      AppController { id: screenAppController }

      BarWindow {
        screenInfo: modelData
        appController: screenAppController
        Component.onCompleted: console.log("BarWindow completed on screen:", screen ? screen.name : "<none>")
      }
    }
  }
}