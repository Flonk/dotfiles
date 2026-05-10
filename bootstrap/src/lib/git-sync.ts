import { $ } from "zx";
import { sshRun } from "./ssh.js";
import { remoteRepoPath } from "./types.js";

export async function gitCommitAndPush(
  repoRoot: string,
  installationName: string,
): Promise<void> {
  $.cwd = repoRoot;
  await $`git add -A`;
  const status = await $`git status --porcelain`;
  if (status.stdout.trim()) {
    await $`git commit -m ${"bootstrap: add keys for " + installationName}`;
  }
  await $`git push`;
}

export async function gitPullRemote(target: string, user: string): Promise<void> {
  await sshRun(target, `nix-shell -p git --run 'cd ${remoteRepoPath(user)} && git pull'`);
}
