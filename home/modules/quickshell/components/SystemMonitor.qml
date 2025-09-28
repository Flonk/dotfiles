// SystemMonitor.qml
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // CPU properties
    property real cpuUsage: 0
    property real cpuTemp: 0
    property real lastCpuTotal: 0
    property real lastCpuIdle: 0
    
    // Per-core CPU usage
    property var coreUsages: []
    property var lastCoreStats: []
    property int coreCount: 0

    // Memory properties
    property real memoryUsed: 0
    property real memoryTotal: 1
    property real memoryUsage: memoryTotal > 0 ? memoryUsed / memoryTotal : 0

    // Battery properties
    property real batteryLevel: 0.5
    property bool isCharging: false
    property bool hasBattery: false
    property string batteryStatus: "Unknown"

    // Disk space properties
    property real diskUsed: 0
    property real diskTotal: 1
    property real diskFree: 0
    property real diskUsage: diskTotal > 0 ? diskUsed / diskTotal : 0

    // Update interval
    property int updateInterval: 3000

    // Format bytes nicely
    function formatBytes(bytes: real): var {
        const kb = 1024;
        const mb = kb * 1024;
        const gb = mb * 1024;
        const tb = gb * 1024;

        if (bytes >= tb) return { value: bytes / tb, unit: "TB" };
        if (bytes >= gb) return { value: bytes / gb, unit: "GB" };
        if (bytes >= mb) return { value: bytes / mb, unit: "MB" };
        if (bytes >= kb) return { value: bytes / kb, unit: "KB" };
        return { value: bytes, unit: "B" };
    }

    // Update timer
    Timer {
        running: true
        interval: root.updateInterval
        repeat: true
        triggeredOnStart: true
        
        onTriggered: {
            cpuStatFile.reload();
            memInfoFile.reload();
            updateBatteryInfo();
            updateDiskInfo();
        }
    }

    // CPU monitoring via /proc/stat
    FileView {
        id: cpuStatFile
        path: "/proc/stat"
        
        onLoaded: {
            const lines = text().split('\n');
            
            // Parse overall CPU usage (first line)
            const cpuLine = lines[0];
            const match = cpuLine.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
            
            if (match) {
                const stats = match.slice(1).map(n => parseInt(n, 10));
                const total = stats.reduce((a, b) => a + b, 0);
                const idle = stats[3] + (stats[4] || 0); // idle + iowait

                if (root.lastCpuTotal > 0) {
                    const totalDiff = total - root.lastCpuTotal;
                    const idleDiff = idle - root.lastCpuIdle;
                    root.cpuUsage = totalDiff > 0 ? Math.max(0, (1 - idleDiff / totalDiff)) : 0;
                }

                root.lastCpuTotal = total;
                root.lastCpuIdle = idle;
            }
            
            // Parse per-core CPU usage
            const newCoreUsages = [];
            const newCoreStats = [];
            let coreIndex = 0;
            
            for (let i = 1; i < lines.length; i++) {
                const line = lines[i];
                const coreMatch = line.match(/^cpu(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/);
                
                if (coreMatch) {
                    const coreNum = parseInt(coreMatch[1], 10);
                    const coreStats = coreMatch.slice(2).map(n => parseInt(n, 10));
                    const coreTotal = coreStats.reduce((a, b) => a + b, 0);
                    const coreIdle = coreStats[3] + (coreStats[4] || 0);
                    
                    newCoreStats[coreNum] = { total: coreTotal, idle: coreIdle };
                    
                    // Calculate usage if we have previous data
                    if (root.lastCoreStats[coreNum]) {
                        const totalDiff = coreTotal - root.lastCoreStats[coreNum].total;
                        const idleDiff = coreIdle - root.lastCoreStats[coreNum].idle;
                        newCoreUsages[coreNum] = totalDiff > 0 ? Math.max(0, (1 - idleDiff / totalDiff)) : 0;
                    } else {
                        newCoreUsages[coreNum] = 0;
                    }
                    coreIndex++;
                } else {
                    break; // No more CPU cores
                }
            }
            
            root.coreCount = coreIndex;
            root.coreUsages = newCoreUsages;
            root.lastCoreStats = newCoreStats;
        }
    }

    // Memory monitoring via /proc/meminfo
    FileView {
        id: memInfoFile
        path: "/proc/meminfo"
        
        onLoaded: {
            const data = text();
            const totalMatch = data.match(/MemTotal:\s*(\d+)\s*kB/);
            const availMatch = data.match(/MemAvailable:\s*(\d+)\s*kB/);
            
            if (totalMatch) {
                root.memoryTotal = parseInt(totalMatch[1], 10) * 1024; // Convert to bytes
            }
            
            if (availMatch && totalMatch) {
                const available = parseInt(availMatch[1], 10) * 1024; // Convert to bytes
                root.memoryUsed = root.memoryTotal - available;
            }
        }
    }

    // Battery monitoring functions and process
    function updateBatteryInfo(): void {
        batteryProc.running = true;
    }

    Process {
        id: batteryProc
        
        command: ["sh", "-c", "find /sys/class/power_supply -name 'BAT*' | head -1 | xargs -I {} sh -c 'echo $(cat {}/capacity) $(cat {}/status)'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output && output !== "") {
                    const parts = output.split(/\s+/);
                    if (parts.length >= 2) {
                        root.hasBattery = true;
                        root.batteryLevel = parseInt(parts[0], 10) / 100.0;
                        root.batteryStatus = parts[1];
                        root.isCharging = parts[1] === "Charging";
                    } else {
                        root.hasBattery = false;
                    }
                } else {
                    root.hasBattery = false;
                }
            }
        }
        
        onExited: (code) => {
            if (code !== 0) {
                root.hasBattery = false;
            }
        }
    }

    // Disk space monitoring functions and process
    function updateDiskInfo(): void {
        diskProc.running = true;
    }

    Process {
        id: diskProc
        
        command: ["df", "-B1", "/"]  // Get disk usage in bytes for root filesystem
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                const lines = output.split('\n');
                if (lines.length >= 2) {
                    const parts = lines[1].split(/\s+/);
                    if (parts.length >= 4) {
                        root.diskTotal = parseInt(parts[1], 10);
                        root.diskUsed = parseInt(parts[2], 10);
                        root.diskFree = parseInt(parts[3], 10);
                    }
                }
            }
        }
    }

    // Helper functions for display
    function getCpuText(): string {
        return `${Math.round(cpuUsage * 100)}%`;
    }
    
    function getMemoryText(): string {
        const fmt = formatBytes(memoryUsed);
        return `${fmt.value.toFixed(1)}${fmt.unit}`;
    }

    // Battery helper functions
    function getBatteryIcon(): string {
        if (!hasBattery) return "";
        
        if (isCharging) {
            return "🔌";
        }
        
        if (batteryLevel > 0.9) return "🔋";
        if (batteryLevel > 0.75) return "🔋";
        if (batteryLevel > 0.5) return "🔋";
        if (batteryLevel > 0.25) return "🪫";
        return "🪫";
    }

    function getBatteryText(): string {
        return hasBattery ? `${Math.round(batteryLevel * 100)}%` : "";
    }
    
    function getChargingIndicator(): string {
        if (!hasBattery) return "";
        return isCharging ? " ⚡" : "";
    }

    // Battery color helper - determines appropriate color based on level and charging state
    function getBatteryColorState(): string {
        if (!hasBattery) return "charging";        // Green - no battery means plugged in
        
        if (batteryLevel >= 0.95) return "charging";  // Green - full battery (must be charging to stay full)
        if (isCharging) return "charging";         // Green - actively charging
        if (batteryLevel <= 0.2) return "critical";   // Red - critically low
        
        return "normal";                           // Window manager color for everything else
    }

    // Disk helper functions
    function getDiskText(): string {
        const fmt = formatBytes(diskFree);
        return `${fmt.value.toFixed(1)}${fmt.unit}`;
    }

    function getDiskUsageText(): string {
        return `${Math.round(diskUsage * 100)}%`;
    }

    // Icons for different metrics
    function getCpuIcon(): string { return "💻"; }
    function getMemoryIcon(): string { return "🧠"; }
    function getBatteryIconForDisplay(): string { return getBatteryIcon(); }
    function getDiskIcon(): string { return "💾"; }
}