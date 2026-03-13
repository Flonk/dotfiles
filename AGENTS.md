Prefix each message with 🧠.

## Modules

When adding a new module:

1. Add new option to `config/types/skynet-modules.nix` (use `skynet.module.$MODULE.enable`)
2. Create module folder at `modules/$MODULE/` with `home.nix` for home-manager and/or `system.nix` for system config
3. Add a guard to the module like `lib.mkIf config.skynet.module.$MODULE.enable`
4. Add `home.nix` import to `config/users/common.nix` and/or `system.nix` import to `config/hosts/common.nix`
5. Enable the module in `$USER-userconfig.nix` or `$HOST-hostconfig.nix`
6. If the module exposes standard applications for mime apps, also edit the `modules/mimeapps` module

## Skynet Scripts

`modules/skynet-scripts/home.nix` is intentionally always imported (not gated behind `skynet.module.*.enable`).

To register a new skynet CLI script, add to the module's `home.nix`:

```nix
skynet.cli.scripts = [{
  command = [ "category" "action" ];  # becomes `skynet category action`
  title = "Human-readable title";     # shown in fzf list
  script = ./path-to-script.ts;       # .ts or .sh, or a derivation bin path
  usage = "Description shown in preview pane below ASCII art";
}];
```

- For sub-fzf scripts (like sops), use `config.skynet.cli.fzfThemeArgs` for consistent styling
- Script type is `.ts` (run via tsx) or `.sh` (run directly)
