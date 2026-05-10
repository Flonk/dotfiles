import { useEffect, useRef, useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { useBootstrap } from "../../context.js";
import { getHostAgeRecipient } from "./keys.js";
import { updateSopsYamlEntries } from "./sops-update.js";
import { rebuildSystem } from "./rebuild.js";
import { gitCommitAndPush } from "../../lib/git-sync.js";
import { cloneRepo } from "../../lib/clone.js";
import { updateSopsKeys } from "../../lib/sops.js";

const ROOT_REPO_PATH = "/root/dotfiles";

type Sub =
  | "fetching_key"
  | "confirm_conflict"
  | "wait_done"
  | "rebuilding";

export function Step5() {
  const ctx = useBootstrap();
  const [sub, setSub] = useState<Sub>("fetching_key");
  const [inputValue, setInputValue] = useState("");
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    (async () => {
      try {
        const hostRecipient = await getHostAgeRecipient(ctx.target);
        ctx.setHostAgeRecipient(hostRecipient);
        const result = updateSopsYamlEntries(ctx.repoRoot, [
          { anchor: `host_${ctx.installationName}`, ageKey: hostRecipient },
        ]);
        setSub(result.status === "conflict" ? "confirm_conflict" : "wait_done");
      } catch (e) {
        ctx.fail(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  const finishAndRebuild = async () => {
    setSub("rebuilding");
    try {
      await updateSopsKeys(ctx.repoRoot);
      await gitCommitAndPush(ctx.repoRoot, ctx.installationName);
      await cloneRepo(ctx.target, ROOT_REPO_PATH);
      const host = ctx.hostFromInstallation();
      await rebuildSystem(ctx.target, host, ROOT_REPO_PATH, ctx.setStatusMsg);
      ctx.advanceStep();
    } catch (e) {
      ctx.fail(e instanceof Error ? e.message : String(e));
    }
  };

  if (sub === "fetching_key") {
    return (
      <Box>
        <Text>Reading host age recipient and updating .sops.yaml…</Text>
      </Box>
    );
  }

  if (sub === "confirm_conflict") {
    return (
      <Box flexDirection="column" marginY={1}>
        <Text bold color="yellow">
          host_{ctx.installationName} already exists in .sops.yaml with a different value.
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
                ctx.fail("Aborted — host key conflict in .sops.yaml");
              }
            }}
          />
        </Box>
      </Box>
    );
  }

  if (sub === "rebuilding") {
    return (
      <Box>
        <Text>Re-encrypting secrets, pushing config, cloning to {ROOT_REPO_PATH}, and running nixos-rebuild…</Text>
      </Box>
    );
  }

  return (
    <Box flexDirection="column">
      <Box flexDirection="column" marginY={1}>
        <Text bold>Discovered host age recipient:</Text>
        <Text>
          <Text bold>host_{ctx.installationName}</Text>: {ctx.hostAgeRecipient}
        </Text>
      </Box>
      <Box flexDirection="column" marginY={1}>
        <Text bold>host_{ctx.installationName} added to .sops.yaml `keys:` section.</Text>
        <Text>
          Now add *host_{ctx.installationName} to the relevant entries under
          creation_rules in .sops.yaml.
        </Text>
        <Text>Also update flake.nix if this is a new installation.</Text>
        <Box marginTop={1}>
          <Text bold>Type "done" when ready: </Text>
          <TextInput
            value={inputValue}
            onChange={setInputValue}
            onSubmit={(value) => {
              if (value.toLowerCase() === "done") {
                setInputValue("");
                finishAndRebuild();
              }
            }}
          />
        </Box>
      </Box>
    </Box>
  );
}
