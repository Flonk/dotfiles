{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop.chinese;

  makemeahanziRev = "bddc96d41bef78427ed0e034e9f7e31d71fd1b92";
  dictionary = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/skishore/makemeahanzi/${makemeahanziRev}/dictionary.txt";
    hash = "sha256-dEuwXVsHQunuNcN3kflNVqFzNJszZ1aefKEeUQNk0gM=";
  };
  graphics = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/skishore/makemeahanzi/${makemeahanziRev}/graphics.txt";
    hash = "sha256-ooxHi1F46Y9n9RCy1S/eCKadxmRlTvQ0mCU7m3ZNRu4=";
  };
  data = pkgs.runCommand "skynet-chinese-data" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./prepare-data.py} ${dictionary} ${graphics} $out
  '';

  extension = inputs.vicinae.lib.${pkgs.stdenv.hostPlatform.system}.mkVicinaeExtension {
    name = "vicinae-chinese";
    version = "0.1.0";
    src = ./extension;
  };
in
{
  config = lib.mkIf cfg.enable {
    xdg.dataFile."skynet-chinese".source = data;
    programs.vicinae.extensions = [ extension ];
  };
}
