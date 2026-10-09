import { setTimeout as sleep } from "node:timers/promises";
import { capture, feed, ok, run } from "./proc.js";

export const xdotool = (...args: string[]) => run("xdotool", ...args);

export const xUp = () => ok("xdotool", "getdisplaygeometry");

export const geometry = () => capture("xdotool", ["getdisplaygeometry"])?.trim().replaceAll(" ", "x") ?? null;

export const readClipboard = (timeout?: number) => capture("xclip", ["-selection", "clipboard", "-o"], timeout);

export async function paste(text: string): Promise<void> {
  feed("xclip", ["-selection", "clipboard", "-i"], text);
  await sleep(300);
  xdotool("key", "ctrl+v");
}

export function realInput(enabled: boolean): void {
  for (const device of ["Xephyr virtual mouse", "Xephyr virtual keyboard"]) ok("xinput", enabled ? "enable" : "disable", device);
}

export function lockedBorder(on: boolean): void {
  ok("hyprctl", "eval", `return hl.dispatch(hl.dsp.window.tag({ window = 'title:^auto-xephyr$', tag = '${on ? "+" : "-"}crdp-locked' }))`);
}
