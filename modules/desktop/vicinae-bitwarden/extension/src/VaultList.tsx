import { useState } from "react";
import { execFileSync } from "child_process";
import { Action, ActionPanel, Clipboard, List } from "@vicinae/api";
import { VaultItem, getPassword } from "./rbw";

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

async function copyPassword(item: VaultItem, masterPassword: string) {
  const password = await getPassword(item, masterPassword);
  await Clipboard.copy(password, { concealed: true });
  execFileSync("notify-send", ["🔑 Password copied", item.name]);
  execFileSync("vicinae", ["close"]);
}

export function VaultList({
  items,
  masterPassword,
  initialQuery,
}: {
  items: VaultItem[];
  masterPassword: string;
  initialQuery?: string;
}) {
  const [searchText, setSearchText] = useState(initialQuery ?? "");

  return (
    <List
      isShowingDetail
      searchBarPlaceholder="Search vault…"
      searchText={searchText}
      onSearchTextChange={setSearchText}
      filtering
    >
      {items.map((item) => (
        <List.Item
          key={item.id}
          id={item.id}
          title={item.name}
          subtitle={item.user ?? undefined}
          keywords={item.uris ?? undefined}
          detail={<ItemDetail item={item} />}
          actions={
            <ActionPanel>
              <Action
                title="Copy Password"
                onAction={() => copyPassword(item, masterPassword)}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
