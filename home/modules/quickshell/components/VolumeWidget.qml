// VolumeWidget.qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Volume properties
    property real volume: 0.5
    property bool muted: false
    property real audioIncrement: 0.005

    // Timer for periodic volume updates
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateVolume()
    }

    // Process to get current volume
    Process {
        id: volumeProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                // Expected output: "Volume: 0.79" or "Volume: 0.79 [MUTED]"
                const output = text.trim();
                const match = output.match(/Volume:\s+([\d.]+)(\s+\[MUTED\])?/);
                
                if (match) {
                    root.volume = parseFloat(match[1]) || 0;
                    root.muted = !!match[2];
                } else {
                    console.log("VolumeWidget: Failed to parse volume output:", output);
                }
            }
        }
        
        onExited: (code) => {
            if (code !== 0) {
                console.log("VolumeWidget: wpctl command failed with code", code);
            }
        }
    }

    function updateVolume(): void {
        if (!volumeProc.running) {
            volumeProc.running = true;
        }
    }

    // Volume control functions
    function setVolume(newVolume: real): void {
        const clampedVolume = Math.max(0, Math.min(1, newVolume));
        
        // Update local state immediately for responsive UI
        root.volume = clampedVolume;
        
        const volumeStr = `${Math.round(clampedVolume * 100)}%`;
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volumeStr]);
        // Don't call updateVolume() here - let the timer handle syncing
    }

    function incrementVolume(): void {
        setVolume(volume + audioIncrement);
    }

    function decrementVolume(): void {
        setVolume(volume - audioIncrement);
    }

    function toggleMute(): void {
        // Update local state immediately for responsive UI
        root.muted = !root.muted;
        
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        // Don't call updateVolume() here - let the timer handle syncing
    }

    // Helper property for volume icon
    property string volumeIcon: {
        if (muted) return "🔇";
        if (volume > 0.66) return "🔊";
        if (volume > 0.33) return "🔉";
        if (volume > 0) return "🔈";
        return "🔇";
    }

    // Helper function for volume text
    property string volumeText: {
        if (muted) return "Muted";
        const vol = volume;
        if (isNaN(vol) || vol === undefined) return "---";
        return `${Math.round(vol * 100)}%`;
    }

    // Initialize on startup
    Component.onCompleted: {
        updateVolume();
    }
}