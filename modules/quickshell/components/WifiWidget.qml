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
    property bool isEnabled: true

    // Interface + throughput tracking
    property string interfaceName: "wlan0"
    property real uploadRate: 0
    property real downloadRate: 0
    property real lastRxBytes: 0
    property real lastTxBytes: 0
    property int networkSampleInterval: 5000
    property int networkInfoInterval: 10000
    property int publicIpInterval: 300000
    property real downloadWarningThresholdBytesPerSec: (30 * 1000 * 1000) / 8
    property real uploadWarningThresholdBytesPerSec: (10 * 1000 * 1000) / 8
    property bool isHighTraffic: false

    // Network info
    property string localIp: ""
    property string gatewayIp: ""
    property string publicIp: ""

    function refresh() {
        checkConnectionStatus.running = true;
    }

    function sendNotification(message, title) {
        if (!message || !message.length) return;
        const notifyTitle = title && title.length ? title : "WiFi";
        notificationProcess.command = ["notify-send", "-u", "low", notifyTitle, message];
        notificationProcess.running = true;
    }

    function copyToClipboard(text) {
        if (!text || !text.length) return;
        clipboardProcess.command = ["wl-copy", text];
        clipboardProcess.running = true;
    }

    function toggleWifi() {
        if (root.isEnabled) {
            disableWifi.running = true;
            sendNotification("Disabling WiFi...");
        } else {
            enableWifi.running = true;
            sendNotification("Enabling WiFi...");
        }
    }

    function rescan() {
        scanNetworks.running = true;
    }

    function detectInterface() {
        deviceStatusProc.running = true;
    }

    function handleDisconnectCleanup() {
        clearNetworkRates();
        clearNetworkInfo();
        root.publicIp = "";
        root.isHighTraffic = false;
    }

    function clearNetworkRates() {
        root.uploadRate = 0;
        root.downloadRate = 0;
        root.lastRxBytes = 0;
        root.lastTxBytes = 0;
        root.isHighTraffic = false;
    }

    function updateTrafficWarning() {
        const downloadExceeded = root.downloadRate >= root.downloadWarningThresholdBytesPerSec;
        const uploadExceeded = root.uploadRate >= root.uploadWarningThresholdBytesPerSec;
        const highTraffic = downloadExceeded || uploadExceeded;
        if (highTraffic !== root.isHighTraffic) {
            console.log("[WifiWidget] traffic", JSON.stringify({
                downloadRate: root.downloadRate,
                uploadRate: root.uploadRate,
                downloadExceeded: downloadExceeded,
                uploadExceeded: uploadExceeded,
                highTraffic: highTraffic
            }));
        }
        root.isHighTraffic = highTraffic;
    }

    function clearNetworkInfo() {
        root.localIp = "";
        root.gatewayIp = "";
    }

    function shellEscape(str) {
        return (str || "").replace(/[^A-Za-z0-9_\-:.]/g, "");
    }

    function updateNetworkInfo() {
        if (!root.isConnected) {
            root.clearNetworkInfo();
            return;
        }
        const iface = shellEscape(root.interfaceName || "wlan0");
        if (!iface) return;
        const localCmd = "ip -4 addr show dev " + iface + " | awk '$1==\"inet\" {print $2; exit}' | cut -d/ -f1";
        if (!localIpProc.running) {
            localIpProc.command = ["sh", "-c", localCmd];
            localIpProc.running = true;
        }
        if (!gatewayProc.running) {
            gatewayProc.running = true;
        }
    }

    function updatePublicIp() {
        if (!root.isConnected) {
            root.publicIp = "";
            return;
        }
        if (!publicIpProc.running) {
            publicIpProc.running = true;
        }
    }

    onInterfaceNameChanged: {
        clearNetworkRates();
        if (root.isConnected) updateNetworkInfo();
    }

    function connect(ssid) {
        connectProcess.command = ["nmcli", "device", "wifi", "connect", ssid];
        connectProcess.running = true;
        sendNotification("Connecting to " + ssid + "...");
    }

    function disconnect() {
        disconnectProcess.running = true;
        sendNotification("Disconnecting...");
    }

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
                    root.handleDisconnectCleanup();
                } else {
                    root.updateNetworkInfo();
                    root.updatePublicIp();
                }
                root.detectInterface();
            }
        }
    }

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
                        if (ssid !== root.connectedSsid && !networks.find(n => n.ssid === ssid)) {
                            networks.push({
                                ssid: ssid,
                                signal: parseInt(signal),
                                secure: security !== ""
                            });
                        }
                    }
                }
                networks.sort((a, b) => b.signal - a.signal);
                root.availableNetworks = networks;
            }
        }
    }

    Process {
        id: deviceStatusProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split('\n');
                for (let line of lines) {
                    if (!line) continue;
                    const parts = line.split(':');
                    if (parts.length < 3) continue;
                    const device = parts[0];
                    const type = parts[1];
                    const state = parts[2];
                    if (type === "wifi" && state.startsWith("connected")) {
                        root.interfaceName = device;
                        root.updateNetworkInfo();
                        return;
                    }
                }
            }
        }
    }

    Process {
        id: connectProcess

        stdout: SplitParser {
            onRead: data => {
                root.refresh();
                root.rescan();
            }
        }
    }

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

    Process {
        id: enableWifi
        command: ["nmcli", "radio", "wifi", "on"]

        stdout: SplitParser {
            onRead: data => {
                root.isEnabled = true;
                root.refresh();
                root.rescan();
            }
        }
    }

    Process {
        id: disableWifi
        command: ["nmcli", "radio", "wifi", "off"]

        stdout: SplitParser {
            onRead: data => {
                root.isEnabled = false;
                root.isConnected = false;
                root.connectedSsid = "";
                root.availableNetworks = [];
                root.handleDisconnectCleanup();
            }
        }
    }

    Process {
        id: notificationProcess
    }

    Process {
        id: clipboardProcess
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.rescan()
    }

    Timer {
        id: networkSampleTimer
        interval: root.networkSampleInterval
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.isConnected) {
                root.clearNetworkRates();
                return;
            }
            if (!networkStatsProc.running) {
                const iface = shellEscape(root.interfaceName || "wlan0");
                networkStatsProc.command = [
                    "sh",
                    "-c",
                    "cat /sys/class/net/" + iface + "/statistics/rx_bytes /sys/class/net/" + iface + "/statistics/tx_bytes"
                ];
                networkStatsProc.running = true;
            }
        }
    }

    Timer {
        id: networkInfoTimer
        interval: root.networkInfoInterval
        running: true
        repeat: true
        onTriggered: root.updateNetworkInfo()
    }

    Timer {
        id: publicIpTimer
        interval: root.publicIpInterval
        running: true
        repeat: true
        onTriggered: root.updatePublicIp()
    }

    Process {
        id: networkStatsProc
        command: ["sh", "-c", "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length >= 2) {
                    const rxBytes = parseInt(parts[0], 10);
                    const txBytes = parseInt(parts[1], 10);
                    const intervalSeconds = Math.max(1, root.networkSampleInterval / 1000);
                    if (root.lastRxBytes > 0) {
                        root.downloadRate = Math.max(0, (rxBytes - root.lastRxBytes) / intervalSeconds);
                    }
                    if (root.lastTxBytes > 0) {
                        root.uploadRate = Math.max(0, (txBytes - root.lastTxBytes) / intervalSeconds);
                    }
                    root.lastRxBytes = rxBytes;
                    root.lastTxBytes = txBytes;
                    root.updateTrafficWarning();
                }
            }
        }
        onExited: (code) => {
            if (code !== 0) {
                root.clearNetworkRates();
            }
        }
    }

    Process {
        id: localIpProc
        command: ["sh", "-c", "true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.localIp = text.trim();
            }
        }
        onExited: (code) => {
            if (code !== 0) root.localIp = "";
        }
    }

    Process {
        id: gatewayProc
        command: ["sh", "-c", "ip route show default | awk '/default/ {print $3; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.gatewayIp = text.trim();
            }
        }
        onExited: (code) => {
            if (code !== 0) root.gatewayIp = "";
        }
    }

    Process {
        id: publicIpProc
        command: ["sh", "-c", "curl -s -4 https://ifconfig.me 2>/dev/null || curl -s -6 https://ifconfig.me 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.publicIp = text.trim();
            }
        }
        onExited: (code) => {
            if (code !== 0) root.publicIp = "";
        }
    }
}
