pragma Singleton
import Quickshell

Singleton {
    function copy(text: string, title: string): void {
        if (!text)
            return;
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy && notify-send \"$2\" \"$1 was copied to the clipboard\"", "sh", text, title]);
    }
}
