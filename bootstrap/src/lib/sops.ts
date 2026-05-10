import { $ } from "zx";

$.verbose = false;

/**
 * Re-encrypt every sops-managed secret in the repo so freshly-added recipients
 * in .sops.yaml can decrypt them. Mirrors bootstrap/update-all-secrets.sh.
 */
export async function updateSopsKeys(repoRoot: string): Promise<void> {
  const result = await $`find ${repoRoot} -type f -path '*/secrets/*'`;
  const files = result.stdout
    .trim()
    .split("\n")
    .filter((f) => /\.(yaml|json|env|ini|ovpn|crt)$/.test(f))
    .sort();

  for (const file of files) {
    await $`sops updatekeys -y ${file}`;
  }
}
