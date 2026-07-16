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
      link="vicinae://launch/@flo/vicinae-bitwarden/search"

      # Only prefill from the active tab if qutebrowser is the focused window
      if hyprctl activewindow -j | grep -qE '"class"[[:space:]]*:[[:space:]]*"org\.qutebrowser\.qutebrowser"'; then
        # Yank current URL from qutebrowser and extract hostname for prefill
        old_clip=$(wl-paste 2>/dev/null || true)
        qutebrowser ':yank'
        url=$(wl-paste 2>/dev/null || true)
        if [ -n "$old_clip" ]; then
          printf '%s' "$old_clip" | wl-copy
        fi

        if [ -n "$url" ]; then
          host="''${url#*://}"
          host="''${host%%/*}"
          host="''${host%%\?*}"
          host="''${host%%#*}"
          if [ -n "$host" ]; then
            link="$link?arguments={\"query\":\"$host\"}"
          fi
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

      (lib.mkIf config.programs.gloxwald.hyprland.enable {
        home.packages = [ open-bitwarden ];
        wayland.windowManager.hyprland.settings.layer_rule = [
          { match.namespace = "vicinae"; dim_around = true; }
        ];
        wayland.windowManager.hyprland.extraConfig = ''
          hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("vicinae open"))
          hl.bind("MOD3 + period", hl.dsp.exec_cmd("xdg-open vicinae://launch/core/search-emojis"))
          hl.bind("MOD3 + B", hl.dsp.exec_cmd("xdg-open vicinae://launch/@Gelei/store.vicinae.bluetooth/devices"))
          hl.bind("MOD3 + P", hl.dsp.exec_cmd("open-bitwarden"))
          hl.bind("MOD3 + T", hl.dsp.exec_cmd("xdg-open vicinae://launch/@gebeto/store.raycast.translate/quick-translate"))
        '';
      })
    ]
  );
}
