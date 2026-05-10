import { sshRun } from "../../lib/ssh.js";
import { remoteRepoPath } from "../../lib/types.js";

/**
 * Run home-manager activation on the remote, as the user, against the cloned
 * repo in the user's home. home-manager standalone has no --target-host, so we
 * SSH in and run it there. nix-shell -p home-manager handles the case where
 * home-manager isn't yet on the user's PATH.
 */
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
