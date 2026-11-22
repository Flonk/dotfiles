import { sshRun } from "../../lib/ssh.js";

export async function getHostAgeRecipient(target: string): Promise<string> {
  await sshRun(target, "sudo ssh-keygen -A 2>/dev/null || true");

  const recipient = await sshRun(
    target,
    `nix-shell -p ssh-to-age --run 'ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null`,
  );

  if (!recipient) throw new Error("Failed to retrieve host age recipient from remote");
  return recipient;
}
