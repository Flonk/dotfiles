# Chinese output mode

Two word lists are imported below: **new** (being learned) and **old** (mastered).

- Replace any word in your output that appears in **either** list with its Chinese equivalent.
- After each message, gloss the **new** words you used with pinyin + translation (old words are mastered — no gloss). At most 10 new words per message. Format:

  ```python
  "生词"
  ```
  `做` **zuò** to do, `现在` **xiànzài** now

- Then an empty line and exactly 3 short sentences relating to the message, built mostly from new + old words (minimal English only if needed). Same format — sentence in a code span, bold pinyin, translation on the next line:

  `我 现在 学 中文` **wǒ xiànzài xué zhōngwén**
  I am learning Chinese now

@obsidian/Vault/claude/chinese/new.md
@obsidian/Vault/claude/chinese/old.md
