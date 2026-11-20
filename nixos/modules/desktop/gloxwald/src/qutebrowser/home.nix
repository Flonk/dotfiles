{
  config,
  lib,
  pkgs,
  ...
}:
let
  g = config.programs.gloxwald;
  s = config.lib.stylix.colors.withHashtag;
  gloxwaldPkgs = import ../../packages.nix {
    inherit pkgs;
    accent = g.stylix.accent;
  };
  palette = builtins.fromJSON (builtins.readFile "${gloxwaldPkgs.chrome}/palette.json");

  channels = hex: map (i: lib.fromHexString (builtins.substring i 2 (lib.removePrefix "#" hex))) [ 0 2 4 ];
  toHex = cs: "#" + lib.concatMapStrings (c: lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString c))) cs;
  mix = a: b: t: toHex (lib.zipListsWith (x: y: builtins.floor (x + (y - x) * t + 0.5)) (channels a) (channels b));

  ink = "#000000";
  cream = "#ddd6c4";
  ground = g.stylix.ground;
  accent = g.stylix.accent;
  accent2 = palette.accent2;
  glow = palette.glow;
  deep = mix ink accent 0.14;
  dimAccent = mix ground accent 0.75;
  dimCream = mix ground cream 0.5;
  danger = s.base08;
  warn = s.base0A;

  tab = bg: fg: {
    even = { inherit bg fg; };
    odd = { inherit bg fg; };
  };
in
{
  config = lib.mkIf (g.qutebrowser.enable && config.programs.qutebrowser.enable) {
    stylix.targets.qutebrowser.colors.enable = false;

    programs.qutebrowser.extraConfig = lib.mkAfter ''
      c.tabs.padding = {"top": 5, "bottom": 5, "left": 10, "right": 10}
      c.tabs.indicator.padding = {"top": 0, "bottom": 0, "left": 0, "right": 6}
      c.statusbar.padding = {"top": 4, "bottom": 4, "left": 8, "right": 8}
      c.hints.padding = {"top": 1, "bottom": 1, "left": 4, "right": 4}
    '';

    programs.qutebrowser.settings = {
      fonts = {
        tabs.selected = "bold default_size default_family";
        tabs.unselected = "default_size default_family";
        statusbar = "bold default_size default_family";
        hints = "bold default_size default_family";
        completion.category = "bold default_size default_family";
        prompts = "default_size default_family";
      };

      tabs = {
        indicator.width = 2;
        favicons.scale = 0.9;
        title.alignment = "left";
      };

      hints = { border = "1px solid ${ink}"; radius = 2; };
      prompt.radius = 4;
      completion = { scrollbar.width = 8; scrollbar.padding = 0; };

      colors = {
        webpage.bg = ground;

        tabs = {
          bar.bg = ink;
          indicator = { start = accent2; stop = accent; error = danger; system = "rgb"; };
          selected = tab accent ink;
          pinned = tab deep accent2 // { selected = tab accent2 ink; };
        } // tab deep dimAccent;

        statusbar = {
          normal = { bg = ground; fg = cream; };
          insert = { bg = accent; fg = ink; };
          passthrough = { bg = accent2; fg = ink; };
          private = { bg = deep; fg = cream; };
          command = { bg = ground; fg = cream; private = { bg = deep; fg = cream; }; };
          caret = { bg = glow; fg = ink; selection = { bg = accent2; fg = ink; }; };
          progress.bg = accent;
          url = {
            fg = cream;
            hover.fg = accent2;
            success = { http.fg = dimCream; https.fg = accent; };
            warn.fg = warn;
            error.fg = danger;
          };
        };

        completion = {
          fg = cream;
          odd.bg = ground;
          even.bg = ground;
          category = { bg = accent; fg = ink; border = { top = accent; bottom = accent; }; };
          item.selected = { bg = deep; fg = cream; border = { top = accent; bottom = accent; }; match.fg = accent2; };
          match.fg = accent;
          scrollbar = { bg = ground; fg = dimAccent; };
        };

        hints = { bg = accent; fg = ink; match.fg = cream; };
        keyhint = { bg = ground; fg = cream; suffix.fg = accent; };

        messages = {
          info = { bg = ground; fg = cream; border = accent; };
          warning = { bg = warn; fg = ink; border = warn; };
          error = { bg = danger; fg = ink; border = danger; };
        };

        prompts = { bg = ground; fg = cream; border = "1px solid ${accent}"; selected = { bg = accent; fg = ink; }; };

        downloads = {
          bar.bg = ground;
          start = { bg = accent2; fg = ink; };
          stop = { bg = accent; fg = ink; };
          system = { bg = "rgb"; fg = "rgb"; };
          error = { bg = danger; fg = ink; };
        };

        contextmenu = {
          menu = { bg = ground; fg = cream; };
          selected = { bg = accent; fg = ink; };
          disabled = { bg = ground; fg = dimCream; };
        };

        tooltip = { bg = ground; fg = cream; };
      };
    };
  };
}
