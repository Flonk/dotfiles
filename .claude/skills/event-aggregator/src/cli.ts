import { num, parse, str, today } from "./args.ts";
import { main as brief } from "./commands/brief.ts";
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

  brief                the day grouped into sections, ranked inside each
    --date YYYY-MM-DD  default today
    --limit N          rows per section (default 12)
    --json             machine-readable

  merge                flat events.json export from the sample files
  stats                store health: fill rates, failures, top sources
    --top N            default 15
`;

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
        date: str(f, "date", today()),
        limit: num(f, "limit", 40),
        why: f.flags.has("why"),
      });
    case "rotate":
      return rotate({
        slugs: f.bare,
        minRun: num(f, "min-run", 3),
        all: f.flags.has("all"),
      });
    case "brief":
      return brief({
        date: str(f, "date", today()),
        limit: num(f, "limit", 12),
        json: f.flags.has("json"),
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
