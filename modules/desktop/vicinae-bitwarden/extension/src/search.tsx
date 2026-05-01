import { useEffect, useState } from "react";
import { execFileSync, spawn, spawnSync } from "child_process";
import { writeFileSync, unlinkSync } from "fs";
import { join } from "path";
import { List, ActionPanel, Action, Clipboard, Form, showToast, Toast } from "@vicinae/api";

interface VaultItem {
  id: string;
  name: string;
  user: string | null;
  folder: string | null;
  uris: string[] | null;
  type: string;
}

type State =
  | { tag: "loading" }
  | { tag: "locked"; error?: string }
  | { tag: "ready"; items: VaultItem[]; masterPassword: string }
  | { tag: "error"; message: string };

const PINENTRY_FILE = join(
  process.env.XDG_RUNTIME_DIR ?? `/run/user/${process.getuid!()}`,
  "rbw-pinentry",
);

function setPinentryPassword(password: string) {
  writeFileSync(PINENTRY_FILE, password, { mode: 0o600 });
}

function clearPinentryPassword() {
  try { unlinkSync(PINENTRY_FILE); } catch {}
}

function isVaultLocked(): boolean {
  return spawnSync("rbw", ["unlocked"]).status !== 0;
}

function runCapture(cmd: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const proc = spawn(cmd, args);
    const stdout: string[] = [];
    const stderr: string[] = [];
    proc.stdout?.on("data", (d) => stdout.push(String(d)));
    proc.stderr?.on("data", (d) => stderr.push(String(d)));
    proc.on("close", (code) => {
      if (code === 0) resolve(stdout.join(""));
      else reject(new Error(stderr.join("").trim() || `${cmd} exited with code ${code}`));
    });
  });
}

async function rbw(masterPassword: string, args: string[]): Promise<string> {
  setPinentryPassword(masterPassword);
  try {
    return await runCapture("rbw", args);
  } finally {
    clearPinentryPassword();
  }
}

async function copyPassword(item: VaultItem, masterPassword: string) {
  const args = ["get", item.name];
  if (item.user) args.push(item.user);
  const password = await rbw(masterPassword, args);
  await Clipboard.copy(password.trim(), { concealed: true });
  execFileSync("notify-send", ["🔑 Password copied", item.name]);
  execFileSync("vicinae", ["close"]);
}

function trunc(s: string): string {
  return s.length > 36 ? s.slice(0, 35) + "…" : s;
}

function ItemDetail({ item }: { item: VaultItem }) {
  return (
    <List.Item.Detail
      metadata={
        <List.Item.Detail.Metadata>
          <List.Item.Detail.Metadata.Label title="Type" text={trunc(item.type)} />
          {item.folder && (
            <List.Item.Detail.Metadata.Label title="Folder" text={trunc(item.folder)} />
          )}
          {item.user && (
            <List.Item.Detail.Metadata.Label title="Username" text={trunc(item.user)} />
          )}
          {item.uris && item.uris.length > 0 && (
            <>
              <List.Item.Detail.Metadata.Separator />
              {item.uris.map((uri, i) => (
                <List.Item.Detail.Metadata.Link
                  key={i}
                  title={i === 0 ? "URL" : `URL ${i + 1}`}
                  target={uri}
                  text={trunc(uri)}
                />
              ))}
            </>
          )}
        </List.Item.Detail.Metadata>
      }
    />
  );
}

export default function SearchVault() {
  const [state, setState] = useState<State>({ tag: "loading" });

  async function load() {
    setState({ tag: "loading" });
    try {
      if (isVaultLocked()) {
        setState({ tag: "locked" });
      } else {
        const out = execFileSync("rbw", ["list", "--raw"], { encoding: "utf-8" });
        setState({ tag: "ready", items: JSON.parse(out), masterPassword: "" });
      }
    } catch (e) {
      setState({ tag: "error", message: e instanceof Error ? e.message : String(e) });
    }
  }

  useEffect(() => { load(); }, []);

  if (state.tag === "loading") {
    return <List isLoading />;
  }

  if (state.tag === "locked") {
    const handleUnlock = async (values: Form.Values) => {
      const masterPassword = values.password as string;
      const toast = await showToast({ style: Toast.Style.Animated, title: "Unlocking vault…" });
      try {
        const out = await rbw(masterPassword, ["list", "--raw"]);
        toast.style = Toast.Style.Success;
        toast.title = "Vault unlocked";
        await toast.update();
        setState({ tag: "ready", items: JSON.parse(out), masterPassword });
      } catch {
        toast.style = Toast.Style.Failure;
        toast.title = "Incorrect master password";
        await toast.update();
        setState({ tag: "locked", error: "Incorrect master password" });
      }
    };

    return (
      <Form
        actions={
          <ActionPanel>
            <Action.SubmitForm title="Unlock" onSubmit={handleUnlock} />
          </ActionPanel>
        }
      >
        <Form.PasswordField
          id="password"
          title="Master Password"
          autoFocus
          error={state.error}
          onChange={() => { if (state.error) setState({ tag: "locked" }); }}
        />
      </Form>
    );
  }

  if (state.tag === "error") {
    return (
      <List>
        <List.EmptyView title="Error" description={state.message} />
      </List>
    );
  }

  const { items, masterPassword } = state;

  return (
    <List isShowingDetail searchBarPlaceholder="Search vault…">
      {items.map((item) => (
        <List.Item
          key={item.id}
          id={item.id}
          title={item.name}
          subtitle={item.user ?? undefined}
          detail={<ItemDetail item={item} />}
          actions={
            <ActionPanel>
              <Action title="Copy Password" onAction={() => copyPassword(item, masterPassword)} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
