import React, { useEffect, useState } from "react";
import { Box, render, Text, useApp } from "ink";
import { access, readdir, readFile } from "node:fs/promises";
import { execSync } from "node:child_process";
import { join } from "node:path";
import { $, quote } from "zx";

// --- Config ------------------------------------------------------------------

$.verbose = false;
$.quiet = true;
$.shell = "/bin/sh";
$.quote = quote;

const VIDEO_NR = 48;
const PORT = 8554;
const PID_FILE = "/run/gopro-webcam-ffmpeg.pid";
const LOG_FILE = "/tmp/gopro-webcam-ffmpeg.log";
const DEVICE_FILE = "/run/gopro-webcam-device";

const isRoot = (process.getuid?.() ?? -1) === 0;
const headless = !process.stdout.isTTY;
const GOPRO_USER = process.env.GOPRO_USER;

const RESOLUTIONS: Record<string, [gopro: string, size: string]> = {
  "1080": ["1080", "1920x1080"],
  "720": ["720", "1280x720"],
  "480": ["720", "854x480"], // GoPro rejects native 480; scale locally
};

const FOV_IDS: Record<string, number> = {
  wide: 0,
  narrow: 2,
  superview: 3,
  linear: 4,
};

// --- Types -------------------------------------------------------------------

interface Ctx {
  resolution: string;
  videoSize: string;
  fovId: number;
  videoDev?: string;
  goProApi?: string;
  goProIface?: string;
  goProIp?: string;
}

type Status = "pending" | "running" | "done" | "failed";

interface StepDef {
  label: string;
  run: (ctx: Ctx) => Promise<string | undefined>;
  soft?: boolean; // failure shows warning but doesn't abort
}

interface StepUI {
  label: string;
  status: Status;
  detail?: string;
  error?: string;
}

// --- Helpers -----------------------------------------------------------------

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// When running as root (systemd service), drop sudo.
// zx template helper: await root`cmd args` runs with sudo when needed.
function root(pieces: TemplateStringsArray, ...args: any[]) {
  if (isRoot) return $(pieces, ...args);
  const sudoPieces = [`sudo ${pieces[0]}`, ...pieces.slice(1)] as unknown as TemplateStringsArray;
  Object.defineProperty(sudoPieces, 'raw', { value: [`sudo ${pieces.raw[0]}`, ...pieces.raw.slice(1)] });
  return $(sudoPieces, ...args);
}

async function exists(path: string): Promise<boolean> {
  try {
    await access(path);
    return true;
  } catch {
    return false;
  }
}

// --- User-context helpers (for running as root from systemd) -----------------

let _userUid: string | undefined;
async function getUserUid(): Promise<string> {
  if (_userUid) return _userUid;
  if (!GOPRO_USER) throw new Error("GOPRO_USER not set");
  _userUid = (await $`id -u ${GOPRO_USER}`).stdout.trim();
  return _userUid;
}

async function systemctlUser(...args: string[]) {
  if (isRoot && GOPRO_USER) {
    const uid = await getUserUid();
    return $`runuser -u ${GOPRO_USER} -- env XDG_RUNTIME_DIR=${`/run/user/${uid}`} systemctl --user ${args}`.nothrow();
  }
  return $`systemctl --user ${args}`.nothrow();
}

async function sendNotify(...args: string[]): Promise<void> {
  if (isRoot && GOPRO_USER) {
    const uid = await getUserUid();
    await $`runuser -u ${GOPRO_USER} -- env XDG_RUNTIME_DIR=${`/run/user/${uid}`} DBUS_SESSION_BUS_ADDRESS=${`unix:path=/run/user/${uid}/bus`} notify-send ${args}`.nothrow();
  } else {
    await $`notify-send ${args}`.nothrow();
  }
}

// --- Steps: shared -----------------------------------------------------------

async function stopFfmpeg(): Promise<string | undefined> {
  let killed = false;

  // Stop the transient systemd service (preferred)
  const status = await root`systemctl is-active gopro-ffmpeg.service`.nothrow();
  if (status.stdout.trim() === "active") {
    await root`systemctl stop gopro-ffmpeg.service`.nothrow();
    killed = true;
  }
  await root`systemctl reset-failed gopro-ffmpeg.service`.nothrow();

  // Kill by PID file (fallback for old-style launches)
  if (await exists(PID_FILE)) {
    const pid = (await root`cat ${PID_FILE}`.nothrow()).stdout.trim();
    if (pid) {
      await root`kill ${pid}`.nothrow();
      for (let i = 0; i < 20; i++) {
        if ((await root`kill -0 ${pid}`.nothrow()).exitCode !== 0) break;
        await sleep(500);
      }
      await root`kill -9 ${pid}`.nothrow();
      killed = true;
    }
    await root`rm -f ${PID_FILE}`.nothrow();
  }

  // Catch strays
  const r1 = await root`pkill -f 'ffmpeg.*v4l2'`.nothrow();
  const r2 = await root`pkill -f 'ffmpeg.*8554'`.nothrow();
  if (r1.exitCode === 0 || r2.exitCode === 0) killed = true;

  if (killed) await sleep(1000);
  return killed ? undefined : "nothing running";
}

