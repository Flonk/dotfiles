// shell.qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    Bar {}

    LockContext {
        id: lockContext

        onUnlocked: {
            Qt.callLater(() => { lock.locked = false; });
        }
    }

    WlSessionLock {
        id: lock
        locked: false

        // the shader renders only on the largest screen; every other
        // surface stays black
        readonly property var renderScreen: {
            let best = null;
            for (const s of Quickshell.screens) {
                if (!best || s.width * s.height > best.width * best.height)
                    best = s;
            }
            return best;
        }

        WlSessionLockSurface {
            id: lockWindow
            LockSurface {
                id: lockSurface
                anchors.fill: parent
                context: lockContext
                renderScene: lockWindow.screen === lock.renderScreen
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen(); }
    }

    function lockScreen() {
        lockContext.reset();
        lock.locked = true;
    }
}
