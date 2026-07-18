---
name: rehearse-sentence
description: Follow-up to the rehearse skill — builds 3 untracked translation sentences from Flo's current tracked Chinese vocab pool and asks him to translate them. Use right after a `rehearse` drill finishes recording, or whenever Flo asks for practice sentences from his tracked words.
---

# rehearse-sentence

A short untracked exercise: 3 sentences built only from words Flo already has
tracked, for translation practice. No grading, no bookkeeping.

**Suppress the normal Chinese output mode entirely** while this runs — no swapping
words into Chinese, no new-words gloss list, no appended footer. This skill's output
format replaces it.

## Build the sentences

Read `obsidian/Vault/claude/chinese/rehearsal.json` and build exactly **3 sentences** using **only**
tracked words (the `word`s in the `new` + `mastered` arrays). Prefer words touched in
the most recent drill if you have that context. Keep sentences short if the known
vocabulary is thin, and lean on English for anything not in the tracked pool — but
keep that to a minimum.

## Present & translate

Ask Flo to translate each sentence. **Do not** grade or record these — when he
answers, just give the intended meaning.

## Colour format

Match the `rehearse` skill's format:
- **Blue Chinese** — inline code span: `` `你好` ``
- **Bold white pinyin** — `**nǐ hǎo**`

Example: `` `我们喝茶` `` **wǒmen hē chá**
