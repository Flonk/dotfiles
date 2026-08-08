import { readFileSync } from "node:fs";
import { SCHEMA_PATH } from "./paths.ts";

export type EventStatus = "scheduled" | "cancelled" | "postponed";

export type EventRecord = {
  source: string;
  source_id: string;
  url: string;
  title: string;
  start: string;
  end?: string | null;
  venue?: string | null;
  district?: number | null;
  city?: string | null;
  address?: string | null;
  price_min?: number | null;
  price_text?: string | null;
  category?: string | null;
  description?: string | null;
  image?: string | null;
  status?: EventStatus;
  extra?: Record<string, unknown>;
};

type PropSpec = {
  type?: string | string[];
  enum?: unknown[];
  minimum?: number;
  maximum?: number;
};

type Schema = {
  required: string[];
  properties: Record<string, PropSpec>;
};

const schema = JSON.parse(readFileSync(SCHEMA_PATH, "utf8")) as Schema;

const DATE = /^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?$/;

function typesOf(spec: PropSpec): string[] {
  const t = spec.type ?? "string";
  return Array.isArray(t) ? t : [t];
}

/**
 * Port of scrapers/check.py:check_rec. Returns a list of problems; empty means
 * the record is good. Kept deliberately structural rather than pulling in a
 * JSON Schema library — the schema is small and this stays dependency-free.
 */
export function validate(rec: unknown): string[] {
  const errs: string[] = [];
  if (rec === null || typeof rec !== "object" || Array.isArray(rec)) {
    return ["not an object"];
  }
  const r = rec as Record<string, unknown>;

  for (const k of schema.required) {
    const v = r[k];
    if (v === null || v === undefined || v === "") {
      errs.push(`missing required ${k}`);
    }
  }

  for (const [k, v] of Object.entries(r)) {
    const spec = schema.properties[k];
    if (!spec) {
      errs.push(`unknown field ${k}`);
      continue;
    }
    const ts = typesOf(spec);
    if (v === null || v === undefined) {
      if (!ts.includes("null")) errs.push(`${k} must not be null`);
      continue;
    }
    const ok =
      (ts.includes("string") && typeof v === "string") ||
      (ts.includes("integer") && typeof v === "number" && Number.isInteger(v)) ||
      (ts.includes("number") && typeof v === "number") ||
      (ts.includes("object") && typeof v === "object" && !Array.isArray(v));
    if (!ok) {
      errs.push(`${k} wrong type (${typeof v}, want ${ts.join("|")})`);
      continue;
    }
    if ((k === "start" || k === "end") && typeof v === "string" && !DATE.test(v)) {
      errs.push(`${k} bad format: ${JSON.stringify(v)}`);
    }
    if (spec.enum && !spec.enum.includes(v)) {
      errs.push(`${k} not in enum: ${JSON.stringify(v)}`);
    }
    if (spec.minimum !== undefined && typeof v === "number" && v < spec.minimum) {
      errs.push(`${k} below minimum`);
    }
    if (spec.maximum !== undefined && typeof v === "number" && v > spec.maximum) {
      errs.push(`${k} above maximum`);
    }
  }
  return errs;
}
