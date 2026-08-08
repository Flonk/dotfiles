import type { Row } from "./db.ts";

/**
 * Inverse specificity. The thing worth knowing about tonight is the thing that
 * only happens tonight; a museum's permanent collection is not news. Two
 * demotion axes, both measured on what REMAINS rather than on the total, so
 * they repeal themselves: a run with two dates left is a last chance, not
 * wallpaper.
 */
export const DEMOTE_RUN = 8;
export const DEMOTE_SPAN = 91;
export const LAST_CHANCE_SPAN = 30;
export const LAST_CHANCE_LEFT = 21;

export function norm(t: string | null): string {
  const s = (t || "").replace(/\(.*?\)|\b-?2D-?\b|OmeU|eOmU|OmU/g, "");
  return s.toLowerCase().replace(/[^a-z0-9]/g, "").slice(0, 40);
}

export function days(a: string, b: string): number {
  return Math.round(
    (Date.parse(`${a}T00:00:00Z`) - Date.parse(`${b}T00:00:00Z`)) / 86_400_000,
  );
}

export type Parts = { permanent: boolean; span: number; left: number };

export function parts(row: Row, today: string): Parts {
  const permanent = String(row["extra"] ?? "").includes("permanent");
  const start = String(row["start_at"] ?? "").slice(0, 10);
  const end = row["end_at"] ? String(row["end_at"]).slice(0, 10) : null;
  const span = permanent ? 1e6 : (end && start ? days(end, start) : 0);
  const left = end ? days(end, today) : 0;
  return { permanent, span, left };
}

export type Score = { score: number; why: string[] };

export function score(row: Row, runLen: number, today: string): Score {
  const { permanent, span, left } = parts(row, today);
  let sc = 100;
  const why: string[] = [];

  if (runLen >= DEMOTE_RUN) {
    sc -= 60;
    why.push(`run×${runLen}`);
  }
  if (permanent) {
    sc -= 50;
    why.push("permanent");
  } else if (span >= DEMOTE_SPAN) {
    sc -= 45;
    why.push(`runs ${span}d`);
  }
  if (!permanent && span >= LAST_CHANCE_SPAN && left >= 0 && left <= LAST_CHANCE_LEFT) {
    sc += 70;
    why.push(`LAST CHANCE ${left}d left`);
  }
  if (runLen <= 2 && span <= 1 && !permanent) {
    sc += 15;
    why.push("one-off");
  }
  if (row["price_min"] === 0) {
    sc += 5;
    why.push("free");
  }
  return { score: sc, why };
}
