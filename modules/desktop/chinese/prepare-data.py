import json
import os
import sys

dictionary_path, graphics_path, out = sys.argv[1:4]
os.makedirs(os.path.join(out, "strokes"))

entries = {}
with open(dictionary_path, encoding="utf-8") as f:
    for line in f:
        e = json.loads(line)
        if e.get("definition") or e.get("pinyin"):
            entries[e["character"]] = {
                "d": e.get("definition", ""),
                "p": e.get("pinyin", []),
            }

with open(os.path.join(out, "dictionary.json"), "w", encoding="utf-8") as f:
    json.dump(entries, f, ensure_ascii=False, separators=(",", ":"))

with open(graphics_path, encoding="utf-8") as f:
    for line in f:
        e = json.loads(line)
        codepoint = format(ord(e["character"]), "x")
        with open(os.path.join(out, "strokes", codepoint + ".json"), "w") as g:
            json.dump({"s": e["strokes"], "m": e["medians"]}, g, separators=(",", ":"))
