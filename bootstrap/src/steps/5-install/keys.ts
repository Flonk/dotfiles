import { sshRun } from "../../lib/ssh.js";

/**
 * Read the host's age recipient by converting its SSH host key. The host private
 * key never leaves /etc/ssh; we only retrieve the public recipient.
 */
export async function getHostAgeRecipient(target: string): Promise<string> {
  // Ensure SSH host key exists (harmless if it does).
  await sshRun(target, "sudo ssh-keygen -A 2>/dev/null || true");

  const recipient = await sshRun(
    target,
    `nix-shell -p ssh-to-age --run 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null`,
  );

  if (!recipient) throw new Error("Failed to retrieve host age recipient from remote");
  return recipient;
}
