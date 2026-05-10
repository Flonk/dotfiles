import { readFileSync, writeFileSync } from "fs";
import { parseDocument, YAMLSeq } from "yaml";

/**
 * Adds key definitions to the `keys:` section of .sops.yaml ONLY.
 * Does NOT touch creation_rules — the user does that manually.
 */
export function addKeysToSopsYaml(
  filePath: string,
  entries: { anchor: string; ageKey: string }[],
): void {
  const content = readFileSync(filePath, "utf-8");
  const doc = parseDocument(content);

  const keys = doc.get("keys", true);
  if (!(keys instanceof YAMLSeq)) {
    throw new Error("Could not find 'keys' sequence in .sops.yaml");
  }

  for (const entry of entries) {
    const node = doc.createNode(entry.ageKey);
    node.anchor = entry.anchor;
    keys.add(node);
  }

  writeFileSync(filePath, doc.toString());
}

export function hasKey(filePath: string, anchor: string): boolean {
  const content = readFileSync(filePath, "utf-8");
  return content.includes(`&${anchor} `);
}

export function getKeyValue(filePath: string, anchor: string): string | null {
  const content = readFileSync(filePath, "utf-8");
  const match = content.match(new RegExp(`&${anchor}\\s+(\\S+)`));
  return match ? match[1] : null;
}
