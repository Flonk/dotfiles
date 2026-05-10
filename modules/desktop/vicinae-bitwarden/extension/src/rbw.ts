import { spawn, spawnSync } from "child_process";
import { writeFileSync, unlinkSync } from "fs";
import { join } from "path";

export interface VaultItem {
  id: string;
  name: string;
  user: string | null;
  folder: string | null;
  uris: string[] | null;
  type: string;
}

const PINENTRY_FILE = join(
  process.env.XDG_RUNTIME_DIR ?? `/run/user/${process.getuid!()}`,
  "rbw-pinentry",
);

function setPinentry(password: string) {
  writeFileSync(PINENTRY_FILE, password, { mode: 0o600 });
}

function clearPinentry() {
  try { unlinkSync(PINENTRY_FILE); } catch {}
}

function capture(cmd: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args);
    const stdout: string[] = [];
    const stderr: string[] = [];
    proc.stdout?.on("data", (d) => stdout.push(String(d)));
    proc.stderr?.on("data", (d) => stderr.push(String(d)));
    proc.on("close", (code) => {
      if (code === 0) resolve(stdout.join(""));
      else reject(new Error(stderr.join("").trim() || `${cmd} exited with code ${code}`));
    });
  });
}

async function rbw(masterPassword: string, args: string[]): Promise<string> {
  setPinentry(masterPassword);
  try {
    return await capture("rbw", args);
  } finally {
    clearPinentry();
  }
}

export function isLocked(): boolean {
  return spawnSync("rbw", ["unlocked"]).status !== 0;
}

export function listItems(): VaultItem[] {
  const out = spawnSync("rbw", ["list", "--raw"], { encoding: "utf-8" });
  return JSON.parse(out.stdout);
}

export async function unlock(masterPassword: string): Promise<VaultItem[]> {
  const out = await rbw(masterPassword, ["list", "--raw"]);
  return JSON.parse(out);
}

export async function getPassword(item: VaultItem, masterPassword: string): Promise<string> {
  const args = ["get", item.name];
  if (item.user) args.push(item.user);
  const password = await rbw(masterPassword, args);
  return password.trim();
}
