import { useEffect, useRef, useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { useBootstrap } from "../../context.js";
import { cloneRepo } from "../../lib/clone.js";
import { generateUserAgeKey } from "./user-key.js";
import { rebuildHomeManager } from "./home-manager.js";
import { updateSopsYamlEntries } from "../5-install/sops-update.js";
import { gitCommitAndPush, gitPullRemote } from "../../lib/git-sync.js";
import { waitForSsh } from "../../lib/ssh.js";
import { remoteRepoPath } from "../../lib/types.js";
import { updateSopsKeys } from "../../lib/sops.js";

type Sub =
  | "wait_user_ssh"
  | "cloning"
  | "generating_key"
  | "sops_updated"
  | "confirm_conflict"
  | "wait_done"
  | "pushing_and_activating";

function userSshTarget(target: string, user: string): string {
  const host = target.includes("@") ? target.split("@")[1] : target;
  return `${user}@${host}`;
}

export function Step6() {
  const ctx = useBootstrap();
  const [sub, setSub] = useState<Sub>("wait_user_ssh");
  const [inputValue, setInputValue] = useState("");
  const started = useRef(false);

  const userTarget = userSshTarget(ctx.target, ctx.selectedUser);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    (async () => {
      try {
        // Wait until SSH-as-user works — activation may still be wrapping up.
        await waitForSsh(userTarget);

        setSub("cloning");
        await cloneRepo(userTarget, remoteRepoPath(ctx.selectedUser));

        setSub("generating_key");
        const userRecipient = await generateUserAgeKey(userTarget);
        ctx.setUserAgeRecipient(userRecipient);

        const result = updateSopsYamlEntries(ctx.repoRoot, [
          { anchor: `user_${ctx.installationName}`, ageKey: userRecipient },
        ]);
        setSub(result.status === "conflict" ? "confirm_conflict" : "wait_done");
      } catch (e) {
        ctx.fail(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  const finishAndActivate = async () => {
    setSub("pushing_and_activating");
    try {
      await updateSopsKeys(ctx.repoRoot);
      await gitCommitAndPush(ctx.repoRoot, ctx.installationName);
      await gitPullRemote(userTarget, ctx.selectedUser);
      await rebuildHomeManager(userTarget, ctx.installationName, ctx.selectedUser);
      ctx.advanceStep();
      ctx.setPhase("done");
    } catch (e) {
      ctx.fail(e instanceof Error ? e.message : String(e));
    }
  };

  if (sub === "wait_user_ssh") {
    return (
      <Box>
        <Text>Waiting for SSH as {ctx.selectedUser}@{ctx.target}…</Text>
      </Box>
    );
  }

  if (sub === "cloning") {
    return (
      <Box>
        <Text>Cloning Skynet into {ctx.selectedUser}'s home…</Text>
      </Box>
    );
  }

  if (sub === "generating_key") {
    return (
      <Box>
        <Text>Generating user age key on remote…</Text>
      </Box>
    );
  }

  if (sub === "confirm_conflict") {
    return (
      <Box flexDirection="column" marginY={1}>
        <Text bold color="yellow">
          user_{ctx.installationName} already exists in .sops.yaml with a different value.
        </Text>
        <Box marginTop={1}>
          <Text bold>Continue with existing key? (type "yes" or "no"): </Text>
          <TextInput
            value={inputValue}
            onChange={setInputValue}
            onSubmit={(value) => {
              const v = value.toLowerCase().trim();
              if (v === "yes") {
                setInputValue("");
                setSub("wait_done");
              } else if (v === "no") {
                ctx.fail("Aborted — user key conflict in .sops.yaml");
              }
            }}
          />
        </Box>
      </Box>
    );
  }

  if (sub === "pushing_and_activating") {
    return (
      <Box>
        <Text>Re-encrypting secrets, pushing, pulling on remote, and running home-manager switch…</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column">
      <Box flexDirection="column" marginY={1}>
        <Text bold>Discovered user age recipient:</Text>
        <Text>
          <Text bold>user_{ctx.installationName}</Text>: {ctx.userAgeRecipient}
        </Text>
      </Box>
      <Box flexDirection="column" marginY={1}>
        <Text bold>user_{ctx.installationName} added to .sops.yaml `keys:` section.</Text>
        <Text>
          Now add *user_{ctx.installationName} to the relevant entries under
          creation_rules in .sops.yaml.
        </Text>
        <Box marginTop={1}>
          <Text bold>Type "done" when ready: </Text>
          <TextInput
            value={inputValue}
            onChange={setInputValue}
            onSubmit={(value) => {
              if (value.toLowerCase() === "done") {
                setInputValue("");
                finishAndActivate();
              }
            }}
          />
        </Box>
      </Box>
    </Box>
  );
}
