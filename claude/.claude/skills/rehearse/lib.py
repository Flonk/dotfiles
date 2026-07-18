"""Shared helpers for the rehearse skill scripts."""
import json
import re
from pathlib import Path

DOCS = Path(__file__).resolve().parents[4] / "obsidian/Vault/claude/chinese"
JSON_PATH = DOCS / "rehearsal.json"
NEW_MD = DOCS / "new.md"
OLD_MD = DOCS / "old.md"

SEP = "，"
_SPLIT = re.compile(r"[，,、]")


def _is_cjk(ch):
    return "一" <= ch <= "鿿"


def load():
    return json.loads(JSON_PATH.read_text(encoding="utf-8"))


def save(data):
    JSON_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def _find_wordline(lines):
    """Index of the single data line (only CJK + separators), or None."""
    for i, line in enumerate(lines):
        s = line.strip()
        if s and any(_is_cjk(c) for c in s) and all(
            _is_cjk(c) or c in "，,、 " for c in s
        ):
            return i
    return None


def read_wordlist(path):
    lines = path.read_text(encoding="utf-8").split("\n")
    i = _find_wordline(lines)
    if i is None:
        return []
    return [w for w in _SPLIT.split(lines[i].strip()) if w]


def edit_wordlist(path, fn):
    """Apply fn(list)->list to the data line, creating it if absent."""
    lines = path.read_text(encoding="utf-8").split("\n")
    i = _find_wordline(lines)
    if i is None:
        words = fn([])
        while lines and lines[-1].strip() == "":
            lines.pop()
        lines += ["", SEP.join(words)]
    else:
        lines[i] = SEP.join(fn(read_wordlist(path)))
    path.write_text("\n".join(lines), encoding="utf-8")
