import { useEffect, useState } from "react";
import { LaunchProps, List } from "@vicinae/api";
import { VaultItem, isLocked, listItems } from "./rbw";
import { UnlockForm } from "./UnlockForm";
import { VaultList } from "./VaultList";

type State =
  | { tag: "loading" }
  | { tag: "locked" }
  | { tag: "ready"; items: VaultItem[]; masterPassword: string }
  | { tag: "error"; message: string };

export default function SearchVault(props: LaunchProps<{ arguments: { query: string } }>) {
  const [state, setState] = useState<State>({ tag: "loading" });

  useEffect(() => {
    try {
      if (isLocked()) {
        setState({ tag: "locked" });
      } else {
        setState({ tag: "ready", items: listItems(), masterPassword: "" });
      }
    } catch (e) {
      setState({ tag: "error", message: e instanceof Error ? e.message : String(e) });
    }
  }, []);

  if (state.tag === "loading") return <List isLoading />;

  if (state.tag === "locked") {
    return (
      <UnlockForm
        onUnlock={(items, masterPassword) =>
          setState({ tag: "ready", items, masterPassword })
        }
      />
    );
  }

  if (state.tag === "error") {
    return (
      <List>
        <List.EmptyView title="Error" description={state.message} />
      </List>
    );
  }

  return (
    <VaultList
      items={state.items}
      masterPassword={state.masterPassword}
      initialQuery={props.arguments.query}
    />
  );
}
