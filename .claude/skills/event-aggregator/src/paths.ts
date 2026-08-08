import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
export const SCRAPERS = join(ROOT, "scrapers");
export const LIB = join(SCRAPERS, "lib");
export const SCHEMA_PATH = join(ROOT, "event.schema.json");
export const BLACKLIST_PATH = join(ROOT, "blacklist.json");
export const EVENTS_JSON = join(ROOT, "events.json");
export const DB_PATH = process.env.EA_DB || join(ROOT, "events.db");
export const PYTHON = process.env.EA_PYTHON || "python3";
