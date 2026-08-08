import datetime
import re
import sys
import urllib.parse
import urllib.request

import ea

AJAX_URL = "https://marxhalle.at/wp-admin/admin-ajax.php"

WIDGET_SETTINGS = {
    "lisitng_id": 197, "posts_num": 16, "columns": 4, "columns_tablet": 2, "columns_mobile": 1,
    "column_min_width": 240, "column_min_width_tablet": 240, "column_min_width_mobile": 240,
    "inline_columns_css": False, "is_archive_template": "", "post_status": ["publish"],
    "use_random_posts_num": "", "max_posts_num": 9, "not_found_message": "No data was found",
    "is_masonry": False, "equal_columns_height": "yes", "use_load_more": "yes",
    "load_more_id": "load-more", "load_more_type": "click",
    "load_more_offset": {"unit": "px", "size": 0, "sizes": []},
    "use_custom_post_types": "", "custom_post_types": ["events"], "hide_widget_if": "",
    "carousel_enabled": "yes", "slides_to_scroll": "1", "arrows": "true",
    "arrow_icon": "fa fa-angle-left", "dots": "", "autoplay": "true", "pause_on_hover": "true",
    "autoplay_speed": 5000, "infinite": "true", "center_mode": "", "effect": "slide", "speed": 500,
    "inject_alternative_items": "", "injection_items": [], "scroll_slider_enabled": "",
    "scroll_slider_on": ["desktop", "tablet", "mobile"], "custom_query": "yes",
    "custom_query_id": "3", "_element_id": "", "collapse_first_last_gap": False,
    "list_tag_selection": "", "list_items_wrapper_tag": "div", "list_item_tag": "div",
    "empty_items_wrapper_tag": "div",
}
QUERY = {"query_id": 3, "posts_per_page": 16,
         "signature": "670e2fe1df5ebc3402b4affd15899e885fc33f7ccc46a6b600ccd38606be03c3"}

ITEM_RE = re.compile(
    r'jet-listing-dynamic-post-(\d+)[^"]*" data-post-id="\d+"\s*>'
    r'<div class="jet-engine-listing-overlay-wrap" data-url="([^"]+)"')
TITLE_RE = re.compile(
    r'<span class="jet-listing-dynamic-field__content" >([^<]*)</span>')
DATE_RE = re.compile(
    r'<p class="jet-listing-dynamic-field__content" >\s*(?:-\s*)?([\d.]{6,10})</p>')

VENUE = "MARX HALLE"
ADDRESS = "Karl-Farkas-Gasse 19"
DISTRICT = 1030


def flatten(prefix, obj, out):
    if isinstance(obj, dict):
        for k, v in obj.items():
            flatten(f"{prefix}[{k}]", v, out)
    elif isinstance(obj, list):
        for v in obj:
            flatten(f"{prefix}[]", v, out)
    elif isinstance(obj, bool):
        out.append((prefix, "true" if obj else "false"))
    elif obj is None:
        out.append((prefix, ""))
    else:
        out.append((prefix, str(obj)))


def fetch_page(page):
    pairs = [("action", "jet_engine_ajax"), ("handler", "listing_load_more")]
    flatten("query", QUERY, pairs)
    flatten("widget_settings", WIDGET_SETTINGS, pairs)
    pairs += [
        ("page_settings[post_id]", "0"),
        ("page_settings[queried_id]", "0"),
        ("page_settings[element_id]", "f6b2a9b"),
        ("page_settings[page]", str(page)),
        ("listing_type", ""),
        ("isEditMode", "false"),
    ]
    body = urllib.parse.urlencode(pairs).encode()
    req = urllib.request.Request(AJAX_URL, data=body, headers={
        "User-Agent": ea.UA,
        "Accept-Language": "de-AT,de;q=0.9,en;q=0.8",
        "X-Requested-With": "XMLHttpRequest",
        "Content-Type": "application/x-www-form-urlencoded",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        raw = r.read().decode("utf-8", "replace")
    import json
    return json.loads(raw)


def ddmmyyyy_to_iso(s):
    m = re.match(r"(\d{1,2})\.(\d{1,2})\.(\d{4})", s)
    if not m:
        return None
    d, mo, y = m.groups()
    return f"{int(y):04d}-{int(mo):02d}-{int(d):02d}"


def main():
    cutoff = ea.horizon()
    today = datetime.date.today()
    out = []
    seen = set()
    for page in range(1, 41):
        try:
            resp = fetch_page(page)
        except Exception as e:
            sys.stderr.write(f"page {page} fetch failed: {e}\n")
            break
        html_chunk = (resp or {}).get("data", {}).get("html", "")
        items = ITEM_RE.findall(html_chunk)
        if not items:
            break
        chunks = re.split(r'jet-listing-grid__item jet-listing-dynamic-post-\d+', html_chunk)[1:]
        for (post_id, url), chunk in zip(items, chunks):
            if post_id in seen:
                continue
            seen.add(post_id)
            tm = TITLE_RE.search(chunk)
            title = ea.text(tm.group(1)) if tm else None
            if not title:
                continue
            dates = DATE_RE.findall(chunk)
            if not dates:
                continue
            start = ddmmyyyy_to_iso(dates[0])
            end = ddmmyyyy_to_iso(dates[1]) if len(dates) > 1 else None
            if not start:
                continue
            try:
                start_date = datetime.date.fromisoformat(start)
            except ValueError:
                continue
            if start_date < today:
                continue
            if start_date > cutoff:
                continue

            out.append({
                "source": "marxhalle",
                "source_id": post_id,
                "url": url,
                "title": title,
                "start": start,
                "end": end,
                "venue": VENUE,
                "district": DISTRICT,
                "city": "Wien",
                "address": ADDRESS,
                "price_min": None,
                "price_text": None,
                "category": None,
                "description": None,
                "status": "scheduled",
            })
    ea.emit(out)


if __name__ == "__main__":
    main()
