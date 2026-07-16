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
- `modules/options.nix` — every `programs.gloxwald.*` option and its default
- `modules/{home-manager,nixos}.nix` — entry points importing the above

## Consuming

NixOS side (greeter, GRUB theme, portals):

```nix
imports = [ gloxwald.nixosModules.default ];
programs.gloxwald.greeter = { enable = true; settings.exec = "start-hyprland"; };
programs.gloxwald.grub.enable = true;
```

Home-manager side:

```nix
imports = [ gloxwald.homeManagerModules.default ];
programs.gloxwald.hyprland.enable = true;
programs.gloxwald.quickshell.enable = true;
```

`homeManagerModules.default` bundles the stylix and vicinae home-manager modules gloxwald depends on. If you pin those flakes yourself, import `homeManagerModules.gloxwald` instead and add their modules alongside.

All options live in `modules/options.nix`; vicinae, mako, and stylix theming default to on with the hyprland session, i18n is opt-in.

## Development

```bash
nix develop        # dev shell with quickshell, go, grub tooling
just qs-run        # run the quickshell bar from the repo
just qs-dev        # hot-reload QML on save
just greet-dev     # run the greeter in test mode (no auth)
just grub-dev      # preview the GRUB theme in QEMU
just shader-dev    # live-iterate a lockscreen shader
```
