export type Flags = { bare: string[]; flags: Map<string, string | true> };

// Only these consume the next argument. Without the list, `--seed porgy` reads
// porgy as the value of --seed and silently drops it from the slug list.
export const VALUE_FLAGS = new Set(["date", "limit", "jobs", "min-run", "top"]);

export function parse(argv: string[]): Flags {
  const bare: string[] = [];
  const flags = new Map<string, string | true>();
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i] as string;
    if (!a.startsWith("--")) {
      bare.push(a);
      continue;
    }
    const [key, inline] = a.slice(2).split("=", 2) as [string, string | undefined];
    if (inline !== undefined) {
      flags.set(key, inline);
      continue;
    }
    const next = argv[i + 1];
    if (VALUE_FLAGS.has(key) && next !== undefined && !next.startsWith("--")) {
      flags.set(key, next);
      i++;
    } else {
      flags.set(key, true);
    }
  }
  return { bare, flags };
}

export function num(f: Flags, key: string, dflt: number): number {
  const v = f.flags.get(key);
  const n = typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : dflt;
}

export function str(f: Flags, key: string, dflt: string): string {
  const v = f.flags.get(key);
  return typeof v === "string" ? v : dflt;
}

export function today(at: Date = new Date()): string {
  const p = (n: number) => String(n).padStart(2, "0");
  return `${at.getFullYear()}-${p(at.getMonth() + 1)}-${p(at.getDate())}`;
}
