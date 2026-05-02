# CLAUDE.md

- User: Flo, Vienna, Austria
- Units: metric, Celsius. Numbers: space as thousands separator, period as decimal (e.g. 1 234.5). Week starts on Monday.
- OS: **NixOS** — use `nix-shell -p <package>` for tools not on PATH. **Never run `python3` or `node` directly.**
- This repo is a **Nix flake** (`/home/flo/repos/personal/dotfiles`). This `claude/` subdirectory lives inside it. See `../AGENTS.md` for repo-wide instructions.
- Obsidian vault: `/home/flo/repos/personal/dotfiles/obsidian/Vault` — CLI: `obsidian`. **Always use a subcommand** (e.g. `obsidian help`, not bare `obsidian`). **Do NOT touch `personal/z/`.** **There is no `obsidian edit` command** — to edit vault files, use the `Read` + `Edit` tools directly on the file path (e.g. `/home/flo/repos/personal/dotfiles/obsidian/Vault/claude/projects.md`).
- You have a knowledge base in the Obsidian vault under `claude/`. Run `obsidian read path="claude/README.md"` to understand how it works. Files live flat in `claude/` — find things with `obsidian search query="tag:#claude"` or any keyword search.
- Slash commands live in `.claude/commands/` in this repo.
- **Projects** — if the conversation is about one of these, read the relevant file before responding. Current projects: fitness, user, academy-singers-2026, paris-bikepacking, rio-2026
- **Small projects & ideas** — `claude/projects.md` is a catch-all for things that don't warrant their own file. Check it when a topic comes up that you don't recognise.
