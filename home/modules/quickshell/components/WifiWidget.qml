// WifiWidget.qml - WiFi state management singleton
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    
    property bool isConnected: false
    property string connectedSsid: ""
    property var availableNetworks: []
    
    // Refresh WiFi status
    function refresh() {
        checkConnectionStatus.running = true;
    }
    
    function rescan() {
        scanNetworks.running = true;
    }
    
    // Connect to a network
    function connect(ssid) {
        connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid];
        connectProcess.running = true;
    }
    
    // Disconnect from current network
    // Disconnect from current network
    function disconnect() {
        disconnectProcess.running = true;
    }
    // Check if currently connected
    Process {
        id: checkConnectionStatus
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "device", "wifi", "list"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text;
                const lines = output.split('\n');
                let found = false;
                for (let line of lines) {
                    if (line.startsWith('yes:')) {
                        root.isConnected = true;
                        root.connectedSsid = line.substring(4);
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    root.isConnected = false;
                    root.connectedSsid = "";
                }
            }
        }
    }
    
    // Scan for available networks
    Process {
        id: scanNetworks
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "device", "wifi", "list"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text;
                const lines = output.split('\n');
                let networks = [];
                for (let line of lines) {
                    const parts = line.split(':');
                    if (parts.length >= 2 && parts[0]) {
                        const ssid = parts[0];
                        const signal = parts[1] || "0";
                        const security = parts[2] || "";
                        // Skip if already in list or is the connected network
                        if (ssid !== root.connectedSsid && !networks.find(n => n.ssid === ssid)) {
                            networks.push({
                                ssid: ssid,
                                signal: parseInt(signal),
                                secure: security !== ""
                            });
                        }
                    }
                }
                // Sort by signal strength
                networks.sort((a, b) => b.signal - a.signal);
                root.availableNetworks = networks;
            }
        }
    }
    
    // Connect to network process
    Process {
        id: connectProcess
        
        stdout: SplitParser {
            onRead: data => {
                root.refresh();
                root.rescan();
            }
        }
    }
    
    // Disconnect process
    Process {
        id: disconnectProcess
        command: ["nmcli", "device", "disconnect", "wlan0"]
        
        stdout: SplitParser {
            onRead: data => {
                root.refresh();
                root.rescan();
            }
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    
    // Rescan networks every 30 seconds
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.rescan()
    }
}