// --- Steps: start ------------------------------------------------------------

async function loadModule(ctx: Ctx): Promise<string> {
  let needWpRestart = false;

  if ((await $`lsmod`).stdout.includes("v4l2loopback")) {
    let unloaded = (await root`rmmod v4l2loopback`.nothrow()).exitCode === 0;

    if (!unloaded) {
      needWpRestart =
        (await systemctlUser("is-active", "wireplumber")).exitCode === 0;
      if (needWpRestart) await systemctlUser("stop", "wireplumber");
      await sleep(300);

      unloaded = (await root`rmmod v4l2loopback`.nothrow()).exitCode === 0;
      if (!unloaded) {
        await root`rmmod -f v4l2loopback`.nothrow();
      }
      await sleep(200);
    }
  }

  await root`modprobe v4l2loopback devices=1 exclusive_caps=1 max_buffers=2 card_label=GoPro video_nr=${VIDEO_NR}`;

  // Find the device in sysfs
  const base = "/sys/devices/virtual/video4linux";
  let found = false;
  for (const dir of await readdir(base)) {
    try {
      const name = await readFile(join(base, dir, "name"), "utf-8");
      if (name.includes("GoPro")) {
        ctx.videoDev = `/dev/${dir}`;
        await root`bash -c ${`echo ${ctx.videoDev} > ${DEVICE_FILE}`}`.nothrow();
        found = true;
        break;
      }
    } catch {}
  }
  if (!found) throw new Error("v4l2loopback loaded but no GoPro device appeared");

  // Set caps immediately so wireplumber sees a capture device (not just output)
  // when it processes the add event. Must happen before wireplumber restarts.
  const caps = `YU12:${ctx.videoSize}`;
  await root`v4l2loopback-ctl set-caps ${ctx.videoDev!} ${caps}`;

  if (needWpRestart) await systemctlUser("start", "wireplumber");

  return ctx.videoDev!;
}

async function discoverGoPro(ctx: Ctx): Promise<string> {
  // When triggered by udev, the network interface may not be ready yet.
  const maxAttempts = headless ? 15 : 3;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    const { stdout } = await $`ip -4 -j addr show`;
    for (const iface of JSON.parse(stdout)) {
      for (const addr of iface.addr_info ?? []) {
        if (/^172\.2\d\./.test(addr.local)) {
          const [a, b, c] = addr.local.split(".");
          ctx.goProApi = `http://${a}.${b}.${c}.51`;
          ctx.goProIface = iface.ifname;
          ctx.goProIp = addr.local;
          return `${iface.ifname} (${addr.local})`;
        }
      }
    }
    if (attempt < maxAttempts - 1) await sleep(2000);
  }

  throw new Error(
    "No GoPro USB interface found (expected 172.2x.x.x).\nIs the GoPro plugged in and powered on?",
  );
}

async function activateWebcam(ctx: Ctx): Promise<string | undefined> {
  const r =
    await $`curl -sf --connect-timeout 3 ${ctx.goProApi}/gp/gpWebcam/START?res=${ctx.resolution}&port=${PORT}`.nothrow();

  // Set FOV (best effort)
  await $`curl -sf --connect-timeout 3 ${ctx.goProApi}/gp/gpWebcam/SETTINGS?fov=${ctx.fovId}`.nothrow();

  return r.exitCode !== 0 ? "already streaming" : undefined;
}

