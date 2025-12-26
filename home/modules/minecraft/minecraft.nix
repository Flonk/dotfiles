{
  pkgs,
  config,
  lib,
  ...
}:
{

  home.packages = with pkgs; [
    prismlauncher
    # Fabric installer for Minecraft modding
    (pkgs.writeShellScriptBin "fabric-installer" ''
      exec ${pkgs.jre}/bin/java -jar ${pkgs.fetchurl {
        url = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.1/fabric-installer-1.1.1.jar";
        sha256 = "0y8vwcp1sn0dh77nn3k2vhpbcsn2fwni99v5a9hc5ngrssfsd1r4";
      }} "$@"
    '')
  ];

}
