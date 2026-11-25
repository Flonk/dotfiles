import { randomBytes } from "node:crypto";
import { readdirSync, readFileSync, rmSync, statSync, utimesSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { markUnverified } from "./focus.js";
import { die, kill, spawnDetached, state } from "./proc.js";
import { claim, forceRelease, heartbeat, holder, release } from "./queue.js";
import { lockedBorder, realInput } from "./x11.js";

export const human = "t3os";
export const tokenPattern = /^[0-9a-f]{8}$/;

type Transaction = { ticket: string; id: string; idle: number };

const defaultIdle = Number(process.env.CRDP_TRANSACTION_IDLE || 600);
const file = (token: string) => join(state, `transaction-${token}`);
const log = (token: string) => join(state, `transaction-${token}.holder.log`);
const lastHolderFile = join(state, "last-holder");
const grabbing = join(state, "grab.pid");

function read(token: string): Transaction | null {
  try {
    return JSON.parse(readFileSync(file(token), "utf8"));
  } catch {
    return null;
  }
}

function tokens(): string[] {
  return readdirSync(state).flatMap((name) => /^transaction-([0-9a-f]{8})$/.exec(name)?.[1] ?? []);
}

export function current(): { token: string; id: string } | null {
  const ticket = holder();
  for (const token of tokens()) {
    const t = read(token);
    if (t !== null && t.ticket === ticket) return { token, id: t.id };
  }
  return null;
}

export function lastHolder(): string | null {
  try {
    return readFileSync(lastHolderFile, "utf8");
  } catch {
    return null;
  }
}

export const forgetLastHolder = () => rmSync(lastHolderFile, { force: true });

function shortId(): string {
  const alphabet = "0123456789abcdefghijklmnopqrstuvwxyz";
  return Array.from(randomBytes(6), (b) => alphabet[b % alphabet.length]).join("");
}

function seconds(flag: string, value: string | undefined): number {
  const n = Number(value);
  if (value === undefined || !Number.isFinite(n) || n <= 0) die(`${flag} needs a positive number of seconds`);
  return n;
}

async function take(id: string, idle: number, timeout = Infinity): Promise<{ token: string; previous: string | null } | null> {
  const ticket = await claim(id === human ? "grab" : `begin for ${id}`, timeout * 1000);
  if (ticket === null) return null;
  const token = randomBytes(4).toString("hex");
  writeFileSync(file(token), JSON.stringify({ ticket, id, idle }));
  const previous = lastHolder();
  writeFileSync(lastHolderFile, id);
  spawnDetached(`transaction-${token}.holder`, process.execPath, [process.argv[1], "hold", token]);
  return { token, previous };
}

export async function begin(args: string[]): Promise<void> {
  let given: string | undefined;
  let timeout = Infinity;
  let idle = defaultIdle;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--timeout") timeout = seconds("--timeout", args[++i]);
    else if (args[i] === "--idle") idle = seconds("--idle", args[++i]);
    else if (given === undefined && !args[i].startsWith("-")) given = args[i];
    else die(`begin: unexpected argument ${args[i]}, see vpn3it crdp without arguments`);
  }
  if (given === human) die(`${human} is the user's bar button, pick another id`);
  if (given !== undefined && !/^[A-Za-z0-9_.-]{1,32}$/.test(given)) die("the id may only use letters, digits, . _ and -, up to 32 characters");
  const id = given ?? shortId();
  const taken = await take(id, idle, timeout);
  if (taken === null) {
    const now = current();
    console.error(`crdp: gave up after ${timeout}s in the queue${now ? `, ${now.id} holds the screen` : ""}`);
    process.exit(75);
  }
  const { token, previous } = taken;
  const T = `vpn3it crdp ${token}`;
  const lines = [`crdp: transaction ${token} for ${id} holds the screen, it ends after ${idle}s without a command.`];
  if (given === undefined) lines.push(`crdp: your id is ${id}. Pass it to your next begin (vpn3it crdp begin ${id}) to skip the checks while nobody else held the screen in between.`);
  if (previous === id) {
    lines.push("crdp: you held the screen last and nobody has touched it since, carry on where you left off.");
  } else {
    const who = previous === null ? "the session was (re)started" : `${previous === human ? "the user" : previous} held the screen`;
    markUnverified(`${who} since your last transaction`);
    lines.push(
      `crdp: ${who} since your last transaction, so the screen may look different now. Check it first: run ${T} shot and look at it. ` +
        `Whatever is in front (another tab, window or dialog) is yours to move. For js or open, bring the Edge tab you need to the front, ` +
        `open its DevTools (F12) if they are closed, click into the Console prompt, shot again to see the cursor there, then pass --focused once.`,
    );
  }
  lines.push(`crdp: never ask the user whether you may use the screen, the transaction is the permission. Release it with ${T} end before waiting on anything.`);
  console.error(lines.join("\n"));
  console.log(token);
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

export async function grab(): Promise<void> {
  const mine = tokens().filter((token) => read(token)?.id === human);
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
  await take(human, Infinity);
  console.error("crdp: the screen is yours until you grab again, agents wait meanwhile");
}

export async function hold(token: string): Promise<void> {
  const t = read(token) ?? die(`no transaction ${token}`);
  const isHuman = t.id === human;
  process.on("exit", () => {
    realInput(false);
    lockedBorder(false);
  });
  for (const signal of ["SIGINT", "SIGTERM", "SIGHUP"] as const) process.once(signal, () => process.exit(0));
  realInput(isHuman);
  lockedBorder(!isHuman);
  const beat = heartbeat();
  for (;;) {
    await sleep(1000);
    const used = statSync(file(token), { throwIfNoEntry: false })?.mtimeMs;
    if (used === undefined || holder() !== t.ticket) break;
    if (!isHuman && Date.now() - used > t.idle * 1000) {
      console.error(`crdp: transaction ${token} expired`);
      break;
    }
  }
  clearInterval(beat);
  rmSync(file(token), { force: true });
  rmSync(log(token), { force: true });
  release(t.ticket);
}

export function end(token: string): void {
  const t = read(token) ?? die(`no transaction ${token}, it may have expired`);
  rmSync(file(token), { force: true });
  release(t.ticket);
  kill(`transaction-${token}.holder`);
  rmSync(log(token), { force: true });
}

export function within(token: string): void {
  const t = read(token);
  if (t === null || holder() !== t.ticket) die(`transaction ${token} is not held, it ended or expired. Start a new one with vpn3it crdp begin [ID]`);
  utimesSync(file(token), new Date(), new Date());
}

export function unlock(): void {
  for (const token of tokens()) {
    rmSync(file(token), { force: true });
    kill(`transaction-${token}.holder`);
    rmSync(log(token), { force: true });
    console.error(`crdp: dropped transaction ${token}`);
  }
  forceRelease();
  realInput(false);
  lockedBorder(false);
  console.error("crdp: screen unlocked");
}
