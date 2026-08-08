import type { Row } from "./db.ts";

/**
 * Which part of the digest a record belongs to.
 *
 * The section must come from the EVENT, not from the scraper. Reading it off
 * the scraper's group put four concerts in "Acts" for 2026-08-09, because a gig
 * listed by volume_at counts as `aggregator` and one sold by wien_ticket counts
 * as `ticketing`. The venue's filing cabinet is not the thing you want to read.
 */
export type Section = "acts" | "movies" | "filmfest" | "exhibitions" | "rest";

export const ORDER: Section[] = ["acts", "movies", "filmfest", "exhibitions", "rest"];

export const TITLES: Record<Section, string> = {
  acts: "Acts",
  movies: "Movies",
  filmfest: "Film festivals",
  exhibitions: "Exhibitions",
  rest: "Everything else",
};

const MUSIC = /konzert|concert|\bmusik\b|\bmusic\b|jazz|\bdj\b|hiphop|hip.hop|techno|klassik|orchester|chor\b|recital|live.?act|clubbing|party|band\b|oper\b|singer|songwriter/i;
const EXHIB = /ausstellung|exhibition|sammlung|dauerausstellung|sonderausstellung|museum|galerie|gallery|vernissage/i;

/**
 * rathausplatz is a film festival that screens filmed concerts, so its records
 * are performances rather than cinema - they belong with the acts. It is also
 * not a cinema source at all the rest of the year (food festivals, an ice rink),
 * which is why the group field cannot decide this either.
 */
const ACTS_SOURCES = new Set(["rathausplatz"]);

export function sectionOf(row: Row, group: string | undefined): Section {
  const source = String(row["source"] ?? "");
  if (ACTS_SOURCES.has(source)) return "acts";

  const title = String(row["title"] ?? "");
  const category = String(row["category"] ?? "");
  const hay = `${title} ${category}`;

  if (group === "cinema") return "movies";
  if (group === "filmfest") return "filmfest";

  // The title wins over the category. "Haus der Musik - Museum" is a museum
  // that the word "Musik" dragged into the lineup; meanwhile wien_gv_at hangs
  // a multi-valued category like "Musik [Ebene1 HKV], Bühne" on venues that
  // merely sometimes host a concert. A concert genuinely called "Bonobo" at a
  // museum still lands in acts, because its title says nothing about museums.
  if (EXHIB.test(title)) return "exhibitions";
  if (group === "music" || MUSIC.test(hay)) return "acts";

  const permanent = String(row["extra"] ?? "").includes("permanent");
  if (group === "museum" || permanent || EXHIB.test(category)) return "exhibitions";
  return "rest";
}

/** A film's genre is the cinema's own category, when it looks like one. */
export function genreOf(row: Row): string | null {
  const c = String(row["category"] ?? "").trim();
  if (!c || c.length > 40 || /kino wie noch nie|fokus|event|movie_series/i.test(c)) return null;
  return c;
}

/**
 * Cinema descriptions start with a credits preamble - "Jan Komasa, PL/GB, 2025
 * 111 min., OmdU — Der 19-jaehrige Tommy...". Strip it back to the synopsis.
 */
export function blurb(row: Row, maxLen = 180): string | null {
  let d = String(row["description"] ?? "").trim();
  if (!d) return null;
  const dash = d.indexOf(" — ");
  if (dash > 0 && dash < 120) d = d.slice(dash + 3);
  d = d.replace(/\s+/g, " ").trim();
  if (!d) return null;
  if (d.length <= maxLen) return d;
  const cut = d.slice(0, maxLen);
  const stop = Math.max(cut.lastIndexOf(". "), cut.lastIndexOf("! "), cut.lastIndexOf("? "));
  return (stop > 80 ? cut.slice(0, stop + 1) : `${cut.trimEnd()}…`);
}
