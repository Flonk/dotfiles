This skill handles food logging, Garmin syncing, and end-of-day summaries. Behavior depends on context:

**Important:** Food tracking lives in Obsidian, NOT Garmin. Calorie logs are stored at `claude/crystallized/calorie-log/YYYY-MM-DD.md` and the food database is at `claude/crystallized/food-db.md`. Never use Garmin's food log tools.

---

## Quick Food Log

Triggered when the user mentions specific food they ate (e.g. "track 1 butter croissant", "log a protein shake").

1. Look up each item in `claude/crystallized/food-db.md`. If not found, **you MUST WebSearch for real nutrition facts** — never estimate or invent numbers. Add the item to the DB, then continue.
2. Get today's date with `date '+%Y-%m-%d'`, then read `claude/crystallized/calorie-log/YYYY-MM-DD.md` (substituting the actual date).
   - If the file doesn't exist yet: create it with proper frontmatter and an empty `## Calories & Macros` section, then add the item(s).
   - If the file exists and has a `## Calories & Macros` table: use Edit to insert the new row(s) before the `**Total**` row, and update the totals.
   - If the file exists but has no table yet: append a new `## Calories & Macros` section with the item(s) and a totals row.
3. Do NOT pull Garmin data. Do NOT update the Activity or Summary sections.
4. Confirm what was logged and the updated running totals to the user.

New file format when creating from scratch:

```markdown
---
date: YYYY-MM-DD
tags: [claude/calorie-log]
---

## Calories & Macros

| Meal      | Item   | kcal    | Protein   | Carbs    | Fat      |
| --------- | ------ | ------- | --------- | -------- | -------- |
| 1         | <item> | <kcal>  | <protein> | <carbs>  | <fat>    |
| **Total** |        | **<X>** | **<X>g**  | **<X>g** | **<X>g** |
```

---

## Garmin Sync

Triggered when the user asks to pull/sync Garmin data (e.g. "pull garmin data", "sync garmin").

1. Get today's date with `date '+%Y-%m-%d'` and read `claude/crystallized/calorie-log/YYYY-MM-DD.md`. If the file doesn't exist, create it with proper frontmatter first.
2. Pull today's Garmin data in parallel:
   - Activities via `mcp__garmin__get_activities_fordate`
   - Daily stats via `mcp__garmin__get_stats` (for `total_calories`, `bmr_calories`, `active_calories`)
   - If any activity is `strength_training`: ask the user what they trained (muscle groups / exercises) and add that to the activity entry in the note.
3. Update the calorie-log file by patching (Read + Edit, never overwrite):
   - `## Activity` table with each Garmin activity, duration, calories, and (for strength) what was trained
   - `## Summary` with:
     - Food in (from existing `## Calories & Macros` total, or 0 if none logged)
     - Total burn (Garmin `total_calories`: BMR + all active calories)
     - Deficit/surplus (food in − total burn)
     - Macro totals vs targets (protein target: 1.8–2g/kg × 81kg = ~145–162g/day)
4. Add each Garmin activity as a calendar event on the **Health** calendar (`8f2e64d5c77c0f450e0b95518e3fe7177f0878382bbdb6181c90130ec9b7e240@group.calendar.google.com`) using `mcp__claude_ai_Google_Calendar__gcal_create_event`:
   - Use the activity's actual start time and duration
   - Title format: e.g. "Strength Training", "Treadmill Run", etc. (human-readable)
   - Location rules:
     - `strength_training` or `treadmill_running`: set location to `FITINN Favoritenstraße 88-90, 1100 Wien` (https://maps.app.goo.gl/YENvGaVeBX7pBrX47)
     - Any other activity type (e.g. yoga, cycling, swimming): ask the user where they were before creating the event, then include the location if provided
   - Only create the event if it doesn't already exist for that day/time (check with `gcal_list_events` first)
5. Report the updated summary to the user: food in, total burn, deficit/surplus, macros vs targets.

---

## End of Day Summary

Triggered when the user asks for a daily summary or end-of-day wrap-up.

1. Read `claude/crystallized/food-db.md`. Get today's date with `date '+%Y-%m-%d'` and read `claude/crystallized/calorie-log/YYYY-MM-DD.md`. If the file doesn't exist, create it with proper frontmatter and empty sections first.
2. Ask the user what they ate today (any meals/snacks not yet logged). Then look up each item in the food DB (adding any unknowns), and update the `## Calories & Macros` table exactly as in the Quick Food Log flow.
3. Run the full Garmin Sync flow (steps 2–4 above).
4. Report the full summary to the user: food in, total burn, deficit/surplus, macros vs targets.
5. Check `claude/gold/projects.md` for any events that have now passed. Ask the user how they went, then remove them from the list.
6. Ask the user about any new events, plans, or things coming up that should be added to `claude/gold/projects.md`.
