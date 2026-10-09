import { execFileSync, spawn } from "node:child_process";
import { closeSync, mkdirSync, openSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

export const display = ":9";
export const hostDisplay = process.env.DISPLAY || ":0";
export const state = join(process.env.XDG_RUNTIME_DIR || "/tmp", "crdp");
mkdirSync(state, { recursive: true });

const env = { ...process.env, DISPLAY: display };

export function die(message: string): never {
  console.error(`crdp: ${message}`);
  process.exit(1);
}

export const readSecret = (path: string) => readFileSync(path, "utf8").replace(/\n+$/, "");

export function run(cmd: string, ...args: string[]): void {
  execFileSync(cmd, args, { env, stdio: "inherit" });
}

export function ok(cmd: string, ...args: string[]): boolean {
  try {
    execFileSync(cmd, args, { env, stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

export function capture(cmd: string, args: string[], timeout?: number): string | null {
  try {
    return execFileSync(cmd, args, {
      env,
      timeout,
      encoding: "utf8",
      maxBuffer: Infinity,
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return null;
  }
}

export function feed(cmd: string, args: string[], input: string): void {
  execFileSync(cmd, args, { env, input, stdio: ["pipe", "ignore", "ignore"] });
}

const pidFile = (name: string) => join(state, `${name}.pid`);

function pidOf(name: string): number | null {
  try {
    return Number(readFileSync(pidFile(name), "utf8")) || null;
  } catch {
    return null;
  }
}

export function alive(name: string): boolean {
  const pid = pidOf(name);
  if (pid === null) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

export function spawnDetached(name: string, cmd: string, args: string[], extraEnv: NodeJS.ProcessEnv = {}): void {
  const log = openSync(join(state, `${name}.log`), "w");
  const child = spawn(cmd, args, { env: { ...env, ...extraEnv }, detached: true, stdio: ["ignore", log, log] });
  closeSync(log);
  child.on("error", (e) => die(`${cmd}: ${e.message}`));
  child.unref();
  if (child.pid !== undefined) writeFileSync(pidFile(name), `${child.pid}\n`);
}

export function kill(name: string): void {
  const pid = pidOf(name);
  if (pid !== null && alive(name)) process.kill(pid);
  rmSync(pidFile(name), { force: true });
}

export async function waitFor(tries: number, check: () => boolean): Promise<boolean> {
  for (let i = 0; i < tries; i++) {
    if (check()) return true;
    await sleep(250);
  }
  return false;
}
