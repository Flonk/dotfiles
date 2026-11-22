{
  pkgs,
  config,
  lib,
  ...
}:
let
  obScript = pkgs.writeShellScriptBin "ob" ''
    export PATH="${pkgs.nodejs_22}/bin:$PATH"
    exec ${pkgs.nodejs_22}/bin/npx --yes obsidian-headless "$@"
  '';
  cfg = config.t3os.module.development.obsidian;
in
{
  config = lib.mkIf cfg.enable {
    home.packages =
      [ obScript ]
      ++ lib.optionals cfg.ui.enable [ pkgs.obsidian ];

    stylix.targets.obsidian.enable = lib.mkIf cfg.ui.enable true;
    stylix.targets.obsidian.vaultNames = lib.mkIf (cfg.ui.enable && config.t3os.module.desktop.stylix.enable) [
      "Vault"
    ];
  };
}
