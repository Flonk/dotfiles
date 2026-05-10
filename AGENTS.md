Prefix each message with 🧠.

## Modules

When adding a new module:

1. Create module folder at `modules/$MODULE/` with:
   - `options.nix` defining `options.skynet.module.$MODULE.enable` (and any extra options)
   - `home.nix` for home-manager and/or `system.nix` for system config
2. Add the `options.nix` import to `config/types/skynet-modules.nix`
3. Add a guard to the module like `lib.mkIf config.skynet.module.$MODULE.enable`
4. Add `home.nix` import to `config/users/common.nix` and/or `system.nix` import to `config/hosts/common.nix`
5. Enable the module in `$USER-userconfig.nix` or `$HOST-hostconfig.nix`
6. If the module handles specific file types/URI schemes, set `xdg.mimeApps.defaultApplications` in its `home.nix`

## Skynet Scripts

`modules/skynet-scripts/home.nix` is intentionally always imported (not gated behind `skynet.module.*.enable`).

To register a new skynet CLI script, add to the module's `home.nix`:

```nix
skynet.cli.scripts = [{
  command = [ "category" "action" ];  # becomes `skynet category action`
  title = "Human-readable title";     # shown in fzf list
  script = ./path-to-script.sh;       # .sh or a derivation bin path
  usage = "Description shown in preview pane below ASCII art";
}];
```

- For sub-fzf scripts (like sops), use `config.skynet.cli.fzfThemeArgs` for consistent styling
