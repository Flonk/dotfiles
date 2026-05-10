import { sshRun } from "../../lib/ssh.js";

export async function isNixOS(target: string): Promise<boolean> {
  const result = await sshRun(target, "test -f /etc/NIXOS && echo yes || echo no");
  return result === "yes";
}

export async function runNixosInfect(target: string): Promise<void> {
  try {
    await sshRun(
      target,
      "curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | PROVIDER=hetznercloud NIX_CHANNEL=nixos-24.11 bash -x",
    );
  } catch (e: any) {
    // Exit code 255 = SSH connection closed by remote reboot — expected
    const code = e?.exitCode ?? e?.code;
    if (code === 255 || String(e).includes("closed by remote host")) {
      return;
    }
    throw e;
  }
}
