"""Pick a drill round: up to 5 mastered + a 30-word new/review slice.

Usage:
    python3 pick.py [--new N] [--review R] [--master M]

--new N     force N brand-new words into the review slice (default 0)
--review R  size of the new/review slice (default 30)
--master M  max mastered words on top (default 5)

The review slice is always filled to R: tracked `new` words first (priority order),
then brand-new words from new.md pad any shortfall (i.e. when fewer than R are
tracked). Round size = mastered taken + R, so it grows from 30 toward 35 as you
accumulate mastered words.

Prints a paste-ready block: a counts line and the words as a 5-column markdown
table (blue code spans, column-major numbering).
Priority within a pool: most overdue first, then most-negative streak (leeches),
then most-seen. Brand-new words are taken easiest-first from new.md (ease-sorted).
"""
import argparse
import random

from lib import load, read_wordlist, NEW_MD


def prio(w):
    # ascending sort: earlier due first, lower (more negative) streak first, more seen first
    return (w["due"], w["streak"], -w["seen"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--new", type=int, default=0)
    ap.add_argument("--review", type=int, default=30)
    ap.add_argument("--master", type=int, default=5)
    args = ap.parse_args()

    data = load()
    review_pool = data["new"]
    mastered_pool = data["mastered"]
    tracked = {w["word"] for w in review_pool} | {w["word"] for w in mastered_pool}

    take_master = sorted(mastered_pool, key=prio)[: args.master]

    n_review = max(0, args.review - args.new)
    take_review = sorted(review_pool, key=prio)[:n_review]

    # fill the review slice up to --review with brand-new words when the tracked
    # `new` pool is short (fewer than --review), plus any forced via --new.
    need_new = args.review - len(take_review)
    brand = []
    if need_new > 0:
        for w in read_wordlist(NEW_MD):
            if w not in tracked and w not in brand:
                brand.append(w)
                if len(brand) == need_new:
                    break

    selected = [w["word"] for w in take_master] + [w["word"] for w in take_review] + brand

    random.shuffle(selected)

    counts = []
    if take_master:
        counts.append(f"{len(take_master)} mastered")
    if take_review:
        counts.append(f"{len(take_review)} review")
    if brand:
        counts.append(f"{len(brand)} new")

    cols = 5
    n = len(selected)
    rows = (n + cols - 1) // cols  # column-major: indices increase down each column

    def cell(r, c):
        i = c * rows + r
        return f"{i + 1}. `{selected[i]}`" if i < n else ""

    def fmt(r):
        return "| " + " | ".join(cell(r, c) for c in range(cols)) + " |"

    print(f"_{' · '.join(counts)}_ — pinyin + translation for each:\n")
    print(fmt(0))                 # first data row doubles as the table header (no empty row)
    print("|" + "---|" * cols)
    for r in range(1, rows):
        print(fmt(r))


if __name__ == "__main__":
    main()
