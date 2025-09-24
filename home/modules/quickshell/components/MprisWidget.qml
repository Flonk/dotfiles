// MprisWidget.qml
pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    // Get the current player (first playing one, or first available)
    property var currentPlayer: {
        if (!Mpris.players || !Mpris.players.values || Mpris.players.values.length === 0) {
            return null;
        }
        
        const players = Mpris.players.values;
        
        // Try to find a playing player first
        for (let i = 0; i < players.length; i++) {
            const player = players[i];
            if (player && player.isPlaying) {
                return player;
            }
        }
        
        // If no playing player, return the first one
        return players[0];
    }

    // Formatted track info: "artist - title"
    property string currentTrack: {
        if (!currentPlayer) return "";
        
        const artist = currentPlayer.trackArtist || "";
        const title = currentPlayer.trackTitle || "";
        
        if (!artist && !title) return "";
        if (!artist) return title;
        if (!title) return artist;
        
        return `${artist} - ${title}`;
    }

    // Whether any player is currently playing
    property bool isPlaying: currentPlayer?.isPlaying || false
}