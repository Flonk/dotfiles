pragma Singleton
import QtQuick

QtObject {
  property bool visible: false
  function toggle() { visible = !visible; }
  function hide() { visible = false; }
}
