import { sshRun } from "./ssh.js";
import { GIT_CLONE_URL } from "./types.js";

/**
 * Clone (or pull) the dotfiles repo at `path` on the remote. The caller picks
 * which target to SSH as — root for /root/dotfiles, the user for their own
 * home — so file ownership is correct from the start, no chown needed.
 */
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
