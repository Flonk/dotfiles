import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

import { LIB, PYTHON, SCRAPERS } from "./paths.ts";
import { validate, type EventRecord } from "./schema.ts";

export type Harvest = { valid: EventRecord[]; invalid: number };

type Exec = { code: number | null; stdout: string; stderr: string };

/**
 * The seam of the migration: scrapers stay Python and communicate over the
 * contract they already speak — one JSON record per line on stdout. Nothing
 * about a scraper needs to change for the TypeScript pipeline to drive it.
 */
function exec(slug: string, horizonDays: number, timeoutMs: number): Promise<Exec> {
  return new Promise((resolve, reject) => {
    const child = spawn(PYTHON, ["scrape.py"], {
      cwd: join(SCRAPERS, slug),
      env: {
        ...process.env,
        PYTHONPATH: LIB,
        EA_HORIZON_DAYS: String(horizonDays || 180),
      },
    });
    const out: Buffer[] = [];
    const err: Buffer[] = [];
    const timer = setTimeout(() => {
      child.kill("SIGKILL");
      reject(new Error(`timeout after ${Math.round(timeoutMs / 1000)}s`));
    }, timeoutMs);

    child.stdout.on("data", (c: Buffer) => out.push(c));
    child.stderr.on("data", (c: Buffer) => err.push(c));
    child.on("error", (e) => {
      clearTimeout(timer);
      reject(e);
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      resolve({
        code,
        stdout: Buffer.concat(out).toString("utf8"),
        stderr: Buffer.concat(err).toString("utf8"),
      });
    });
  });
}

export function parse(stdout: string): Harvest {
  const valid: EventRecord[] = [];
  let invalid = 0;
  for (const line of stdout.split("\n")) {
    if (!line.trim()) continue;
    let rec: unknown;
    try {
      rec = JSON.parse(line);
    } catch {
      invalid++;
      continue;
    }
    if (validate(rec).length) invalid++;
    else valid.push(rec as EventRecord);
  }
  return { valid, invalid };
}

export async function scrape(
  slug: string,
  horizonDays: number,
  timeoutMs = 600_000,
): Promise<Harvest> {
  const p = await exec(slug, horizonDays, timeoutMs);
  if (p.code !== 0) {
    throw new Error(`exit ${p.code}: ${p.stderr.slice(-800).trim()}`);
  }
  const h = parse(p.stdout);
  // A redesigned site that now parses to nothing must record a failure, not
  // quietly blank the source and take every one of its events with it.
  if (!h.valid.length) throw new Error(`zero valid records (${h.invalid} invalid)`);
  return h;
}

export function fromSample(slug: string): Harvest {
  const f = join(SCRAPERS, slug, "scraper_example_result.json");
  if (!existsSync(f)) throw new Error("no sample file");
  return { valid: JSON.parse(readFileSync(f, "utf8")) as EventRecord[], invalid: 0 };
}
