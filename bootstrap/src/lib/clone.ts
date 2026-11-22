import { sshRun } from "./ssh.js";
import { GIT_CLONE_URL } from "./types.js";

export async function cloneRepo(target: string, path: string): Promise<void> {
  const exists = await sshRun(
    target,
    `test -d ${path}/.git && echo yes || echo no`,
  );

  if (exists === "yes") {
    await sshRun(target, `nix-shell -p git --run 'cd ${path} && git pull'`);
    return;
  }

  await sshRun(
    target,
    `nix-shell -p git --run 'mkdir -p $(dirname ${path}) && git clone ${GIT_CLONE_URL} ${path}'`,
  );
}
