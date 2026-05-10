import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";

export function getInstallations(repoRoot: string): string[] {
  const dir = join(repoRoot, "config", "installations");
  return readdirSync(dir)
    .filter((f) => f.endsWith(".nix"))
    .map((f) => f.replace(/\.nix$/, ""))
    .sort();
}

export function getUsers(repoRoot: string): string[] {
  const dir = join(repoRoot, "config", "users");
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== "_template")
    .map((d) => d.name)
    .sort();
}

export function getHosts(repoRoot: string): string[] {
  const dir = join(repoRoot, "config", "hosts");
  return readdirSync(dir, { withFileTypes: true })
    .filter((d) => d.isDirectory() && d.name !== "_template")
    .map((d) => d.name)
    .sort();
}

/**
 * Parse an installation nix file to extract the host and user it references.
 */
export function parseInstallation(
  repoRoot: string,
  installationName: string,
): { user: string; host: string } {
  const nixPath = join(repoRoot, "config", "installations", `${installationName}.nix`);
  const content = readFileSync(nixPath, "utf-8");

  const hostMatch = content.match(/\.\.\/hosts\/([^/]+)\//);
  const userMatch = content.match(/\.\.\/users\/([^/\s]+)/);

  if (!hostMatch) throw new Error(`Could not determine host from ${nixPath}`);
  if (!userMatch) throw new Error(`Could not determine user from ${nixPath}`);

  return { host: hostMatch[1], user: userMatch[1] };
}

/**
 * Clone the _template host directory, replacing __HOST__ and __USER__ placeholders.
 * Also adds the host to nixosConfigurations in flake.nix.
 */
export function createHostFromTemplate(
  repoRoot: string,
  host: string,
  user: string,
  arch: string,
  stateVersion: string,
  sshKeys: string[] = [],
): void {
  const templateDir = join(repoRoot, "config", "hosts", "_template");
  const hostDir = join(repoRoot, "config", "hosts", host);
  mkdirSync(hostDir, { recursive: true });

  const sshKeysNix = sshKeys.length > 0
    ? sshKeys.map(k => `        "${k}"`).join("\n")
    : "";

  for (const file of readdirSync(templateDir)) {
    const content = readFileSync(join(templateDir, file), "utf-8")
      .replace(/__HOST__/g, host)
      .replace(/__USER__/g, user)
      .replace(/__ARCH__/g, arch)
      .replace(/__STATEVERSION__/g, stateVersion)
      .replace(/__SSH_KEYS__/g, sshKeysNix);
    const destName = file.replace(/_template/g, host);
    writeFileSync(join(hostDir, destName), content);
  }

  addHostToFlake(repoRoot, host);
}

/**
 * Add a nixosConfigurations entry for a new host in flake.nix.
 */
function addHostToFlake(repoRoot: string, host: string): void {
  const flakePath = join(repoRoot, "flake.nix");
  const lines = readFileSync(flakePath, "utf-8").split("\n");

  if (lines.some((l) => l.includes(`${host} = mkSystem`))) return;

  // Find nixosConfigurations block and its closing };
  let inBlock = false;
  let insertIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes("nixosConfigurations = {")) {
      inBlock = true;
    }
    if (inBlock && lines[i].match(/^\s{6}\};/)) {
      insertIdx = i;
      break;
    }
  }

  if (insertIdx === -1) {
    throw new Error("Could not find nixosConfigurations closing brace in flake.nix");
  }

  lines.splice(insertIdx, 0, `        ${host} = mkSystem "${host}" { };`);
  writeFileSync(flakePath, lines.join("\n"));
}

/**
 * Clone the _template user directory, replacing __USER__ placeholders.
 */
export function createUserFromTemplate(repoRoot: string, user: string): void {
  const templateDir = join(repoRoot, "config", "users", "_template");
  const userDir = join(repoRoot, "config", "users", user);
  mkdirSync(userDir, { recursive: true });

  for (const file of readdirSync(templateDir)) {
    const content = readFileSync(join(templateDir, file), "utf-8")
      .replace(/__USER__/g, user);
    const destName = file.replace(/_template/g, user);
    writeFileSync(join(userDir, destName), content);
  }
}

/**
 * Generate the installation nix file. Name is always user-host.
 */
export function createInstallation(repoRoot: string, user: string, host: string): string {
  const name = `${user}-${host}`;
  const content = `{ ... }:
{
  imports = [
    ../../types
    ../hosts/${host}/${host}-hostconfig.nix
    ../users/${user}
  ];

  skynet.whoami.installation = "${name}";

}
`;
  writeFileSync(join(repoRoot, "config", "installations", `${name}.nix`), content);
  return name;
}
