# gloxwald

Standalone home for the custom quickshell setup extracted from `personal/dotfiles`.

## Layout

- `shell/` contains the full quickshell config tree.
- `shell/Theme.qml` is a checked-in fallback theme that matches the current live setup.
- `flake.nix` provides `nix run` and `nix develop` entrypoints for local iteration.
- `scripts/` contains the hot-reload development workflow.
- `justfile` exposes the common dev commands.

## Usage

Run the shell directly from the repo:

```bash
nix run .
```

Open a development environment with the expected runtime tools on `PATH`:

```bash
nix develop
quickshell --path ./shell
```

If you prefer plain `nix-shell`, this repo also ships a standalone `shell.nix` with the same dev dependencies:

```bash
nix-shell
just dev
```

For the live-reload workflow that bootstraps from the Nix-managed `~/.config/quickshell` and syncs edits back into this repo:

```bash
just dev
```

## Dotfiles integration

The dotfiles repo should treat this repository as the source of truth for QML and assets. It can still regenerate `Theme.qml` from Stylix and overwrite the fallback file at build time.

## Notes

- The app launcher still expects `vicinae` to be available on the host.
- Runtime integrations such as `nmcli`, `bluetoothctl`, `wpctl`, `wl-copy`, and `notify-send` are included in the Nix wrapper where possible, but they still depend on host services being present.
