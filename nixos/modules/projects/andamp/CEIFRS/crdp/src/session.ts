import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { markUnverified } from "./focus.js";
import { alive, die, display, headless, hostDisplay, kill, ok, readSecret, spawnDetached, state, waitFor } from "./proc.js";
import { queueLength } from "./queue.js";
import { current, forgetLastHolder, human, lastHolder } from "./transaction.js";
import { geometry, realInput, xUp } from "./x11.js";

const tiled = () => geometry() !== "640x480";
const connected = () => ok("xdotool", "search", "--name", "^FreeRDP");

const startKeepalive = () => alive("keepalive") || spawnDetached("keepalive", process.execPath, [process.argv[1], "keepalive"]);

const secret = (variable: string) => readSecret(process.env[variable] ?? die(`${variable} is not set`));

export async function start(size?: string): Promise<void> {
  if (alive("freerdp")) {
    startKeepalive();
    die("already running");
  }
  if (!xUp()) {
    if (headless) spawnDetached("xephyr", "Xvfb", [display, "-screen", "0", "1920x1080x24"]);
    else spawnDetached("xephyr", "auto-xephyr", [], { DISPLAY: hostDisplay });
    if (!(await waitFor(40, xUp))) die(`Xephyr did not come up, see ${join(state, "xephyr.log")}`);
    await waitFor(12, tiled);
  }
  realInput(current()?.id === human);
  forgetLastHolder();
  markUnverified("the session was (re)started");
  size ??= geometry() ?? die("could not read the display geometry");
  spawnDetached("freerdp", "xfreerdp", [
    `/v:${secret("CRDP_HOST_FILE")}:${secret("CRDP_PORT_FILE")}`,
    `/u:${secret("CRDP_USER_FILE")}`,
    `/p:${secret("CRDP_PASS_FILE")}`,
    "/cert-ignore",
    "/bpp:32",
    `/size:${size}`,
    "-gfx",
    "+rfx",
    "+clipboard",
  ]);
  if (!headless && !alive("clip")) {
    spawnDetached("clip", "wl-paste", ["--type", "text", "--watch", "xclip", "-selection", "clipboard", "-i"]);
  }
  if (!(await waitFor(120, connected))) die(`no session window, see ${join(state, "freerdp.log")}`);
  startKeepalive();
  console.log(`connected at ${size} on ${display}`);
}

export function stop(): void {
  const now = current();
  if (now !== null) die(`${now.id} holds the screen, stop refuses while a transaction is held. End yours first, or wait`);
  for (const name of ["keepalive", "clip", "freerdp", "xephyr"]) kill(name);
  ok("pkill", "-f", `(Xephyr|Xvfb) ${display} `);
}

export function status(): void {
  for (const name of ["xephyr", "freerdp", "clip", "keepalive"]) console.log(`${name}: ${alive(name) ? "up" : "down"}`);
  if (xUp()) console.log(`display: ${geometry()}`);
  const now = current();
  const waiting = queueLength();
  console.log(`screen: ${now === null ? "free" : `held by ${now.id}`}${waiting > 0 ? `, ${waiting} waiting` : ""}`);
  console.log(`last holder: ${lastHolder() ?? "none since start"}`);
}

export async function keepalive(): Promise<never> {
  for (;;) {
    await sleep(60_000);
    ok("xdotool", "mousemove_relative", "--", "1", "1");
    ok("xdotool", "mousemove_relative", "--", "-1", "-1");
  }
}
