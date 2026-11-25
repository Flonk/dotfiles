import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { markUnverified } from "./focus.js";
import { js, open } from "./js.js";
import { links } from "./links.js";
import { die, display, run, state } from "./proc.js";
import { keepalive, start, status, stop } from "./session.js";
import { begin, end, grab, hold, tokenPattern, unlock, within } from "./transaction.js";
import { paste, xdotool } from "./x11.js";

const usage = `Everything on the screen goes through a transaction. One holds the screen at a time, the others wait in the queue.
Between transactions the window takes no input at all. Never ask the user whether you may use the screen:
holding a transaction is the permission, and whatever is on screen is yours to rearrange.

vpn3it crdp start [WxH]       Xephyr on ${display} (workspace 9) + xfreerdp, sized to the tiled window,
                              plus a keepalive that nudges the mouse every minute so the session never locks
vpn3it crdp stop | status     stop refuses while a transaction is held
vpn3it crdp links             the known web apps as NAME URL, open takes either

vpn3it crdp begin [ID] [--timeout S] [--idle S]
                              wait for the screen, then print a transaction token T
                              ID names you (letters, digits, . _ -); without one you get a short random id on stderr, keep it
                              if you held the screen last, carry on; if someone else did, begin tells you what to check first
                              --timeout gives up after S seconds in the queue (exit 75)
                              --idle ends T after S seconds without a command (default CRDP_TRANSACTION_IDLE, ${process.env.CRDP_TRANSACTION_IDLE || 180}s here)
vpn3it crdp T end             release the screen, always before waiting on anything

vpn3it crdp T shot [file]     screenshot, prints the path
vpn3it crdp T click X Y [btn] | dclick X Y | move X Y | scroll up|down [n]
vpn3it crdp T type TEXT       type via the de keymap (garbles : / - y z, use paste for anything else)
vpn3it crdp T key KEY...      e.g. ctrl+s super+r Return
vpn3it crdp T paste TEXT      put TEXT on the session clipboard and ctrl+v it
vpn3it crdp T clip            print the session clipboard
vpn3it crdp T edge [url]      open url in InPrivate Edge via Win+R
vpn3it crdp T js [--focused] CODE|FILE|-
                              run CODE as an async function body in the focused DevTools console, prints the returned value as JSON
vpn3it crdp T open [--focused] NAME|URL
                              navigate the tab of the focused DevTools console to a link or URL and wait until it has loaded
                              js and open refuse to paste until rerun with --focused whenever focus may have moved:
                              after a begin that followed someone else, after click, dclick, type, key, paste or edge,
                              and after a js or open without result. Check with T shot that the Console prompt has the cursor first

vpn3it crdp grab              the user's bar button: toggles a hold for t3os, the only holder whose mouse and keyboard reach the window
                              agents never run it
vpn3it crdp unlock            force-release: drops every transaction and the queue lock, only when the user asks`;

const focusMoving = ["click", "dclick", "type", "key", "paste", "edge"];
const screen = ["shot", "click", "dclick", "move", "scroll", "type", "key", "paste", "clip", "edge", "js", "open", "end"];

function shot(out = join(state, "shot.png")): void {
  run("import", "-window", "root", out);
  console.log(out);
}

async function edge(url = ""): Promise<void> {
  xdotool("key", "super+r");
  await sleep(1000);
  xdotool("type", "--delay", "30", "--", `msedge --inprivate ${url}`);
  xdotool("key", "Return");
}

async function inside(token: string, cmd: string | undefined, args: string[]): Promise<void> {
  const arg = (i: number) => args[i] ?? die(`${cmd}: missing argument ${i + 1}, see vpn3it crdp without arguments`);
  if (cmd === undefined || !screen.includes(cmd)) die(`unknown command ${cmd ?? "(none)"} for transaction ${token}, see vpn3it crdp without arguments`);
  within(token);
  if (focusMoving.includes(cmd)) markUnverified(`"vpn3it crdp T ${[cmd, ...args].join(" ").slice(0, 80)}" ran since the last js`);
  switch (cmd) {
    case "end":
      return end(token);
    case "shot":
      return shot(args[0]);
    case "click":
      return xdotool("mousemove", arg(0), arg(1), "click", args[2] ?? "1");
    case "dclick":
      return xdotool("mousemove", arg(0), arg(1), "click", "--repeat", "2", "--delay", "80", "1");
    case "move":
      return xdotool("mousemove", arg(0), arg(1));
    case "scroll":
      return xdotool("click", "--repeat", args[1] ?? "3", "--delay", "50", args[0] === "up" ? "4" : "5");
    case "type":
      return xdotool("type", "--delay", "30", "--", args.join(" "));
    case "key":
      return xdotool("key", "--delay", "60", "--", ...args);
    case "paste":
      return paste(args.join(" "));
    case "clip":
      return run("xclip", "-selection", "clipboard", "-o");
    case "edge":
      return edge(args[0]);
    case "js":
      return js(token, args);
    case "open":
      return open(token, args);
  }
}

async function main(): Promise<void> {
  const [first, ...rest] = process.argv.slice(2);
  if (first !== undefined && tokenPattern.test(first)) return inside(first, rest[0], rest.slice(1));
  switch (first) {
    case "start":
      return start(rest[0]);
    case "stop":
      return stop();
    case "status":
      return status();
    case "links":
      return links();
    case "begin":
      return begin(rest);
    case "grab":
      return grab();
    case "unlock":
      return unlock();
    case "keepalive":
      return keepalive();
    case "hold":
      return hold(rest[0] ?? die("hold: missing token"));
  }
  if (first !== undefined && screen.includes(first))
    die(`${first} runs inside a transaction: T=$(vpn3it crdp begin [ID]), then vpn3it crdp $T ${first} ..., and vpn3it crdp $T end`);
  console.log(usage);
}

main().catch((e) => {
  if (typeof e?.status === "number") process.exit(e.status);
  die(e instanceof Error ? e.message : String(e));
});
