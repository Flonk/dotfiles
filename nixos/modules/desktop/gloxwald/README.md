# gloxwald

A complete Hyprland desktop: hyprland + hy3, quickshell bar and lockscreen, vicinae launcher, mako notifications, fcitx5 input-method switching, stylix theming, a greetd greeter, and a matching GRUB theme.

## Layout

- `src/greeter/` — `gloxwaldgreet`, a Bubble Tea terminal greeter for greetd (Go)
- `src/grub/` — GRUB theme asset generator and QEMU preview
- `src/hyprland/` — hyprland session config, keybindings, styling
- `src/i18n/` — fcitx5 input-method switching (`gloxwald-i18n` CLI + MOD3+I cycle)
- `src/mako/` — notification daemon
- `src/quickshell/` — bar and lockscreen (QML)
- `src/vicinae/` — launcher service and binds
- `gloxwald-options.nix` — every `programs.gloxwald.*` option and its default
- `stylix.nix` — stylix theming for the session
- `home.nix` / `system.nix` — entry points importing the above; they also map `skynet.module.desktop.gloxwald.enable` onto `programs.gloxwald.*`
- `packages.nix` — the `gloxwald` and `greeter` packages, exposed as `packages.x86_64-linux` of the nixos flake

## Wiring

`home.nix` and `system.nix` are imported from `nixos/flake.nix` (right after the stylix modules), not from `config/{users,hosts}/common.nix`: hyprland settings and window rules merge in module order, so keeping this position keeps their order stable.

All options live in `gloxwald-options.nix`; vicinae, mako, and stylix theming default to on with the hyprland session, i18n is opt-in.

## Development

```bash
just dev [tab]     # unified dev window: bar, lock, greeter, grub tabs (tab = desktop|bar|lock|greeter|grub)
nix-shell          # dev shell with quickshell, go, grub tooling (or direnv)
just qs-run        # run the quickshell bar from the repo
just qs-dev        # hot-reload QML on save
just greet-dev     # run the greeter in test mode (no auth)
just grub-dev      # preview the GRUB theme in QEMU
just shader-dev    # live-iterate a lockscreen shader
```

### `just dev`

One window (desktop, bar, lock, greeter and grub tabs): a sidebar (tabs, frame resolution, theme (`.dev/theme.json`, seeded from the installed `quickshell-theme.json`), reload actions, the current tab's own controls, and the log) next to the stage.

- **desktop**: the whole screen at the frame resolution, chrome, live header and mock windows
- **bar**: the real `BarContent`
- **lock**: the real `LockSurface` with the shader dev panel; auth is faked, `gloxwald` unlocks, anything else fails
- **greeter**: `gloxwaldgreet --test` in a hidden tmux (`dev/greeter.sh`), mirrored and fed keys
- **grub**: a BIOS ISO built from `generate-assets.sh` booted in headless QEMU (`dev/grub.sh`), mirrored via QMP screendumps and fed keys

Shader, greeter and GRUB sources are watched and rebuilt automatically; build output lands in the log pane. Click a pane to give it keyboard focus.

Keys: `Ctrl+1..5` tabs, `Ctrl+R` reload tab, `Ctrl+Shift+R` reload all, `Ctrl+F` fit/1:1, `Ctrl+L` log, `Ctrl+D` dock left/bottom. Desktop tab: `Ctrl`+scroll or pinch to zoom, scroll or drag to pan, double-click or `Ctrl+0` to fit, `Ctrl+=`/`Ctrl+-` to step.

IPC: `quickshell ipc --path src/quickshell/shell/dev.qml call dev state` (also `tab <name>`, `dock left|bottom`, `zoom <z>` with 0 = fit, `reload`).
