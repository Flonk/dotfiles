{
  pkgs,
  config,
  lib,
  ...
}:
let
  open-bitwarden = pkgs.writeShellApplication {
    name = "open-bitwarden";
    runtimeInputs = with pkgs; [ wl-clipboard ];
    text = ''
      command="''${1:-search}"
      link="vicinae://launch/@flo/vicinae-bitwarden/$command"

      if hyprctl activewindow -j | grep -qE '"class"[[:space:]]*:[[:space:]]*"org\.qutebrowser\.qutebrowser"'; then
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
  config =
    lib.mkIf (config.t3os.module.desktop.vicinae.enable && config.programs.t3-desktop.hyprland.enable)
      {
        home.packages = [ open-bitwarden ];

        wayland.windowManager.hyprland.extraConfig = ''
          hl.bind("MOD3 + B", hl.dsp.exec_cmd("xdg-open vicinae://launch/@Gelei/store.vicinae.bluetooth/devices"))
          hl.bind("MOD3 + P", hl.dsp.exec_cmd("open-bitwarden"))
          hl.bind("MOD3 + A", hl.dsp.exec_cmd("open-bitwarden autofill"))
        '';
      };
}
