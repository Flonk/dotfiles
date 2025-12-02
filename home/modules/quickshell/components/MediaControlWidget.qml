// MediaControlWidget.qml - Media control state management singleton
pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Mirror Mpris service directly now that MprisWidget is gone
    property var currentPlayer: {
        if (!Mpris.players || !Mpris.players.values || Mpris.players.values.length === 0) {
            return null;
        }

        const players = Mpris.players.values;

        for (let i = 0; i < players.length; i++) {
            const player = players[i];
            if (player && player.isPlaying) {
                return player;
            }
        }

        return players[0];
    }

    property bool isPlaying: currentPlayer?.isPlaying || false
    property string currentTitle: currentPlayer?.trackTitle || ""
    property string currentArtist: currentPlayer?.trackArtist || ""
    property string albumArtUrl: currentPlayer?.trackArtUrl || ""

    function canGoPrevious() {
        return currentPlayer && currentPlayer.canGoPrevious;
    }

    function canGoNext() {
        return currentPlayer && currentPlayer.canGoNext;
    }

    function canTogglePlaying() {
        return currentPlayer && currentPlayer.canTogglePlaying;
    }

    function previous() {
        if (canGoPrevious()) {
            currentPlayer.previous();
        }
    }

    function next() {
        if (canGoNext()) {
            currentPlayer.next();
        }
    }

    function togglePlaying() {
        if (canTogglePlaying()) {
            currentPlayer.togglePlaying();
        }
    }
}
