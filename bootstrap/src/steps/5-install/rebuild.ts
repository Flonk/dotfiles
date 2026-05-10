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
  // Run nixos-rebuild ON the remote, against the cloned repo. Pulling from the
  // binary cache over the remote's network is much faster than nix-copy-closure
  // from a local build.
  const cmd = `cd ${remotePath} && sudo nixos-rebuild switch --flake .#${host}`;
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

/**
 * Run nixos-rebuild on the remote against the repo at `remotePath`. SSH-based
 * execution lets the remote pull from the binary cache directly, instead of
 * nix-copy-closure pushing a multi-GB closure over the local uplink.
 *
 * sshd / networking restarts during activation are normal; sshd hiccups also
 * happen on the first switch from nixos-infect's stub config to the real one.
 * Both look the same to us — once the build's SSH session dies, the remote is
 * effectively wedged and needs a power cycle. We surface that, wait for sshd
 * to come back, and retry up to MAX_TRANSIENT_RETRIES (rebuild is idempotent).
 *
 * The watchdog probes sshCheck during the build; if it sees the remote stop
 * answering for ~30 s, it switches the status line to a hard "force-restart
 * now" message so the user doesn't sit watching a zombie.
 */
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
