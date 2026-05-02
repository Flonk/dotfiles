{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  open-bitwarden = pkgs.writeShellApplication {
    name = "open-bitwarden";
    runtimeInputs = with pkgs; [ wl-clipboard ];
    text = ''
      # Yank current URL from qutebrowser and extract hostname for prefill
      old_clip=$(wl-paste 2>/dev/null || true)
      qutebrowser ':yank'
      url=$(wl-paste 2>/dev/null || true)
      if [ -n "$old_clip" ]; then
        printf '%s' "$old_clip" | wl-copy
      fi

      link="vicinae://extensions/flo/vicinae-bitwarden/search"
      if [ -n "$url" ]; then
        host="''${url#*://}"
        host="''${host%%/*}"
        host="''${host%%\?*}"
        host="''${host%%#*}"
        if [ -n "$host" ]; then
          link="$link?arguments={\"query\":\"$host\"}"
        fi
      fi
      vicinae deeplink "$link"
    '';
  };
in
{
  config = lib.mkIf config.skynet.module.desktop.vicinae.enable (
    lib.mkMerge [
      {
        services.vicinae = {
          enable = true;

          package = pkgs.vicinae;

          systemd = {
            enable = true;
            autoStart = true;
            target = "graphical-session.target";
          };
        };
      }

      (lib.mkIf config.skynet.module.desktop.hyprland.enable {
        home.packages = [ open-bitwarden ];
        wayland.windowManager.hyprland.settings = {
          bind = [
            "$mainMod, SPACE, exec, vicinae open"
            "MOD3, period, exec, xdg-open vicinae://extensions/vicinae/core/search-emojis"
            "MOD3, B, exec, xdg-open vicinae://extensions/Gelei/bluetooth/devices"
            "MOD3, P, exec, open-bitwarden"
          ];
          layerrule = [
            "dim_around on, match:namespace vicinae"
          ];
        };
      })
    ]
  );
}
