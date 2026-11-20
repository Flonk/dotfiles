{
  config,
  lib,
  ...
}:
let
  g = config.programs.t3-desktop;
  hex = lib.removePrefix "#" g.stylix.accent;
  channel = i: toString (lib.fromHexString (builtins.substring i 2 hex));
  accent = "38;2;${channel 0};${channel 2};${channel 4}";
in
{
  config = lib.mkIf (g.fastfetch.enable && config.programs.fastfetch.enable) {
    programs.fastfetch.settings = {
      logo = lib.mkForce {
        type = "file";
        source = "${../../ascii.txt}";
        color."1" = accent;
        padding = {
          top = 1;
          left = 2;
          right = 3;
        };
      };
      display.color = {
        keys = accent;
        title = accent;
      };
    };
  };
}
