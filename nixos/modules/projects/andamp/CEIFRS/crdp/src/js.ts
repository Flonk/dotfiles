import { readFileSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { die, readSecret, state } from "./proc.js";
import { queued } from "./queue.js";
import { within } from "./transaction.js";
import { paste, readClipboard, xdotool } from "./x11.js";

type Result = { crdp: string; ok: true; value?: unknown } | { crdp: string; ok: false; error: string };

const lastUrl = join(state, "js-url");

function source(args: string[]): string {
  if (args.length === 0 || args[0] === "-") return readFileSync(0, "utf8");
  if (statSync(args[0], { throwIfNoEntry: false })?.isFile()) return readFileSync(args[0], "utf8");
  return args.join(" ");
}

function parse(args: string[]): { workspace?: string; transaction?: string; rest: string[] } {
  const flags: Record<string, string> = {};
  let i = 0;
  for (; i < args.length; i++) {
    const flag = /^--(workspace|transaction)(?:=(.*))?$/.exec(args[i]);
    if (!flag) break;
    flags[flag[1]] = flag[2] ?? args[++i] ?? die(`--${flag[1]} needs a value`);
  }
  return { workspace: flags.workspace, transaction: flags.transaction ?? process.env.CRDP_TRANSACTION, rest: args.slice(i) };
}

function workspaceUrl(workspace: string): string {
  const paths: Record<string, string> = JSON.parse(process.env.CRDP_WORKSPACES ?? "{}");
  if (!(workspace in paths)) die(`unknown workspace ${workspace}, expected one of ${Object.keys(paths).join(", ")}`);
  return new URL(readSecret(paths[workspace])).href;
}

function previousUrl(): string | null {
  try {
    return readFileSync(lastUrl, "utf8");
  } catch {
    return null;
  }
}

async function submit(code: string): Promise<void> {
  await paste(code);
  await sleep(300);
  xdotool("key", "Return");
}

async function evaluate(code: string, seconds: number): Promise<Result | null> {
  const id = `crdp-${process.pid}-${Math.floor(Math.random() * 32768)}`;
  await submit(`((__copy) => { (async () => { ${code}
})().then(v => __copy(JSON.stringify({crdp: '${id}', ok: true, value: v})), e => __copy(JSON.stringify({crdp: '${id}', ok: false, error: String(e && e.stack || e)}))); })(copy); '${id}'`);
  for (let i = 0; i < seconds * 2; i++) {
    const out = readClipboard(2000);
    if (out?.includes(`"crdp":"${id}"`)) return JSON.parse(out);
    await sleep(500);
  }
  return null;
}

async function open(workspace: string, url: string): Promise<void> {
  console.error(`crdp: js opening workspace ${workspace}`);
  await submit(`location.href = ${JSON.stringify(url)}`);
  const origin = new URL(url).origin;
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    await sleep(1000);
    const probe = await evaluate(`return document.readyState === "complete" && location.origin`, 5);
    if (probe?.ok && probe.value === origin) {
      writeFileSync(lastUrl, url);
      return;
    }
  }
  die(`workspace ${workspace} did not finish loading at ${origin}, is a login in the way?`);
}

export async function js(args: string[]): Promise<void> {
  const { workspace, transaction, rest } = parse(args);
  const url = workspace === undefined ? undefined : workspaceUrl(workspace);
  const code = source(rest);
  const task = async () => {
    if (workspace !== undefined && url !== undefined && previousUrl() !== url) await open(workspace, url);
    const result = (await evaluate(code, Number(process.env.CRDP_JS_TIMEOUT || 30))) ?? die("no result, is the DevTools console focused?");
    if (!result.ok) {
      console.error(result.error);
      process.exit(1);
    }
    console.log(JSON.stringify(result.value ?? null, null, 2));
  };
  if (transaction === undefined) return queued("js", task);
  within(transaction);
  await task();
}
