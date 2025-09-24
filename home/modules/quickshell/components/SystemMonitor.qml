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

    // Helper functions for display
    function getCpuText(): string {
        return `${Math.round(cpuUsage * 100)}%`;
    }
    
    function getMemoryText(): string {
        const fmt = formatBytes(memoryUsed);
        return `${fmt.value.toFixed(1)}${fmt.unit}`;
    }

    // Icons for different metrics
    function getCpuIcon(): string { return "💻"; }
    function getMemoryIcon(): string { return "🧠"; }
}