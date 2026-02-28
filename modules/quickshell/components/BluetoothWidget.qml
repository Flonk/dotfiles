// BluetoothWidget.qml - Bluetooth state management singleton
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    
    property bool isEnabled: false
    property bool isScanning: false
    property var connectedDevices: []
    property var trustedDevices: []
    property var availableDevices: []
    
    // Refresh Bluetooth status
    function refresh() {
        checkBluetoothStatus.running = true;
        listDevices.running = true;
    }
    
    // Toggle Bluetooth on/off
    function toggleBluetooth() {
        if (root.isEnabled) {
            disableBluetooth.running = true;
            notificationProcess.command = ["notify-send", "-u", "low", "Bluetooth", "Disabling Bluetooth..."];
            notificationProcess.running = true;
        } else {
            enableBluetooth.running = true;
            notificationProcess.command = ["notify-send", "-u", "low", "Bluetooth", "Enabling Bluetooth..."];
            notificationProcess.running = true;
        }
    }
    
    // Toggle scanning
    function toggleScan() {
        if (root.isScanning) {
            stopScan.running = true;
            notificationProcess.command = ["notify-send", "-u", "low", "Bluetooth", "Stopping scan..."];
            notificationProcess.running = true;
        } else {
            startScan.running = true;
            notificationProcess.command = ["notify-send", "-u", "low", "Bluetooth", "Starting scan..."];
            notificationProcess.running = true;
        }
    }
    
    // Connect/pair to device
    function connectDevice(address, name) {
        connectProcess.command = ["bluetoothctl", "connect", address];
        connectProcess.running = true;
        notificationProcess.command = ["notify-send", "-u", "low", "Bluetooth", "Connecting to " + name + "..."];
        notificationProcess.running = true;
    }
    
    // Disconnect device
    function disconnectDevice(address, name) {
        disconnectProcess.command = ["bluetoothctl", "disconnect", address];
        disconnectProcess.running = true;
        notificationProcess.command = ["notify-send", "-u", "low", "Bluetooth", "Disconnecting " + name + "..."];
        notificationProcess.running = true;
    }
    
    // Check if Bluetooth is enabled
    Process {
        id: checkBluetoothStatus
        command: ["bluetoothctl", "show"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text;
                root.isEnabled = output.includes("Powered: yes");
                root.isScanning = output.includes("Discovering: yes");
            }
        }
    }
    
    // Enable Bluetooth
    Process {
        id: enableBluetooth
        command: ["bluetoothctl", "power", "on"]
        
        stdout: SplitParser {
            onRead: data => {
                root.refresh();
            }
        }
    }
    
    // Disable Bluetooth
    Process {
        id: disableBluetooth
        command: ["bluetoothctl", "power", "off"]
        
        stdout: SplitParser {
            onRead: data => {
                root.refresh();
            }
        }
    }
    
    // Start scanning
    Process {
        id: startScan
        command: ["bluetoothctl", "scan", "on"]
        
        stdout: SplitParser {
            onRead: data => {
                root.isScanning = true;
            }
        }
    }
    
    // Stop scanning
    Process {
        id: stopScan
        command: ["bluetoothctl", "scan", "off"]
        
        stdout: SplitParser {
            onRead: data => {
                root.isScanning = false;
            }
        }
    }
    
    // List devices
    Process {
        id: listDevices
        command: ["bluetoothctl", "devices"]
        running: true
        
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text;
                const lines = output.split('\n');
                let devices = [];
                
                // Clear lists at the start of processing
                let newConnected = [];
                let newTrusted = [];
                let newAvailable = [];
                
                for (let line of lines) {
                    // Format: "Device AA:BB:CC:DD:EE:FF Device Name"
                    const match = line.match(/Device\s+([0-9A-F:]+)\s+(.+)/i);
                    if (match) {
                        const address = match[1];
                        const name = match[2];
                        devices.push({ address: address, name: name, connected: false, trusted: false });
                    }
                }
                
                // Get connection and trust status for each device
                for (let device of devices) {
                    checkDeviceStatus(device, newConnected, newTrusted, newAvailable);
                }
            }
        }
    }
    
    // Check individual device status
    property int pendingDeviceChecks: 0
    property var tempConnected: []
    property var tempTrusted: []
    property var tempAvailable: []
    
    function checkDeviceStatus(device, connectedArr, trustedArr, availableArr) {
        root.pendingDeviceChecks++;
        const proc = Qt.createQmlObject(`
            import Quickshell
            import Quickshell.Io
            Process {
                command: ["bluetoothctl", "info", "${device.address}"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        const output = text;
                        const connected = output.includes("Connected: yes");
                        const trusted = output.includes("Trusted: yes");
                        
                        if (connected) {
                            root.tempConnected.push({ address: "${device.address}", name: "${device.name}", trusted: trusted });
                        } else if (trusted) {
                            root.tempTrusted.push({ address: "${device.address}", name: "${device.name}" });
                        } else {
                            root.tempAvailable.push({ address: "${device.address}", name: "${device.name}" });
                        }
                        
                        root.pendingDeviceChecks--;
                        if (root.pendingDeviceChecks === 0) {
                            // Update all lists at once when all checks complete
                            root.connectedDevices = root.tempConnected;
                            root.trustedDevices = root.tempTrusted;
                            root.availableDevices = root.tempAvailable;
                            root.tempConnected = [];
                            root.tempTrusted = [];
                            root.tempAvailable = [];
                        }
                    }
                }
            }
        `, root);
    }
    
    // Connect process
    Process {
        id: connectProcess
        
        stdout: SplitParser {
            onRead: data => {
                root.refresh();
            }
        }
    }
    
    // Disconnect process
    Process {
        id: disconnectProcess
        
        onExited: (code) => {
            // Force immediate refresh after disconnect
            root.refresh();
        }
        
        stdout: SplitParser {
            onRead: data => {}
        }
    }
    
    // Notification process
    Process {
        id: notificationProcess
    }
    
    // Status check timer
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    
    Component.onCompleted: {
        root.refresh();
    }
}
