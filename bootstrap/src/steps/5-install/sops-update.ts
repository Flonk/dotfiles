import { join } from "path";
import { addKeysToSopsYaml, hasKey, getKeyValue } from "../../lib/sops-yaml.js";

export type SopsUpdateResult =
  | { status: "added" }
  | { status: "unchanged" }
  | { status: "conflict"; existingKeys: string[] };

export interface SopsEntry {
  anchor: string;
  ageKey: string;
}

export function updateSopsYamlEntries(
  repoRoot: string,
  entries: SopsEntry[],
): SopsUpdateResult {
  const sopsPath = join(repoRoot, ".sops.yaml");

  const conflicting: string[] = [];
  const toAdd: SopsEntry[] = [];

  for (const entry of entries) {
    if (hasKey(sopsPath, entry.anchor)) {
      const current = getKeyValue(sopsPath, entry.anchor);
      if (current !== entry.ageKey) conflicting.push(entry.anchor);
    } else {
      toAdd.push(entry);
    }
  }

  if (conflicting.length > 0) {
    return { status: "conflict", existingKeys: conflicting };
  }

  if (toAdd.length === 0) {
    return { status: "unchanged" };
  }

  addKeysToSopsYaml(sopsPath, toAdd);
  return { status: "added" };
}
