import { useEffect, useRef, useState } from "react";
import { Box, Text } from "ink";
import TextInput from "ink-text-input";
import { useBootstrap } from "../../context.js";
import { isNixOS, runNixosInfect } from "./nixos-check.js";
import { sshCheck } from "../../lib/ssh.js";

type Sub = "checking" | "offer_infect" | "infecting" | "wait_reconnect";

export function Step3() {
  const ctx = useBootstrap();
  const [sub, setSub] = useState<Sub>("checking");

  useEffect(() => {
    if (sub !== "checking") return;
    (async () => {
      try {
        const nixos = await isNixOS(ctx.target);
        if (nixos) {
          ctx.advanceStep();
        } else {
          setSub("offer_infect");
        }
      } catch (e) {
        ctx.fail(e instanceof Error ? e.message : String(e));
      }
    })();
  }, [sub]);

  if (sub === "checking") {
    return (
      <Box>
        <Text>Checking for NixOS on {ctx.target}…</Text>
      </Box>
    );
  }

  if (sub === "offer_infect") {
    return <InfectConfirm onAccept={() => setSub("infecting")} />;
  }

  if (sub === "infecting") {
    return <Infecting onDone={() => setSub("wait_reconnect")} />;
  }

  return <WaitReconnect onReconnected={() => ctx.advanceStep()} />;
}

function InfectConfirm({ onAccept }: { onAccept: () => void }) {
  const ctx = useBootstrap();
  const [inputValue, setInputValue] = useState("");

  return (
    <Box flexDirection="column" marginY={1}>
      <Text bold>Remote is not running NixOS.</Text>
      <Box marginTop={1}>
        <Text bold>Run nixos-infect to convert it? (type "yes" or "no"): </Text>
        <TextInput
          value={inputValue}
          onChange={setInputValue}
          onSubmit={(value) => {
            const v = value.toLowerCase().trim();
            if (v === "yes") {
              onAccept();
            } else if (v === "no") {
              ctx.fail("Remote is not running NixOS. Cannot continue.");
            }
          }}
        />
      </Box>
    </Box>
  );
}

function Infecting({ onDone }: { onDone: () => void }) {
  const ctx = useBootstrap();
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    runNixosInfect(ctx.target)
      .then(onDone)
      .catch((e) => ctx.fail(e instanceof Error ? e.message : String(e)));
  }, []);

  return (
    <Box flexDirection="column" marginY={1}>
      <Text bold>Remote is not running NixOS.</Text>
      <Text>Running nixos-infect... (this will take a while)</Text>
    </Box>
  );
}

function WaitReconnect({ onReconnected }: { onReconnected: () => void }) {
  const ctx = useBootstrap();
  const [attempts, setAttempts] = useState(0);
  const checking = useRef(false);
  const reconnected = useRef(false);

  useEffect(() => {
    const interval = setInterval(async () => {
      if (checking.current || reconnected.current) return;
      checking.current = true;
      setAttempts((a) => a + 1);
      const ok = await sshCheck(ctx.target);
      checking.current = false;
      if (ok && !reconnected.current) {
        reconnected.current = true;
        clearInterval(interval);
        onReconnected();
      }
    }, 5000);

    return () => clearInterval(interval);
  }, [ctx.target, onReconnected]);

  return (
    <Box flexDirection="column" marginY={1}>
      <Text bold>nixos-infect complete. Waiting for reboot...</Text>
      <Text>
        Pinging {ctx.target} every 5s (attempt {attempts})
      </Text>
    </Box>
  );
}
