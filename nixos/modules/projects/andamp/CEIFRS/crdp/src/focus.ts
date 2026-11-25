import { readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { state } from "./proc.js";

const file = join(state, "js-focus-unverified");

export const markUnverified = (reason: string) => writeFileSync(file, reason);

export const clearUnverified = () => rmSync(file, { force: true });

export function unverified(): string | null {
  try {
    return readFileSync(file, "utf8");
  } catch {
    return null;
  }
}
