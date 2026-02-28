Prefix each message with 🧠.

## Modules

When adding a new module:

1. Add new option to `config/types/skynet.nix` (use `skynet.module.$MODULE.enable`)
2. Add a guard to the module like `lib.mkIf config.skynet.module.$MODULE.enable`
3. Add module to `nixos/hosts/common.nix` or `home/users/common.nix` depending on
   whether it's a home manager module or nixos systemwide config.
4. Enable the module in `$USER-userconfig.nix` or `$HOST-hostconfig.nix`
5. If the module exposes standard applications for mime apps, also edit the `home/modules/mimeApps` module
