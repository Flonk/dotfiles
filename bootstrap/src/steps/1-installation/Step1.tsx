import { useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import SelectInput from "ink-select-input";
import { useBootstrap } from "../../context.js";
import {
  getInstallations,
  getUsers,
  getHosts,
  parseInstallation,
} from "../../lib/installations.js";

type Sub =
  | "pick_or_new"
  | "pick_installation"
  | "input_host"
  | "pick_arch"
  | "pick_user"
  | "input_user";

export function Step1() {
  const ctx = useBootstrap();
  const [sub, setSub] = useState<Sub>("pick_or_new");
  const [hostName, setHostName] = useState("");
  const [userName, setUserName] = useState("");

  const installations = getInstallations(ctx.repoRoot);
  const users = getUsers(ctx.repoRoot);
  const hosts = getHosts(ctx.repoRoot);

  if (sub === "pick_or_new") {
    return (
      <Box flexDirection="column">
        <Text bold>Use an existing installation or create a new one?</Text>
        <SelectInput
          items={[
            { label: "Existing installation", value: "existing" },
            { label: "New installation", value: "new" },
          ]}
          onSelect={(item) => {
            setSub(item.value === "existing" ? "pick_installation" : "input_host");
          }}
        />
      </Box>
    );
  }

  if (sub === "pick_installation") {
    return (
      <Box flexDirection="column">
        <Text bold>Select installation:</Text>
        <SelectInput
          items={installations.map((i) => ({ label: i, value: i }))}
          onSelect={(item) => {
            ctx.setInstallationName(item.value);
            const { user, host } = parseInstallation(ctx.repoRoot, item.value);
            ctx.setSelectedUser(user);
            ctx.setSelectedHost(host);
            ctx.advanceStep();
          }}
        />
      </Box>
    );
  }

  if (sub === "input_host") {
    return (
      <Box>
        <Text bold>Host name: </Text>
        <TextInput
          value={hostName}
          onChange={setHostName}
          onSubmit={(name) => {
            if (!name) return;
            ctx.setSelectedHost(name);
            if (hosts.includes(name)) {
              setSub("pick_user");
            } else {
              ctx.setIsNewHost(true);
              setSub("pick_arch");
            }
          }}
        />
      </Box>
    );
  }

  if (sub === "pick_arch") {
    return (
      <Box flexDirection="column">
        <Text bold>Architecture:</Text>
        <SelectInput
          items={[
            { label: "x86_64-linux", value: "x86_64-linux" },
            { label: "aarch64-linux", value: "aarch64-linux" },
          ]}
          onSelect={(item) => {
            ctx.setSelectedArch(item.value);
            setSub("pick_user");
          }}
        />
      </Box>
    );
  }

  if (sub === "pick_user") {
    return (
      <Box flexDirection="column">
        <Text bold>Select user (or create new):</Text>
        <SelectInput
          items={[
            ...users.map((u) => ({ label: u, value: u })),
            { label: "+ New user", value: "__new__" },
          ]}
          onSelect={(item) => {
            if (item.value === "__new__") {
              setSub("input_user");
            } else {
              finalize(ctx, item.value);
            }
          }}
        />
      </Box>
    );
  }

  if (sub === "input_user") {
    return (
      <Box>
        <Text bold>User name: </Text>
        <TextInput
          value={userName}
          onChange={setUserName}
          onSubmit={(name) => {
            if (!name) return;
            ctx.setIsNewUser(true);
            finalize(ctx, name);
          }}
        />
      </Box>
    );
  }

  return null;
}

function finalize(ctx: ReturnType<typeof useBootstrap>, user: string) {
  const name = `${user}-${ctx.selectedHost}`;
  ctx.setSelectedUser(user);
  ctx.setInstallationName(name);
  ctx.advanceStep();
}
