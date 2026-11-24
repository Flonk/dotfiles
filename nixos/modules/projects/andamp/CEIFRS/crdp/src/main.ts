import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { js, markUnverified } from "./js.js";
import { die, display, run, state } from "./proc.js";
import { keepalive, start, status, stop } from "./session.js";
import { begin, end, grab, hold, transactionFlag, unlock, within } from "./transaction.js";
import { paste, xdotool } from "./x11.js";

const usage = `The screen is shared through transactions only: while one is held everything else waits, otherwise it is free.
Never ask the user whether you may use it. Holding a transaction, whatever is on screen is yours to rearrange:
bring the window and tab you need to the front and focus its DevTools console yourself.

vpn3it crdp start [WxH]     Xephyr on ${display} (workspace 9) + xfreerdp, sized to the tiled window
                              also starts a keepalive that nudges the mouse 1px and back every minute so the session never locks
vpn3it crdp stop | status
vpn3it crdp shot [file]       screenshot, prints the path
                              the commands below until edge drive the screen and need --transaction T (or CRDP_TRANSACTION=T) first
vpn3it crdp click X Y [btn] | dclick X Y | move X Y | scroll up|down [n]
vpn3it crdp type TEXT         type via the de keymap
vpn3it crdp key KEY...        e.g. ctrl+s super+r Return
vpn3it crdp paste TEXT        put TEXT on the session clipboard and ctrl+v it
vpn3it crdp clip              print the session clipboard
vpn3it crdp edge [url]        open url in InPrivate Edge via Win+R (new tab if an InPrivate window exists)
vpn3it crdp js [--workspace W] [--focused] CODE|FILE|-
                              run CODE as an async function body in the focused DevTools console, prints the returned value as JSON
                              after start, click, dclick, type, key, paste or edge it refuses to paste until rerun with --focused:
                              check vpn3it crdp shot first that the Console prompt has the cursor, otherwise the code lands in the page
                              W is ${Object.keys(JSON.parse(process.env.CRDP_WORKSPACES ?? "{}")).join(" | ")}, the tab is navigated there first unless it's already open
                              calls are queued globally and run one at a time, waiters report their position on stderr
                              --transaction T (or CRDP_TRANSACTION=T) runs inside transaction T, skipping the queue
vpn3it crdp transaction start take the screen exclusively: queues, then prints a token; js and other transactions wait
                              expires after CRDP_TRANSACTION_IDLE seconds (default 600) without a js call using it
vpn3it crdp transaction stop T release the screen
vpn3it crdp transaction grab  the user's bar button, toggles a hold for the human; agents never run it
vpn3it crdp transaction unlock force-release: drops every transaction and the queue lock, the next waiter goes`;

const [cmd, ...given] = process.argv.slice(2);
const screen = ["click", "dclick", "move", "scroll", "type", "key", "paste", "edge"];
const { token, rest: args } = screen.includes(cmd) ? transactionFlag(given) : { token: undefined, rest: given };
const arg = (i: number) => args[i] ?? die(`${cmd}: missing argument ${i + 1}, see vpn3it crdp without arguments`);

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

async function main(): Promise<void> {
  if (screen.includes(cmd)) within(token ?? die(`${cmd} needs --transaction T (or CRDP_TRANSACTION=T), see vpn3it crdp transaction start`));
  if (["start", "click", "dclick", "type", "key", "paste", "edge"].includes(cmd)) markUnverified([cmd, ...args].join(" ").slice(0, 80));
  switch (cmd) {
    case "start":
      return start(args[0]);
    case "stop":
      return stop();
    case "status":
      return status();
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
    case "keepalive":
      return keepalive();
    case "js":
      return js(args);
    case "transaction":
      if (args[0] === "start") return begin();
      if (args[0] === "stop") return end(arg(1));
      if (args[0] === "hold") return hold(arg(1));
      if (args[0] === "unlock") return unlock();
      if (args[0] === "grab") return grab();
      return die("usage: vpn3it crdp transaction start | stop TOKEN | grab | unlock");
    default:
      console.log(usage);
  }
}

main().catch((e) => {
  if (typeof e?.status === "number") process.exit(e.status);
  die(e instanceof Error ? e.message : String(e));
});
