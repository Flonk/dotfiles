import { useEffect, useMemo, useState } from "react";
import { Action, ActionPanel, Clipboard, List } from "@vicinae/api";
import { lookupChar, lookupStrokes } from "./data";
import { firstStrokeHint, strokeSvgFile } from "./strokes";
import { translateInput } from "./translate";

const MAX_CHARS = 60;
const MAX_MEANINGS = 5;

const isHan = (ch: string) => /\p{Script=Han}/u.test(ch);

export default function Lookup() {
  const [input, setInput] = useState<string | null>(null);
  const [translation, setTranslation] = useState("");

  useEffect(() => {
    Clipboard.readText()
      .then((text) => setInput((text ?? "").trim()))
      .catch(() => setInput(""));
  }, []);

  const chars = useMemo(
    () => (input ? Array.from(input).filter(isHan).slice(0, MAX_CHARS) : []),
    [input],
  );

  useEffect(() => {
    if (!input || chars.length === 0) {
      setTranslation("");
      return;
    }
    let stale = false;
    setTranslation("…");
    const timer = setTimeout(() => {
      translateInput(input)
        .then((t) => {
          if (!stale) setTranslation(t || "(no translation)");
        })
        .catch(() => {
          if (!stale) setTranslation("(translation unavailable — offline?)");
        });
    }, 350);
    return () => {
      stale = true;
      clearTimeout(timer);
    };
  }, [input]);

  return (
    <List
      isLoading={input === null}
      searchText={input ?? ""}
      onSearchTextChange={setInput}
      filtering={false}
      isShowingDetail={chars.length > 0}
      searchBarPlaceholder="Paste or type Chinese text…"
    >
      {chars.length === 0 ? (
        <List.EmptyView
          title="No Chinese characters"
          description="Copy Chinese text to the clipboard or type it above"
        />
      ) : (
        chars.map((ch, i) => (
          <CharItem key={`${i}-${ch}`} ch={ch} input={input!} translation={translation} />
        ))
      )}
    </List>
  );
}

function CharItem({
  ch,
  input,
  translation,
}: {
  ch: string;
  input: string;
  translation: string;
}) {
  const entry = useMemo(() => lookupChar(ch), [ch]);
  const strokes = useMemo(() => lookupStrokes(ch), [ch]);

  const pinyin = entry?.pinyin.join(", ") ?? "";
  const meanings = (entry?.definition ?? "")
    .split(";")
    .map((m) => m.trim())
    .filter(Boolean)
    .slice(0, MAX_MEANINGS);

  const markdown = strokes
    ? `<img src="file://${strokeSvgFile(ch, strokes)}" width="300" height="300"/>\n\n` +
      `**${strokes.strokes.length} strokes** — draw stroke 1 first (highlighted): ${firstStrokeHint(strokes)}`
    : `# ${ch}\n\n_No stroke data for this character._`;

  return (
    <List.Item
      title={ch}
      subtitle={pinyin}
      accessories={meanings.length > 0 ? [{ text: meanings[0] }] : undefined}
      detail={
        <List.Item.Detail
          markdown={markdown}
          metadata={
            <List.Item.Detail.Metadata>
              <List.Item.Detail.Metadata.Label title="Character" text={ch} />
              <List.Item.Detail.Metadata.Label title="Pinyin" text={pinyin || "—"} />
              {meanings.length > 0 && (
                <List.Item.Detail.Metadata.TagList title="Meanings">
                  {meanings.map((m) => (
                    <List.Item.Detail.Metadata.TagList.Item key={m} text={m} />
                  ))}
                </List.Item.Detail.Metadata.TagList>
              )}
              <List.Item.Detail.Metadata.Separator />
              <List.Item.Detail.Metadata.Label title="Input" text={input} />
              <List.Item.Detail.Metadata.Label
                title="Translation"
                text={translation || "—"}
              />
            </List.Item.Detail.Metadata>
          }
        />
      }
      actions={
        <ActionPanel>
          <Action.CopyToClipboard title="Copy Character" content={ch} />
          {pinyin ? (
            <Action.CopyToClipboard title="Copy Pinyin" content={pinyin} />
          ) : null}
          <Action.CopyToClipboard title="Copy Translation" content={translation} />
        </ActionPanel>
      }
    />
  );
}
