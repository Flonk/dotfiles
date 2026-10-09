import { join } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";
import { js } from "./js.js";
import { die, display, run, state } from "./proc.js";
import { keepalive, start, status, stop } from "./session.js";
import { begin, end, hold, transactionFlag, unlock, within } from "./transaction.js";
import { paste, xdotool } from "./x11.js";

const usage = `crdp start [WxH]       Xephyr on ${display} (workspace 9) + xfreerdp, sized to the tiled window
                       also starts a keepalive that nudges the mouse 1px and back every minute so the session never locks
crdp stop | status
crdp shot [file]       screenshot, prints the path
                       the commands below until edge drive the screen and need --transaction T (or CRDP_TRANSACTION=T) first
crdp click X Y [btn] | dclick X Y | move X Y | scroll up|down [n]
crdp type TEXT         type via the de keymap
crdp key KEY...        e.g. ctrl+s super+r Return
crdp paste TEXT        put TEXT on the session clipboard and ctrl+v it
crdp clip              print the session clipboard
crdp edge [url]        open url in InPrivate Edge via Win+R (new tab if an InPrivate window exists)
crdp js [--workspace W] CODE|FILE|-
                       run CODE as an async function body in the focused DevTools console, prints the returned value as JSON
                       W is ${Object.keys(JSON.parse(process.env.CRDP_WORKSPACES ?? "{}")).join(" | ")}, the tab is navigated there first unless it's already open
                       calls are queued globally and run one at a time, waiters report their position on stderr
                       --transaction T (or CRDP_TRANSACTION=T) runs inside transaction T, skipping the queue
crdp transaction start take the screen exclusively: queues, then prints a token; js and other transactions wait
                       expires after CRDP_TRANSACTION_IDLE seconds (default 600) without a js call using it
crdp transaction stop T release the screen
crdp transaction unlock force-release: drops every transaction and the queue lock, the next waiter goes`;

const [cmd, ...given] = process.argv.slice(2);
const screen = ["click", "dclick", "move", "scroll", "type", "key", "paste", "edge"];
const { token, rest: args } = screen.includes(cmd) ? transactionFlag(given) : { token: undefined, rest: given };
const arg = (i: number) => args[i] ?? die(`${cmd}: missing argument ${i + 1}, see crdp without arguments`);

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
  if (screen.includes(cmd)) within(token ?? die(`${cmd} needs --transaction T (or CRDP_TRANSACTION=T), see crdp transaction start`));
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
      return die("usage: crdp transaction start | stop TOKEN | unlock");
    default:
      console.log(usage);
  }
}

main().catch((e) => {
  if (typeof e?.status === "number") process.exit(e.status);
  die(e instanceof Error ? e.message : String(e));
});
