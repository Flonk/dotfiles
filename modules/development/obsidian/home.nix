{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development.obsidian.enable {
    home.packages = with pkgs; [ obsidian ];

    stylix.targets.obsidian.enable = true;
    stylix.targets.obsidian.vaultNames = lib.mkIf config.skynet.module.desktop.stylix.enable [
      "Vault"
    ];
  };
}
