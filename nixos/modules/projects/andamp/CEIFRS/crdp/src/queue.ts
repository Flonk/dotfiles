import { existsSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { state } from "./proc.js";

const dir = join(state, "queue");
const lock = join(state, "queue.lock");
const staleMs = 10_000;
const signals = [
  ["SIGINT", 130],
  ["SIGTERM", 143],
  ["SIGHUP", 129],
] as const;

function stale(path: string): boolean {
  try {
    return Date.now() - statSync(path).mtimeMs > staleMs;
  } catch {
    return false;
  }
}

function waiting(): string[] {
  return readdirSync(dir)
    .filter((name) => {
      if (!stale(join(dir, name))) return true;
      rmSync(join(dir, name), { force: true });
      return false;
    })
    .sort();
}

export function queueLength(): number {
  try {
    return waiting().length;
  } catch {
    return 0;
  }
}

function acquire(ticket: string): boolean {
  if (stale(lock)) {
    console.error("crdp: queue lock went stale, taking over");
    rmSync(lock, { force: true });
  }
  try {
    writeFileSync(lock, ticket, { flag: "wx" });
    return true;
  } catch (e) {
    if ((e as NodeJS.ErrnoException).code === "EEXIST") return false;
    throw e;
  }
}

export function release(ticket: string): void {
  rmSync(join(dir, ticket), { force: true });
  try {
    if (readFileSync(lock, "utf8") === ticket) rmSync(lock, { force: true });
  } catch {}
}

let trapped = false;

export function holder(): string | null {
  try {
    return readFileSync(lock, "utf8");
  } catch {
    return null;
  }
}

export function heartbeat(): NodeJS.Timeout {
  return setInterval(() => {
    try {
      utimesSync(lock, new Date(), new Date());
    } catch {}
  }, 1000);
}

export async function claim(label: string, timeoutMs = Infinity): Promise<string | null> {
  mkdirSync(dir, { recursive: true });
  const ticket = `${String(Date.now()).padStart(15, "0")}-${process.pid}-${Math.floor(Math.random() * 32768)}`;
  const cleanup = () => release(ticket);
  process.on("exit", cleanup);
  if (!trapped) for (const [signal, code] of signals) process.once(signal, () => process.exit(code));
  trapped = true;

  const since = Date.now();
  let shown: number | undefined;
  for (;;) {
    writeFileSync(join(dir, ticket), "");
    const queue = waiting();
    if (queue[0] === ticket && acquire(ticket)) break;
    if (Date.now() - since > timeoutMs) {
      release(ticket);
      process.off("exit", cleanup);
      return null;
    }
    const ahead = queue.indexOf(ticket) + (existsSync(lock) ? 1 : 0);
    if (ahead !== shown) console.error(`crdp: ${label} waiting, ${ahead} ahead in queue`);
    shown = ahead;
    await sleep(250);
  }
  rmSync(join(dir, ticket), { force: true });
  process.off("exit", cleanup);
  if (shown !== undefined) console.error(`crdp: ${label} running after ${Math.round((Date.now() - since) / 1000)}s in queue`);
  return ticket;
}

export function forceRelease(): void {
  rmSync(lock, { force: true });
}
