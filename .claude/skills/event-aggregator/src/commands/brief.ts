import * as db from "../db.ts";
import { norm, score } from "../rank.ts";
import { ORDER, TITLES, blurb, genreOf, sectionOf, type Section } from "../sections.ts";

export type BriefOpts = { date: string; limit: number; json: boolean };

export type Item = {
  section: Section;
  score: number;
  why: string[];
  time: string | null;
  title: string;
  venue: string | null;
  district: number | null;
  price: number | null;
  image: string | null;
  genre: string | null;
  blurb: string | null;
  url: string | null;
  source: string;
  runLen: number;
};

export function collect(date: string): { items: Item[]; total: number } {
  const conn = db.connect();
  const bl = db.blacklist();

  const group = new Map<string, string>();
  for (const r of db.all(conn, "SELECT slug, grp FROM scrapers")) {
    if (r["grp"]) group.set(String(r["slug"]), String(r["grp"]));
  }

  const rows = db.all(
    conn,
    "SELECT * FROM events WHERE gone=0 AND (substr(start_at,1,10)=?" +
    " OR (substr(start_at,1,10)<=? AND substr(end_at,1,10)>=?)" +
    " OR (end_at IS NULL AND substr(start_at,1,10)<=? AND extra LIKE '%permanent%'))",
    [date, date, date, date],
  ).filter((r) => !db.isBlacklisted(r, bl));

  const runDates = new Map<string, Set<string>>();
  for (const r of db.all(
    conn,
    "SELECT title, venue, start_at FROM events WHERE gone=0 AND substr(start_at,1,10)>=?",
    [date],
  )) {
    const k = `${norm(r["title"] as string)} ${r["venue"] ?? ""}`;
    let d = runDates.get(k);
    if (!d) {
      d = new Set();
      runDates.set(k, d);
    }
    d.add(String(r["start_at"]).slice(0, 16));
  }

  const seen = new Set<string>();
  const items: Item[] = [];
  for (const r of rows) {
    const title = norm(r["title"] as string);
    const k = `${title} ${String(r["start_at"]).slice(0, 16)}`;
    if (seen.has(k)) continue;
    seen.add(k);
    const runLen = runDates.get(`${title} ${r["venue"] ?? ""}`)?.size ?? 0;
    const s = score(r, runLen, date);
    const t = String(r["start_at"]).slice(11, 16);
    items.push({
      section: sectionOf(r, group.get(String(r["source"]))),
      score: s.score,
      why: s.why,
      time: t || null,
      title: String(r["title"] ?? ""),
      venue: r["venue"] ? String(r["venue"]) : null,
      district: r["district"] === null ? null : Number(r["district"]),
      price: r["price_min"] === null ? null : Number(r["price_min"]),
      image: r["image"] ? String(r["image"]) : null,
      genre: genreOf(r),
      blurb: blurb(r),
      url: r["url"] ? String(r["url"]) : null,
      source: String(r["source"]),
      runLen,
    });
  }

  items.sort((a, b) =>
    b.score - a.score || (a.time ?? "zz").localeCompare(b.time ?? "zz"));
  return { items, total: rows.length };
}

function line(i: Item): string {
  const t = (i.time ?? "  ?  ").padEnd(5);
  const where = [i.venue, i.district ? String(i.district) : null]
    .filter(Boolean).join(", ");
  const price = i.price === 0 ? "free" : i.price === null ? "" : `${i.price} EUR`;
  return `  ${t}  ${i.title.slice(0, 46).padEnd(46)} ${where.slice(0, 30).padEnd(30)} ${price}`;
}

export function main(o: BriefOpts): number {
  const { items, total } = collect(o.date);

  if (o.json) {
    console.log(JSON.stringify({ date: o.date, total, items }, null, 1));
    return 0;
  }

  console.log(`${o.date} — ${total} records, ${items.length} after dedupe\n`);

  for (const sec of ORDER) {
    const rows = items.filter((i) => i.section === sec);
    if (!rows.length) continue;
    console.log(`${TITLES[sec]} — ${rows.length}`);

    if (sec === "acts") {
      // Lineup shape: the names, comma-separated, the way a festival bill reads.
      console.log(`  ${rows.map((r) => r.title.slice(0, 40)).join(" · ")}\n`);
    }
    for (const r of rows.slice(0, o.limit)) {
      console.log(line(r));
      if (sec === "movies" && r.genre) {
        console.log(`         ${r.genre}${r.blurb ? ` — ${r.blurb.slice(0, 90)}` : ""}`);
      }
    }
    if (rows.length > o.limit) console.log(`  … and ${rows.length - o.limit} more`);
    console.log("");
  }
  return 0;
}
