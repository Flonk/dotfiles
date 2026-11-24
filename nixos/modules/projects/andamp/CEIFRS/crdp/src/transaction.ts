import { randomBytes } from "node:crypto";
import { existsSync, readdirSync, readFileSync, rmSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { die, kill, spawnDetached, state } from "./proc.js";
import { claim, forceRelease, heartbeat, holder, release } from "./queue.js";
import { lockedBorder, realInput } from "./x11.js";

const idleMs = Number(process.env.CRDP_TRANSACTION_IDLE || 600) * 1000;
const file = (token: string) => join(state, `transaction-${token}`);
const log = (token: string) => join(state, `transaction-${token}.holder.log`);
const user = (token: string) => join(state, `transaction-${token}.user`);
const grabbing = join(state, "grab.pid");

function userTokens(): string[] {
  return readdirSync(state).flatMap((name) => /^transaction-([0-9a-f]+)\.user$/.exec(name)?.[1] ?? []);
}

function pendingGrab(): number | null {
  try {
    const pid = Number(readFileSync(grabbing, "utf8"));
    process.kill(pid, 0);
    return pid;
  } catch {
    return null;
  }
}

function ticketOf(token: string): string | null {
  try {
    return readFileSync(file(token), "utf8");
  } catch {
    return null;
  }
}

export async function begin(): Promise<void> {
  const ticket = await claim("transaction");
  const token = randomBytes(4).toString("hex");
  writeFileSync(file(token), ticket);
  spawnDetached(`transaction-${token}.holder`, process.execPath, [process.argv[1], "transaction", "hold", token]);
  console.error(
    `crdp: transaction ${token} holds the screen, expires after ${idleMs / 1000}s without use\n` +
      `crdp: the screen is yours now. Whatever is in front (another tab, window or dialog) is yours to move: bring the window and tab you need ` +
      `to the front, click into its DevTools Console prompt, check with vpn3it crdp shot, then run js with --transaction ${token} --focused. ` +
      `Do not ask the user whether you may use the screen, the transaction is the permission. ` +
      `Release it with vpn3it crdp transaction stop ${token} before waiting on anything.`,
  );
  console.log(token);
}

export async function grab(): Promise<void> {
  const mine = userTokens();
  if (mine.length > 0) {
    for (const token of mine) end(token);
    console.error("crdp: released your hold on the screen");
    return;
  }
  const pending = pendingGrab();
  if (pending !== null) {
    process.kill(pending);
    rmSync(grabbing, { force: true });
    console.error("crdp: cancelled your waiting grab");
    return;
  }
  writeFileSync(grabbing, String(process.pid));
  process.on("exit", () => rmSync(grabbing, { force: true }));
  const ticket = await claim("grab");
  const token = randomBytes(4).toString("hex");
  writeFileSync(file(token), ticket);
  writeFileSync(user(token), "");
  spawnDetached(`transaction-${token}.holder`, process.execPath, [process.argv[1], "transaction", "hold", token]);
  console.error(`crdp: the screen is yours until you grab again, agents wait meanwhile`);
}

export async function hold(token: string): Promise<void> {
  const ticket = ticketOf(token) ?? die(`no transaction ${token}`);
  const human = existsSync(user(token));
  process.on("exit", () => {
    realInput(true);
    lockedBorder(false);
  });
  for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"] as const) process.once(signal, () => process.exit(0));
  realInput(human);
  lockedBorder(!human);
  const beat = heartbeat();
  for (;;) {
    await sleep(1000);
    const used = statSync(file(token), { throwIfNoEntry: false })?.mtimeMs;
    if (used === undefined || holder() !== ticket) break;
    if (!human && Date.now() - used > idleMs) {
      console.error(`crdp: transaction ${token} expired`);
      break;
    }
  }
  clearInterval(beat);
  rmSync(file(token), { force: true });
  rmSync(user(token), { force: true });
  rmSync(log(token), { force: true });
  release(ticket);
}

export function end(token: string): void {
  const ticket = ticketOf(token) ?? die(`no transaction ${token}, it may have expired`);
  rmSync(file(token), { force: true });
  rmSync(user(token), { force: true });
  release(ticket);
  kill(`transaction-${token}.holder`);
  rmSync(log(token), { force: true });
}

export function within(token: string): void {
  const ticket = ticketOf(token);
  if (ticket === null || holder() !== ticket) die(`transaction ${token} is not held, it was stopped or expired`);
  utimesSync(file(token), new Date(), new Date());
}

export function unlock(): void {
  for (const name of readdirSync(state)) {
    const token = /^transaction-([0-9a-f]+)$/.exec(name)?.[1];
    if (token === undefined) continue;
    rmSync(file(token), { force: true });
    rmSync(user(token), { force: true });
    kill(`transaction-${token}.holder`);
    rmSync(log(token), { force: true });
    console.error(`crdp: dropped transaction ${token}`);
  }
  forceRelease();
  realInput(true);
  lockedBorder(false);
  console.error("crdp: screen unlocked");
}

export function transactionFlag(args: string[]): { token?: string; rest: string[] } {
  const flag = /^--transaction(?:=(.*))?$/.exec(args[0] ?? "");
  if (!flag) return { token: process.env.CRDP_TRANSACTION, rest: args };
  if (flag[1] !== undefined) return { token: flag[1], rest: args.slice(1) };
  return { token: args[1] ?? die("--transaction needs a value"), rest: args.slice(2) };
}
