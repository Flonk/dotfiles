# wienervorlesungen

- URL: https://vorlesungen.wien.gv.at/ (www.wienervorlesungen.at 301s here). robots.txt only blocks calendar action URLs, root is fine.
- Method: html. No JSON-LD Event data, no calendar API in use despite the ai1ec plugin CSS being loaded (unused). The homepage IS the season programme page: teaser sections ("Aktuelle Termine") plus an in-page archive of this season's past lectures, both built from the same `<section class="av_textblock_section">...<p>DATE</p><h2>TITLE</h2>...<h2><a href="URL">mehr lesen</a></h2>` block.
- scrape.py regex-matches these blocks, parses the German date, and keeps only start >= today and <= horizon. Speaker is pulled from "Vortrag von X" text if present.
- Publishes very few events ahead: at fetch time (2026-08-08) only ONE upcoming lecture was listed (2026-09-26, Ian McEwan). This is normal for this site — the series runs at roughly monthly cadence and only announces the next 1-2 talks. min_records=1 reflects this, not a scraper bug.
- No price is ever stated on the site for these lectures; price_min/price_text left null unless "frei/gratis/kostenlos" literally appears.
- Venue/district (Rathaus, 1010) inferred from the organizer's own address (Wienbibliothek im Rathaus) shown in page footer/imprint, not from an explicit per-event venue field — the site doesn't label venue per event, but the lecture series is well known to run in the Rathaus.
- Breaks if: the `av_textblock_section`/`itemprop="text"` markup changes (Avia builder theme update), or the "mehr lesen" link text changes.
- Re-derive: refetch homepage, grep for `Vortrag von` and the date paragraphs to confirm block structure is unchanged.
