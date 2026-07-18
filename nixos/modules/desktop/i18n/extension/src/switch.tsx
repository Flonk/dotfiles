import { useEffect, useState } from "react";
import { execFileSync } from "child_process";
import { Action, ActionPanel, Icon, List } from "@vicinae/api";

interface InputMethod {
  im: string;
  label: string;
}

function listMethods(): InputMethod[] {
  const out = execFileSync("skynet-i18n", ["list"], { encoding: "utf-8" });
  return out
    .trim()
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      const [im, label] = line.split("\t");
      return { im, label };
    });
}

function currentMethod(): string {
  try {
    return execFileSync("skynet-i18n", ["current"], { encoding: "utf-8" }).trim();
  } catch {
    return "";
  }
}

function switchTo(method: InputMethod) {
  execFileSync("skynet-i18n", ["set", method.im]);
  execFileSync("notify-send", ["⌨️ Keyboard switched", method.label]);
  execFileSync("vicinae", ["close"]);
}

type State =
  | { tag: "loading" }
  | { tag: "ready"; methods: InputMethod[]; current: string }
  | { tag: "error"; message: string };

export default function SwitchKeyboard() {
  const [state, setState] = useState<State>({ tag: "loading" });

  useEffect(() => {
    try {
      setState({ tag: "ready", methods: listMethods(), current: currentMethod() });
    } catch (e) {
      setState({ tag: "error", message: e instanceof Error ? e.message : String(e) });
    }
  }, []);

  if (state.tag === "loading") return <List isLoading />;

  if (state.tag === "error") {
    return (
      <List>
        <List.EmptyView title="Error" description={state.message} />
      </List>
    );
  }

  return (
    <List searchBarPlaceholder="Switch keyboard…">
      {state.methods.map((method) => (
        <List.Item
          key={method.im}
          id={method.im}
          title={method.label}
          subtitle={method.im}
          icon={Icon.Keyboard}
          accessories={method.im === state.current ? [{ text: "active" }] : undefined}
          actions={
            <ActionPanel>
              <Action title="Switch" onAction={() => switchTo(method)} />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