async function startFfmpeg(ctx: Ctx): Promise<string> {
  // Raise kernel UDP buffer limit
  await root`sysctl -w net.core.rmem_max=16777216`.nothrow();

  // Stop any leftover transient unit from a previous run
  await root`systemctl stop gopro-ffmpeg.service`.nothrow();
  await root`systemctl reset-failed gopro-ffmpeg.service`.nothrow();

  // Launch ffmpeg as a transient systemd service with memory limits.
  // This keeps it in a tracked cgroup so it can't OOM the whole system.
  const cmd = [
    `systemd-run`,
    `--unit=gopro-ffmpeg`,
    `--property=MemoryMax=2G`,
    `--property=MemoryHigh=1G`,
    `--property=StandardOutput=file:${LOG_FILE}`,
    `--property=StandardError=file:${LOG_FILE}`,
    `--`,
    `ffmpeg`,
    `-nostdin -use_wallclock_as_timestamps 1`,
    `-f mpegts -fflags nobuffer+discardcorrupt -flags low_delay`,
    `-max_delay 0`,
    `-analyzeduration 256k -probesize 256k`,
    `-skip_frame noref -flags2 fast`,
    `-i 'udp://@0.0.0.0:${PORT}?overrun_nonfatal=1&fifo_size=50000&buffer_size=16777216'`,
    `-map 0:v -vf 'format=yuv420p'`,
    `-fps_mode passthrough -codec:v rawvideo -pix_fmt yuv420p`,
    `-flush_packets 1`,
    `-f v4l2 ${ctx.videoDev}`,
  ].join(" ");

  if (isRoot) {
    await $({ input: cmd })`bash`;
  } else {
    await $({ input: cmd })`sudo bash`;
  }

  // Give ffmpeg a moment to start (or crash)
  await sleep(2000);

  // Verify it's alive via systemd
  const status = await root`systemctl is-active gopro-ffmpeg.service`.nothrow();
  if (status.stdout.trim() === "active") {
    // Write PID file for the stop function
    const mainPid = (await root`systemctl show -p MainPID --value gopro-ffmpeg.service`.nothrow()).stdout.trim();
    if (mainPid && mainPid !== "0") {
      await root`bash -c ${`echo ${mainPid} > ${PID_FILE}`}`.nothrow();
    }
    return "streaming";
  }

  const log = (await $`tail -20 ${LOG_FILE}`.nothrow()).stdout;
  throw new Error(`ffmpeg exited:\n${log}`);
}

// --- Steps: stop -------------------------------------------------------------

async function unloadModule(): Promise<string | undefined> {
  if (!(await $`lsmod`).stdout.includes("v4l2loopback")) return "not loaded";

  for (let i = 0; i < 6; i++) {
    if ((await root`rmmod v4l2loopback`.nothrow()).exitCode === 0) {
      await root`rm -f ${DEVICE_FILE}`.nothrow();
      return undefined;
    }
    await sleep(1000);
  }

  await root`rm -f ${DEVICE_FILE}`.nothrow();
  return "still loaded (harmless)";
}

// --- Headless runner ---------------------------------------------------------

async function runHeadless(
  stepDefs: StepDef[],
  title: string,
  ctx: Ctx,
  onDone?: (ctx: Ctx) => Promise<void>,
) {
  console.log(`GoPro Webcam — ${title}`);
  for (const step of stepDefs) {
    try {
      const detail = await step.run(ctx);
      console.log(`  ✓ ${step.label}${detail ? ` → ${detail}` : ""}`);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (step.soft) {
        console.log(`  ⚠ ${step.label} → ${msg}`);
      } else {
        console.error(`  ✗ ${step.label} → ${msg}`);
        process.exit(1);
      }
    }
  }
  if (onDone) await onDone(ctx);
}

// --- UI Components -----------------------------------------------------------

const FRAMES = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function Spinner() {
  const [i, setI] = useState(0);
  useEffect(() => {
    const t = setInterval(() => setI((n) => (n + 1) % FRAMES.length), 80);
    return () => clearInterval(t);
  }, []);
  return <Text color="yellow">{FRAMES[i]}</Text>;
}

function StepRow({ step }: { step: StepUI }) {
  const icon =
    step.status === "done" ? "✓" : step.status === "failed" ? "✗" : "○";
  const color =
    step.status === "done"
      ? "green"
      : step.status === "failed"
        ? "red"
        : "gray";

  return (
    <Box flexDirection="column">
      <Box>
        <Text>{"  "}</Text>
        {step.status === "running" ? (
          <Spinner />
        ) : (
          <Text color={color}>{icon}</Text>
        )}
        <Text> </Text>
        <Text dimColor={step.status === "pending"}>{step.label}</Text>
        {step.detail && <Text color="gray"> → {step.detail}</Text>}
      </Box>
      {step.error && (
        <Box marginLeft={5}>
          <Text color="red">{step.error}</Text>
        </Box>
      )}
    </Box>
  );
}

// --- App ---------------------------------------------------------------------

