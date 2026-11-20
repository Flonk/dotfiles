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
nix-shell          # dev shell with quickshell, go, grub tooling (or direnv)
just qs-run        # run the quickshell bar from the repo
just qs-dev        # hot-reload QML on save
just greet-dev     # run the greeter in test mode (no auth)
just grub-dev      # preview the GRUB theme in QEMU
just shader-dev    # live-iterate a lockscreen shader
```
