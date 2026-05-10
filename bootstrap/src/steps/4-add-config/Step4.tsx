import { useEffect, useRef } from "react";
import { Box, Text } from "ink";
import { readFileSync, readdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import { useBootstrap } from "../../context.js";
import { sshRun } from "../../lib/ssh.js";
import { fetchHardwareConfig } from "../../lib/hardware.js";
import {
  createHostFromTemplate,
  createUserFromTemplate,
  createInstallation,
} from "../../lib/installations.js";

function readLocalSshKeys(): string[] {
  const sshDir = join(homedir(), ".ssh");
  const pubFiles = readdirSync(sshDir).filter((f) => f.endsWith(".pub"));
  const keys: string[] = [];
  for (const f of pubFiles) {
    const content = readFileSync(join(sshDir, f), "utf-8").trim();
    if (content) keys.push(content);
  }
  return keys;
}

export function Step4() {
  const ctx = useBootstrap();
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    if (!ctx.isNewHost && !ctx.isNewUser) {
      ctx.skipStep();
      return;
    }

    (async () => {
      try {
        if (ctx.isNewHost) {
          const stateVersion =
            (await sshRun(
              ctx.target,
              "nixos-version 2>/dev/null | cut -d. -f1-2 || echo 24.11",
            )) || "24.11";
          const sshKeys = readLocalSshKeys();
          createHostFromTemplate(
            ctx.repoRoot,
            ctx.selectedHost,
            ctx.selectedUser,
            ctx.selectedArch,
            stateVersion,
            sshKeys,
          );
        }
        if (ctx.isNewUser) {
          createUserFromTemplate(ctx.repoRoot, ctx.selectedUser);
        }
        createInstallation(ctx.repoRoot, ctx.selectedUser, ctx.selectedHost);
        await fetchHardwareConfig(ctx.repoRoot, ctx.selectedHost, ctx.target);
        ctx.advanceStep();
      } catch (e) {
        ctx.fail(e instanceof Error ? e.message : String(e));
      }
    })();
  }, []);

  return (
    <Box>
      <Text>Adding config to repo…</Text>
    </Box>
  );
}
