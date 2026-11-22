## Modules

When adding a new module:

1. Create module folder at `nixos/modules/$MODULE/` with:
   - `options.nix` defining `options.t3os.module.$MODULE.enable` (and any extra options)
   - `home.nix` for home-manager and/or `system.nix` for system config
2. Add the `options.nix` import to `nixos/types/t3os-modules.nix`
3. Add a guard to the module like `lib.mkIf config.t3os.module.$MODULE.enable`
4. Add `home.nix` import to `nixos/config/users/common.nix` and/or `system.nix` import to `nixos/config/hosts/common.nix`
   - Exception: `desktop/t3-desktop` is imported from `nixos/flake.nix` right after stylix, to keep hyprland settings/window-rule merge order stable
5. Enable the module in `$USER-userconfig.nix` or `$HOST-hostconfig.nix`
6. If the module handles specific file types/URI schemes, set `xdg.mimeApps.defaultApplications` in its `home.nix`

## Host Config Files

Each host has two files with distinct roles — never mix them:

- `nixos/config/hosts/$HOST/default.nix` — NixOS system options (`programs.*`, `services.*`, `security.*`, etc.)
- `nixos/config/hosts/$HOST/$HOST-hostconfig.nix` — **only** `config.t3os.*` values (whoami, host metadata, module enable flags)

## T3 OS Scripts

`nixos/modules/t3os-scripts/home.nix` is intentionally always imported (not gated behind `t3os.module.*.enable`).

To register a new T3 OS CLI script, add to the module's `home.nix`:

```nix
t3os.cli.scripts = [{
  command = [ "category" "action" ];  # becomes `t3os category action`
  title = "Human-readable title";     # shown in fzf list
  script = ./path-to-script.sh;       # .sh or a derivation bin path
  usage = "Description shown in preview pane below ASCII art";
}];
```

- For sub-fzf scripts (like sops), use `config.t3os.cli.fzfThemeArgs` for consistent styling

## T3 OS Updaters

Modules that pin versions by hand (fetchurl + hash) register an updater so `t3os upgrade` bumps them after `nix flake update`:

```nix
t3os.cli.updaters = [{
  name = "artcraft";
  script = pkgs.writeShellScript "artcraft-update.sh" ''...'';
}];
```

- The script runs with `T3OS_REPO` set to the dotfiles checkout and edits pinned data in place (e.g. a `versions.json` next to the module, read via `lib.importJSON`)
- See `nixos/modules/leisure/artcraft/` for the reference implementation
