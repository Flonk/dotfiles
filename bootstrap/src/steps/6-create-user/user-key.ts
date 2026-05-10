import { sshRun } from "../../lib/ssh.js";

/**
 * Generate the user age key on the remote machine, in the user's own home.
 * Run AFTER nixos-rebuild creates the user — SSH must be as the user, not root.
 * Returns the public recipient; the private key stays at ~/.config/sops/age/keys.txt.
 */
export async function generateUserAgeKey(userTarget: string): Promise<string> {
  await sshRun(
    userTarget,
    `mkdir -p "$HOME/.config/sops/age" && chmod 700 "$HOME/.config/sops/age" && (test -f "$HOME/.config/sops/age/keys.txt" || nix-shell -p age --run 'age-keygen -o "$HOME/.config/sops/age/keys.txt" 2>/dev/null') && chmod 600 "$HOME/.config/sops/age/keys.txt"`,
  );

  const recipient = await sshRun(
    userTarget,
    `nix-shell -p age --run 'age-keygen -y "$HOME/.config/sops/age/keys.txt"' 2>/dev/null`,
  );

  if (!recipient) throw new Error("Failed to retrieve user age recipient from remote");
  return recipient;
}
