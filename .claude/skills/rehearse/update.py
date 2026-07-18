"""Record drill results. Plug in word + correct/wrong; it figures out the rest.

Usage:
    python3 update.py 书:1 大:0 会:t 手:f ...

Each token is `word:result`. Result truthy: 1 t true y yes + c correct.
Result falsy:  0 f false n no - x wrong.

Applies the signed-streak rules, updates rehearsal.json, and syncs new.md/old.md
on graduation (streak>=5) or demotion (missed a mastered word). Prints a summary.
"""
import sys
from datetime import date, timedelta

from lib import load, save, edit_wordlist, NEW_MD, OLD_MD

TRUE = {"1", "t", "true", "y", "yes", "+", "c", "correct"}
FALSE = {"0", "f", "false", "n", "no", "-", "x", "wrong"}
INTERVAL = {1: 1, 2: 2, 3: 4, 4: 7}  # positive streak -> days until due
MASTER_INTERVAL = 15
GRADUATE_AT = 5

TODAY = date.today()
TOMORROW = TODAY + timedelta(days=1)


def due_for(streak):
    if streak >= GRADUATE_AT:
        return TODAY + timedelta(days=MASTER_INTERVAL)
    if streak >= 1:
        return TODAY + timedelta(days=INTERVAL.get(streak, 7))
    return TOMORROW


def parse_result(tok):
    v = tok.strip().lower()
    if v in TRUE:
        return True
    if v in FALSE:
        return False
    raise SystemExit(f"unrecognized result: {tok!r}")


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: update.py word:result [word:result ...]")

    data = load()
    review = data["new"]
    mastered = data["mastered"]
    by_word = {w["word"]: ("new", w) for w in review}
    by_word.update({w["word"]: ("old", w) for w in mastered})

    log = []
    for tok in sys.argv[1:]:
        if ":" not in tok:
            raise SystemExit(f"bad token (need word:result): {tok!r}")
        word, res = tok.split(":", 1)
        word = word.strip()
        correct = parse_result(res)
        where = by_word.get(word)

        if where is None:  # brand-new, first drill
            streak = 1 if correct else -1
            entry = {
                "word": word, "seen": 1, "streak": streak,
                "last": TODAY.isoformat(), "due": due_for(streak).isoformat(),
            }
            review.append(entry)
            by_word[word] = ("new", entry)
            log.append(f"{word}  NEW  streak {streak:+d}  {'✓' if correct else '✗'}")
            continue

        loc, e = where
        e["seen"] += 1
        e["last"] = TODAY.isoformat()

        if loc == "old":  # mastered word
            if correct:
                e["due"] = (TODAY + timedelta(days=MASTER_INTERVAL)).isoformat()
                log.append(f"{word}  mastered  ✓  (retention held)")
            else:  # demote
                e["streak"] = -1
                e["due"] = TOMORROW.isoformat()
                mastered.remove(e)
                review.append(e)
                by_word[word] = ("new", e)
                edit_wordlist(OLD_MD, lambda ws: [w for w in ws if w != word])
                edit_wordlist(NEW_MD, lambda ws: ws if word in ws else ws + [word])
                log.append(f"{word}  DEMOTED  ✗  mastered -> new")
            continue

        # loc == "new"
        prev = e["streak"]
        if correct:
            e["streak"] = prev + 1 if prev >= 0 else 1
        else:
            e["streak"] = prev - 1 if prev <= 0 else -1

        if correct and e["streak"] >= GRADUATE_AT:  # graduate
            e["due"] = due_for(e["streak"]).isoformat()
            review.remove(e)
            mastered.append(e)
            by_word[word] = ("old", e)
            edit_wordlist(NEW_MD, lambda ws: [w for w in ws if w != word])
            edit_wordlist(OLD_MD, lambda ws: ws if word in ws else ws + [word])
            log.append(f"{word}  GRADUATED  ✓  streak {e['streak']}  new -> mastered")
        else:
            e["due"] = due_for(e["streak"]).isoformat() if correct else TOMORROW.isoformat()
            log.append(f"{word}  streak {e['streak']:+d}  {'✓' if correct else '✗'}")

    save(data)
    print("\n".join(log))
    print(f"\ntracked: {len(review)} new, {len(mastered)} mastered")


if __name__ == "__main__":
    main()
