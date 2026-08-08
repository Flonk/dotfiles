# visitingvienna

- url: https://www.visitingvienna.com/entertainment/events/film-festivals/
- method: html — no ld+json/API. Article body has one `<h3 id="...">` per festival
  followed by prose paragraphs and a "Next dates: <English date range>" sentence.
- Parser splits the article on h2/h3/h4 headings, grabs the h3's id as source_id, the
  first `<a href>` in the section as url, and regexes the "Next dates:" sentence for a
  Month/Day[-Month/Day], Year range.
- Skips "Next dates: TBA" (unannounced next edition, incl. cases like "TBA (was ...
  2025)") — never guesses from the historical aside. Also skips ranges whose end (or
  start, if single-day) is already before today, since the page is only updated ~monthly
  and lags behind.
- No venue/district/price given per festival on this page — always null.
- ~14 upcoming festivals at any time, occasionally as far as next year (Vienna Shorts
  was listed ~9 months out). No pagination; this is the whole horizon the site offers.
- Re-derive: refetch, breaks if the site restructures headings or drops the "Next
  dates:" wording/format.
