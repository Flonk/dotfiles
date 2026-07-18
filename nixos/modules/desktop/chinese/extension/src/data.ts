import * as fs from "fs";
import * as os from "os";
import * as path from "path";

export interface DictEntry {
  definition: string;
  pinyin: string[];
}

export interface StrokeData {
  strokes: string[];
  medians: number[][][];
}

const dataDir = path.join(
  process.env.XDG_DATA_HOME ?? path.join(os.homedir(), ".local", "share"),
  "skynet-chinese",
);

let dictionary: Record<string, { d?: string; p?: string[] }> | null = null;

export function lookupChar(ch: string): DictEntry | null {
  if (!dictionary) {
    dictionary = JSON.parse(
      fs.readFileSync(path.join(dataDir, "dictionary.json"), "utf-8"),
    );
  }
  const entry = dictionary![ch];
  if (!entry) return null;
  return { definition: entry.d ?? "", pinyin: entry.p ?? [] };
}

const strokeCache = new Map<string, StrokeData | null>();

export function lookupStrokes(ch: string): StrokeData | null {
  const cached = strokeCache.get(ch);
  if (cached !== undefined) return cached;
  let result: StrokeData | null = null;
  try {
    const file = path.join(
      dataDir,
      "strokes",
      ch.codePointAt(0)!.toString(16) + ".json",
    );
    const raw = JSON.parse(fs.readFileSync(file, "utf-8"));
    result = { strokes: raw.s, medians: raw.m };
  } catch {
    result = null;
  }
  strokeCache.set(ch, result);
  return result;
}
