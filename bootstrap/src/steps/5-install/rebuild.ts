import { $ } from "zx";
import { sshCheck, waitForSsh } from "../../lib/ssh.js";

$.verbose = false;

const SSH_OPTS = [
  "-o", "StrictHostKeyChecking=no",
  "-o", "UserKnownHostsFile=/dev/null",
  "-o", "LogLevel=ERROR",
  "-o", "ServerAliveInterval=10",
  "-o", "ServerAliveCountMax=3",
  "-o", "ConnectTimeout=10",
];

const MAX_TRANSIENT_RETRIES = 2;
const TRANSIENT_PATTERNS = /broken pipe|connection reset|connection closed|closed by remote host/i;

type AttemptResult =
  | { kind: "success" }
  | { kind: "transient"; zombieDetected: boolean; reason: string }
  | { kind: "failure"; exitCode: number; stderr: string };

async function attempt(
  target: string,
  host: string,
  remotePath: string,
  onStatus?: (msg: string) => void,
): Promise<AttemptResult> {
  const cmd = `cd ${remotePath}/nixos && sudo nixos-rebuild switch --flake .#${host}`;
  const proc = $`ssh ${SSH_OPTS} ${target} ${cmd}`.nothrow();

  let zombieDetected = false;
  let consecutiveFailedProbes = 0;
  let probing = false;

  const watchdog = setInterval(async () => {
    if (probing || zombieDetected) return;
    probing = true;
    try {
      if (await sshCheck(target)) {
        consecutiveFailedProbes = 0;
      } else {
        consecutiveFailedProbes++;
        if (consecutiveFailedProbes >= 2) {
          zombieDetected = true;
          onStatus?.(
            "Remote is unresponsive — SSH stopped answering during rebuild. Force-restart the remote via your provider's console NOW; it will not recover on its own. The script will resume once sshd is back.",
          );
        }
      }
    } finally {
      probing = false;
    }
  }, 15_000);

  const result = await proc;
  clearInterval(watchdog);

  if (result.exitCode === 0 || result.exitCode === 4) return { kind: "success" };

  const stderr = String(result.stderr ?? "");
  if (
    result.exitCode === 255 ||
    TRANSIENT_PATTERNS.test(stderr) ||
    zombieDetected
  ) {
    const reason =
      zombieDetected
        ? "remote went unresponsive"
        : result.exitCode === 255
          ? "SSH session died (exit 255)"
          : "broken pipe / connection reset";
    return { kind: "transient", zombieDetected, reason };
  }

  return { kind: "failure", exitCode: result.exitCode ?? -1, stderr };
}

export async function rebuildSystem(
  target: string,
  host: string,
  remotePath: string,
  onStatus?: (msg: string) => void,
): Promise<void> {
  let transientRetries = 0;
  while (true) {
    const result = await attempt(target, host, remotePath, onStatus);

    if (result.kind === "success") {
      onStatus?.("");
      return;
    }

    if (result.kind === "transient") {
      if (!result.zombieDetected) {
        onStatus?.(
          `Rebuild interrupted (${result.reason}). The remote is wedged and will not recover on its own — force-restart it via your provider's console NOW. The script will retry once sshd is back.`,
        );
      }
      await waitForSsh(target);
      transientRetries++;
      if (transientRetries > MAX_TRANSIENT_RETRIES) {
        throw new Error(
          `nixos-rebuild kept losing SSH after ${MAX_TRANSIENT_RETRIES} retries — bailing.`,
        );
      }
      onStatus?.(`Retrying nixos-rebuild (attempt ${transientRetries + 1})…`);
      continue;
    }

    throw new Error(`nixos-rebuild failed with exit code ${result.exitCode}\n${result.stderr}`);
  }
}