function App({
  stepDefs,
  title,
  ctx,
  onDone,
}: {
  stepDefs: StepDef[];
  title: string;
  ctx: Ctx;
  onDone?: (ctx: Ctx) => Promise<void>;
}) {
  const { exit } = useApp();
  const [steps, setSteps] = useState<StepUI[]>(
    stepDefs.map((s) => ({ label: s.label, status: "pending" as Status })),
  );

  const update = (i: number, patch: Partial<StepUI>) =>
    setSteps((prev) => prev.map((s, j) => (j === i ? { ...s, ...patch } : s)));

  useEffect(() => {
    let cancelled = false;

    (async () => {
      for (let i = 0; i < stepDefs.length; i++) {
        if (cancelled) return;
        update(i, { status: "running" });
        try {
          const detail = await stepDefs[i].run(ctx);
          update(i, { status: "done", detail: detail ?? undefined });
        } catch (e: unknown) {
          const msg = e instanceof Error ? e.message : String(e);
          update(i, { status: "failed", error: msg });
          if (!stepDefs[i].soft) {
            process.exitCode = 1;
            await sleep(100);
            exit();
            return;
          }
          // Soft failure — mark done with warning and continue
          update(i, { status: "done", detail: msg });
        }
      }

      // Send desktop notification on success
      if (onDone) await onDone(ctx);

      await sleep(100);
      exit();
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <Box flexDirection="column" paddingY={1}>
      <Box marginBottom={1}>
        <Text bold>{" GoPro Webcam"}</Text>
        <Text color="gray"> — {title}</Text>
      </Box>
      {steps.map((step, i) => (
        <StepRow key={i} step={step} />
      ))}
    </Box>
  );
}

// --- Main --------------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);
  const action = args[0] ?? "start";

  if (action === "help" || action === "--help" || action === "-h") {
    console.log(
      "Usage: gopro [start|stop] [1080|720|480] [linear|wide|narrow|superview]",
    );
    process.exit(0);
  }

  if (!["start", "stop"].includes(action)) {
    console.log(
      "Usage: gopro [start|stop] [1080|720|480] [linear|wide|narrow|superview]",
    );
    process.exit(1);
  }

  const resKey = args[1] ?? "1080";
  const fovKey = args[2] ?? "linear";

  if (!(resKey in RESOLUTIONS)) {
    console.error(`Invalid resolution: ${resKey}. Choose 1080, 720, or 480.`);
    process.exit(1);
  }
  if (!(fovKey in FOV_IDS)) {
    console.error(
      `Invalid FOV: ${fovKey}. Choose linear, wide, narrow, or superview.`,
    );
    process.exit(1);
  }

  const [resolution, videoSize] = RESOLUTIONS[resKey];
  const ctx: Ctx = { resolution, videoSize, fovId: FOV_IDS[fovKey] };

  // Authenticate sudo before ink takes over the terminal (skip when already root)
  if (!isRoot) {
    try {
      await $`sudo -v`;
    } catch {
      console.error("sudo authentication required.");
      process.exit(1);
    }
  }

  // Fire-and-forget low priority notification at the start
  if (action === "start") {
    sendNotify("-t", "2000", "-u", "low", "-i", "camera-web", "🎥 GoPro starting...");
  } else if (action === "stop") {
    sendNotify("-t", "2000", "-u", "low", "-i", "camera-web", "🎥 GoPro stopping...");
  }

  const startSteps: StepDef[] = [
    { label: "Stop previous session", run: () => stopFfmpeg() },
    { label: "Load v4l2loopback", run: (c) => loadModule(c) },
    { label: "Discover GoPro", run: (c) => discoverGoPro(c) },
    {
      label: "Activate webcam mode",
      run: (c) => activateWebcam(c),
      soft: true,
    },
    { label: "Start ffmpeg", run: (c) => startFfmpeg(c) },
  ];

  const stopSteps: StepDef[] = [
    { label: "Stop ffmpeg", run: () => stopFfmpeg() },
    { label: "Unload v4l2loopback", run: () => unloadModule() },
  ];

  const stepDefs = action === "start" ? startSteps : stopSteps;
  const title =
    action === "start" ? `Starting (${resKey}p, ${fovKey})` : "Stopping";

  const notify = async (c: Ctx) => {
    if (action === "start") {
      const body = [
        `Device: ${c.videoDev}`,
        `Interface: ${c.goProIface} (${c.goProIp})`,
        `Resolution: ${c.videoSize}`,
      ].join("\n");
      await sendNotify("-i", "camera-web", "🎥 GoPro started!", body);
    } else {
      await sendNotify("-i", "camera-web", "🎥 GoPro stopped.");
    }
  };

  if (headless) {
    await runHeadless(stepDefs, title, ctx, notify);
  } else {
    const { waitUntilExit } = render(
      <App stepDefs={stepDefs} title={title} ctx={ctx} onDone={notify} />,
    );
    await waitUntilExit();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
