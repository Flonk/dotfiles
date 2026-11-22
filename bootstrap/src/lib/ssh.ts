import { $ } from "zx";

$.verbose = false;

const SSH_OPTS = [
  "-o", "StrictHostKeyChecking=no",
  "-o", "UserKnownHostsFile=/dev/null",
  "-o", "LogLevel=ERROR",
];

export async function sshRun(
  target: string,
  command: string,
): Promise<string> {
  const result =
    await $`ssh ${SSH_OPTS} -o ConnectTimeout=10 ${target} ${command}`;
  return result.stdout.trim();
}

export async function sshCheck(target: string): Promise<boolean> {
  try {
    await $`ssh ${SSH_OPTS} -o ConnectTimeout=5 ${target} echo ok`;
    return true;
  } catch {
    return false;
  }
}

export async function waitForSsh(
  target: string,
  attempts: number = 60,
  intervalMs: number = 5000,
): Promise<void> {
  for (let i = 0; i < attempts; i++) {
    if (await sshCheck(target)) return;
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error(`SSH never came back for ${target} after ${(attempts * intervalMs) / 1000}s`);
}
