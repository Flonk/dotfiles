"""Pick a drill round: up to 5 mastered + a 15-word sample from a 30-word review pool.

Usage:
    python3 pick.py [--new N] [--pool P] [--round R] [--master M]

--new N     force N brand-new words into the review pool (default 0)
--pool P    floor for the tracked review pool (default 30)
--round R   how many review words to actually present this round (default 15)
--master M  max mastered words on top (default 5)

The review pool is kept filled to P: tracked `new` words first (priority order),
then brand-new words from new.md pad any shortfall (i.e. when fewer than P are
tracked) — this is what keeps at least P words in rotation over time. Each round
then samples R words from that pool at random, so untracked pad-in words still get
a chance to be drilled (and graduate into the tracked pool) even once P is reached.

Prints a paste-ready block: a counts line and the words as a 5-column markdown
table (blue code spans, column-major numbering).
Priority within the pool: most overdue first, then most-negative streak (leeches),
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
    ap.add_argument("--pool", type=int, default=30)
    ap.add_argument("--round", type=int, default=15)
    ap.add_argument("--master", type=int, default=5)
    args = ap.parse_args()

    data = load()
    review_pool = data["new"]
    mastered_pool = data["mastered"]
    tracked = {w["word"] for w in review_pool} | {w["word"] for w in mastered_pool}

    take_master = sorted(mastered_pool, key=prio)[: args.master]

    n_review = max(0, args.pool - args.new)
    take_review = sorted(review_pool, key=prio)[:n_review]

    # fill the review pool up to --pool with brand-new words when the tracked
    # `new` pool is short (fewer than --pool), plus any forced via --new.
    need_new = args.pool - len(take_review)
    brand = []
    if need_new > 0:
        for w in read_wordlist(NEW_MD):
            if w not in tracked and w not in brand:
                brand.append(w)
                if len(brand) == need_new:
                    break

    review_words = [w["word"] for w in take_review] + brand
    random.shuffle(review_words)
    round_review = review_words[: args.round]
    round_brand = [w for w in round_review if w in brand]
    round_tracked = [w for w in round_review if w not in brand]

    selected = [w["word"] for w in take_master] + round_review

    random.shuffle(selected)

    counts = []
    if take_master:
        counts.append(f"{len(take_master)} mastered")
    if round_tracked:
        counts.append(f"{len(round_tracked)} review")
    if round_brand:
        counts.append(f"{len(round_brand)} new")

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
