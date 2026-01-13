Prefix each message with 🧠.

## Modules

When adding a new module:

1. Add new option to `config/types/skynet.nix`
2. Add a guard to the module like `lib.mkIf config.skynet.module.{home,system}.$MODULE`
3. Add module to `nixos/hosts/common.nix`or `home/users/common.nix` depending on
   whether it's a home manager module or nixos systemwide config.
4. Enable the module in `$USER-userconfig.nix` `$HOST-hostconfig.nix`
