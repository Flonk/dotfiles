import { readFileSync, statSync } from "node:fs";
import { setTimeout as sleep } from "node:timers/promises";
import { clearUnverified, markUnverified, unverified } from "./focus.js";
import { resolve } from "./links.js";
import { die } from "./proc.js";
import { paste, readClipboard, xdotool } from "./x11.js";

type Result = { crdp: string; ok: true; value?: unknown } | { crdp: string; ok: false; error: string };

function source(args: string[]): string {
  if (args.length === 0 || args[0] === "-") return readFileSync(0, "utf8");
  if (statSync(args[0], { throwIfNoEntry: false })?.isFile()) return readFileSync(args[0], "utf8");
  return args.join(" ");
}

function parse(args: string[]): { focused: boolean; rest: string[] } {
  const focused = args[0] === "--focused";
  return { focused, rest: focused ? args.slice(1) : args };
}

function guard(token: string, focused: boolean): void {
  const reason = unverified();
  if (reason === null) return;
  if (!focused)
    die(
      `refusing to paste: ${reason}, so focus may be off the DevTools console and the code could land in the page (Genie box, notebook cell). ` +
        `Run vpn3it crdp ${token} shot, make sure the Console prompt has the cursor (click into it if not), then rerun with --focused. ` +
        `Don't ask the user for the screen, your transaction is the permission`,
    );
  clearUnverified();
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

function noResult(token: string): never {
  markUnverified("the last js or open got no result");
  return die(
    "no result: either the code is still running past CRDP_JS_TIMEOUT, or it never reached a DevTools console because something else has focus " +
      "(another tab or window in front, the page itself, an address bar that turns the paste into a web search). " +
      `Fix it yourself, don't ask the user: vpn3it crdp ${token} shot, bring the tab with the open DevTools console to the front ` +
      "(close a search tab the paste opened), click its Console prompt, shot again, then rerun with --focused. " +
      "If the code has side effects, check whether it already ran before retrying.",
  );
}

export async function js(token: string, args: string[]): Promise<void> {
  const { focused, rest } = parse(args);
  const code = source(rest);
  guard(token, focused);
  const result = (await evaluate(code, Number(process.env.CRDP_JS_TIMEOUT || 30))) ?? noResult(token);
  if (!result.ok) {
    console.error(result.error);
    process.exit(1);
  }
  console.log(JSON.stringify(result.value ?? null, null, 2));
}

export async function open(token: string, args: string[]): Promise<void> {
  const { focused, rest } = parse(args);
  const url = resolve(rest[0] ?? die("open: missing NAME or URL, see vpn3it crdp links"));
  guard(token, focused);
  await submit(`location.href = ${JSON.stringify(url)}`);
  const origin = new URL(url).origin;
  const deadline = Date.now() + 60_000;
  while (Date.now() < deadline) {
    await sleep(1000);
    const probe = await evaluate(`return document.readyState === "complete" && location.origin`, 5);
    if (probe?.ok && probe.value === origin) {
      console.log(url);
      return;
    }
  }
  die(`${origin} did not finish loading within 60s, take a vpn3it crdp ${token} shot: is a login in the way?`);
}
