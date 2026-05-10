import { useEffect, useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { useBootstrap } from "../../context.js";
import { sshCheck } from "../../lib/ssh.js";
import { updateRegistry } from "../../lib/registry.js";

type Sub = "input_target" | "running";

export function Step2() {
  const ctx = useBootstrap();
  const [sub, setSub] = useState<Sub>("input_target");

  useEffect(() => {
    if (sub !== "running") return;
    (async () => {
      try {
        const ok = await sshCheck(ctx.target);
        if (!ok) throw new Error(`Cannot connect to ${ctx.target}`);
        await updateRegistry(ctx.repoRoot, ctx.installationName, ctx.target);
        ctx.advanceStep();
      } catch (e) {
        ctx.fail(e instanceof Error ? e.message : String(e));
      }
    })();
  }, [sub]);

  if (sub === "input_target") {
    return (
      <Box>
        <Text bold>SSH target (user@host): </Text>
        <TextInput
          value={ctx.target}
          onChange={ctx.setTarget}
          onSubmit={() => {
            if (!ctx.target) return;
            setSub("running");
          }}
        />
      </Box>
    );
  }

  return (
    <Box>
      <Text>Connecting to {ctx.target}…</Text>
    </Box>
  );
}
