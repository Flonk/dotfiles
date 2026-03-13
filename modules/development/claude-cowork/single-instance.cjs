// Single-instance lock for Claude Desktop on Linux.
//
// Loaded via NODE_OPTIONS="--require=<this>" BEFORE frame-fix-wrapper.js
// spoofs process.platform to 'darwin'.
//
// Why this matters:
//   Electron's requestSingleInstanceLock() uses platform-specific mechanisms.
//   On Linux it creates a file lock + Unix socket. On macOS it uses
//   NSDistributedNotifications. Since the stubs spoof darwin AFTER this runs,
//   we get the real Linux locking mechanism.
//
// Flow:
//   1. First launch: acquires lock, registers second-instance listener
//   2. Browser redirects to claude://callback?code=...
//   3. xdg-open → desktop entry → claude-desktop claude://callback?code=...
//   4. Second electron starts, tries lock, FAILS
//   5. Electron sends argv to first instance via the lock socket
//   6. Second instance exits immediately
//   7. First instance receives second-instance event with the callback URL
//   8. We emit open-url so the renderer's auth flow completes

// NODE_OPTIONS affects ALL Node.js processes (asar, npm, etc.), not just Electron.
// Skip silently when loaded by regular Node.js (e.g. `asar pack` in launch.sh).
if (!process.versions.electron) return;

// At --require time, `require('electron')` isn't available yet.
// We hook into Electron's internal module loader to intercept the app module
// the moment it becomes available (before the main entry point runs).
const Module = require("module");
const originalLoad = Module._load;
let patched = false;

Module._load = function (request, parent, isMain) {
  const result = originalLoad.apply(this, arguments);

  // Intercept the first require('electron') from the app's entry point.
  if (!patched && request === "electron" && result && result.app) {
    patched = true;
    const app = result.app;

    const gotTheLock = app.requestSingleInstanceLock();

    if (!gotTheLock) {
      // Second instance — argv (including the claude:// URL) was already sent
      // to the first instance via the lock socket. Exit before the app loads.
      process.exit(0);
    }

    // First instance — listen for URLs forwarded from subsequent launches.
    app.on("second-instance", (_event, argv, _workingDirectory) => {
      const url = argv.find(
        (arg) => typeof arg === "string" && arg.startsWith("claude://"),
      );
      if (url) {
        console.log(
          "[single-instance] Forwarding callback URL to renderer:",
          url,
        );
        app.emit("open-url", { preventDefault: () => {} }, url);
      }

      // Focus the main window so the user sees the auth complete.
      try {
        const { BrowserWindow } = require("electron");
        const windows = BrowserWindow.getAllWindows();
        if (windows.length > 0) {
          const win = windows[0];
          if (win.isMinimized()) win.restore();
          win.focus();
        }
      } catch (_) {
        // Window focus is best-effort.
      }
    });
  }

  return result;
};
