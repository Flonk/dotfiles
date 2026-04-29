{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.skynet.module.os.greetd = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    greeter = mkOption {
      type = types.enum [
        "custom"
        "tuigreet"
        "none"
      ];
      default = "custom";
      description = "Which greeter to use: 'custom' (pygame-based matching GRUB theme), 'tuigreet' (TUI-based), or 'none' (auto-login, relies on hyprlock for security)";
    };
  };
}
