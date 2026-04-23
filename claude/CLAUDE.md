# CLAUDE.md

- User: Flo, Vienna, Austria
- OS: **NixOS** — use `nix-shell -p <package>` for tools not on PATH. **Never run `python3` or `node` directly.**
- Obsidian vault: `/home/flo/Documents/Vault` — CLI: `obsidian`. **Always use a subcommand** (e.g. `obsidian help`, not bare `obsidian`). **Do NOT touch `personal/z/`.** **There is no `obsidian edit` command** — to edit vault files, use the `Read` + `Edit` tools directly on the file path (e.g. `/home/flo/Documents/Vault/claude/gold/projects.md`).
- You have a knowledge base in the Obsidian vault under `claude/`. Run `obsidian read path="claude/README.md"` to understand how it works. The short version: important stuff lives in `claude/gold/`, and you can find things with `obsidian search query="tag:#claude/gold"` or any other tag/keyword search.
- Slash commands live in `.claude/commands/` in this repo.
- **Projects** — if the conversation is about one of these, read the gold file before responding. Check #claude/gold for a list. Current projects: fitness, user, academy-singers-2026, paris-bikepacking, rio-2026
- **Small projects & ideas** — `claude/gold/projects.md` is a catch-all for things that don't warrant their own file. Check it when a topic comes up that you don't recognise.
