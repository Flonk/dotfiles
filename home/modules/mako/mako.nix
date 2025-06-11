{
  pkgs,
  config,
  lib,
  ...
}: let
  theme = import ../themes/trump.nix;
in {
  
  # mako notification daemon
  services.mako = {
    enable = true;
    settings = {
      actions = true;
      anchor = "top-right";
      border-radius = 0;
      border-size = 2;
      font = "monospace 9";
      default-timeout = 10000;
      layer = "overlay";
      max-visible = 3;
      padding = "10";
      width = 340;
      height = 300;
      border-color = "#ffa200";
      background-color = "#000000";
    };
  };
  
}
