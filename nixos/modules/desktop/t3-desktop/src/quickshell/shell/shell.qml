import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    id: root
    property bool loginMode: false

    Chrome {}

    RecordBar {}

    Askpass {}
    DisplayPicker {}

    LockContext {
        id: lockContext

        onUnlocked: {
            Qt.callLater(() => {
                lock.locked = false;
                root.loginMode = false;
            });
        }
    }

    WlSessionLock {
        id: lock
        locked: false

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
            Loader {
                anchors.fill: parent
                focus: true
                sourceComponent: root.loginMode ? loginComponent : lockComponent
            }

            Component {
                id: lockComponent
                LockSurface {
                    context: lockContext
                    renderScene: lockWindow.screen === lock.renderScreen
                }
            }

            Component {
                id: loginComponent
                LoginSurface {
                    context: lockContext
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen(); }
        function login(): void {
            lockContext.reset();
            root.loginMode = true;
            lock.locked = true;
        }
    }

    function lockScreen() {
        lockContext.reset();
        lock.locked = true;
    }
}
