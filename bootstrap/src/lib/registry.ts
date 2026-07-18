import { readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { sshRun } from "./ssh.js";

interface RegistryEntry {
  user: string;
  hostname: string;
  ip: string;
  sshPublicKey: string;
}

export async function updateRegistry(
  repoRoot: string,
  installationName: string,
  target: string,
): Promise<void> {
  const registryPath = join(repoRoot, "nixos", ".registry.json");

  let registry: Record<string, RegistryEntry> = {};
  try {
    registry = JSON.parse(readFileSync(registryPath, "utf-8"));
  } catch {}

  const sshPublicKey = await sshRun(
    target,
    "cat /etc/ssh/ssh_host_ed25519_key.pub",
  );

  const hostname = await sshRun(target, "hostname");

  // Extract user and host from target (user@host -> user, host)
  const user = target.includes("@") ? target.split("@")[0] : "";
  const host = target.includes("@") ? target.split("@")[1] : target;
  // Resolve IP — could be an IP already or a hostname
  const ip = await sshRun(target, `dig +short ${host} | head -1`).catch(
    () => host,
  );

  registry[installationName] = {
    user: user || "",
    hostname: hostname || "",
    ip: ip || host,
    sshPublicKey: sshPublicKey || "",
  };

  writeFileSync(registryPath, JSON.stringify(registry, null, 2) + "\n");
}
