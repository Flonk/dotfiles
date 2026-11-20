pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    readonly property var currentPlayer: {
        const players = Mpris.players?.values ?? [];
        return players.find(p => p?.isPlaying) ?? players[0] ?? null;
    }

    readonly property bool isPlaying: currentPlayer?.isPlaying ?? false
    readonly property string currentTitle: currentPlayer?.trackTitle ?? ""
    readonly property string currentArtist: currentPlayer?.trackArtist ?? ""

    function canGoPrevious(): bool {
        return currentPlayer?.canGoPrevious ?? false;
    }

    function canGoNext(): bool {
        return currentPlayer?.canGoNext ?? false;
    }

    function canTogglePlaying(): bool {
        return currentPlayer?.canTogglePlaying ?? false;
    }

    function previous(): void {
        if (canGoPrevious())
            currentPlayer.previous();
    }

    function next(): void {
        if (canGoNext())
            currentPlayer.next();
    }

    function togglePlaying(): void {
        if (canTogglePlaying())
            currentPlayer.togglePlaying();
    }
}
