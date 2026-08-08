import { main as digest } from "./commands/digest.ts";
import { main as merge } from "./commands/merge.ts";
import { main as rotate } from "./commands/rotate.ts";
import { main as scrape } from "./commands/scrape.ts";
import { main as stats } from "./commands/stats.ts";

const USAGE = `ea <command> [options]

  scrape [slug...]     scrape what is due, validate, upsert
    --all              ignore cadence, run everything built
    --seed             ingest scraper_example_result.json instead of fetching
    --dry              list what would run
    --jobs N           parallel scrapers (default 4)

  digest               one day, ranked by inverse specificity
    --date YYYY-MM-DD  default today
    --limit N          default 40
    --why              show the score reasons

  rotate [slug...]     what entered or left a fixed repertoire
    --min-run N        run length to care about (default 3)
    --all              include sources with no change

  merge                flat events.json export from the sample files
  stats                store health: fill rates, failures, top sources
    --top N            default 15
`;

type Flags = { bare: string[]; flags: Map<string, string | true> };

// Only these consume the next argument. Without the list, `--seed porgy` reads
// porgy as the value of --seed and silently drops it from the slug list.
const VALUE_FLAGS = new Set(["date", "limit", "jobs", "min-run", "top"]);

function parse(argv: string[]): Flags {
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

function num(f: Flags, key: string, dflt: number): number {
  const v = f.flags.get(key);
  const n = typeof v === "string" ? Number(v) : NaN;
  return Number.isFinite(n) ? n : dflt;
}

function today(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

async function run(): Promise<number> {
  const [cmd, ...rest] = process.argv.slice(2);
  const f = parse(rest);

  switch (cmd) {
    case "scrape":
      return await scrape({
        slugs: f.bare,
        all: f.flags.has("all"),
        seed: f.flags.has("seed"),
        dry: f.flags.has("dry"),
        jobs: num(f, "jobs", 4),
      });
    case "digest":
      return digest({
        date: typeof f.flags.get("date") === "string"
          ? (f.flags.get("date") as string)
          : today(),
        limit: num(f, "limit", 40),
        why: f.flags.has("why"),
      });
    case "rotate":
      return rotate({
        slugs: f.bare,
        minRun: num(f, "min-run", 3),
        all: f.flags.has("all"),
      });
    case "merge":
      return merge();
    case "stats":
      return stats({ top: num(f, "top", 15) });
    default:
      console.log(USAGE);
      return cmd ? 1 : 0;
  }
}

process.exitCode = await run();
