import { sshRun } from "../../lib/ssh.js";
import { remoteRepoPath } from "../../lib/types.js";

export async function rebuildHomeManager(
  userTarget: string,
  installationName: string,
  user: string,
): Promise<void> {
  const repoPath = remoteRepoPath(user);
  await sshRun(
    userTarget,
    `nix-shell -p home-manager --run 'home-manager switch --flake ${repoPath}#${installationName}'`,
  );
}
