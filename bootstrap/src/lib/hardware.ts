import { mkdirSync, writeFileSync } from "fs";
import { join } from "path";
import { sshRun } from "./ssh.js";

export async function fetchHardwareConfig(
  repoRoot: string,
  host: string,
  target: string,
): Promise<void> {
  // Prefer the existing file (nixos-infect writes boot loader config there).
  // Fall back to regenerating if it doesn't exist.
  const exists = await sshRun(target, "test -f /etc/nixos/hardware-configuration.nix && echo yes || echo no");
  let config: string;
  if (exists === "yes") {
    config = await sshRun(target, "cat /etc/nixos/hardware-configuration.nix");
  } else {
    config = await sshRun(target, "sudo nixos-generate-config --show-hardware-config");
  }

  if (!config) throw new Error("Failed to fetch hardware config from remote");

  const hostDir = join(repoRoot, "config", "hosts", host);
  mkdirSync(hostDir, { recursive: true });
  writeFileSync(join(hostDir, `${host}-hardware.nix`), config + "\n");
}
