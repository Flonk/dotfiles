{
  pkgs,
  config,
  lib,
  theme,
  ...
}:
let
  stripHash = hex: lib.replaceStrings [ "#" ] [ "" ] hex;
  toRgba = hex: "rgba(${stripHash hex}ff)";

  borderColor = toRgba theme.color.accent;
  inactiveBorderColor = toRgba theme.color.background;

  mkKeypadBindings =
    {
      mod,
      action,
      d,
    }:
    let
      keys = [
        {
          key = "KP_Left";
          x = -1;
          y = 0;
        }
        {
          key = "KP_Right";
          x = 1;
          y = 0;
        }
        {
          key = "KP_Up";
          x = 0;
          y = -1;
        }
        {
          key = "KP_Down";
          x = 0;
          y = 1;
        }
        {
          key = "KP_Begin";
          x = 0;
          y = 1;
        }
        {
          key = "KP_Home";
          x = -1;
          y = -1;
        }
        {
          key = "KP_Prior";
          x = 1;
          y = -1;
        }
        {
          key = "KP_End";
          x = -1;
          y = 1;
        }
        {
          key = "KP_Next";
          x = 1;
          y = 1;
        }
      ];
    in
    map (k: "$mainMod ${mod}, ${k.key}, ${action}, ${toString (k.x * d)} ${toString (k.y * d)}") keys;
in
{

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;

    plugins = [ pkgs.hyprlandPlugins.hy3 ];

    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };

    xwayland = {
      enable = true;
    };

    settings = {
      "$terminal" = "alacritty";
      "$fileManager" = "nautilus";
      "$mainMod" = "SUPER";
      "$code" = "vscode";
      "$browser" = "google-chrome-stable";
      "$editor" = "micro";

      exec-once = [
        "waybar"
        "alacritty"
        "google-chrome-stable"
        "hyprctl setcursor macOS-White 28"
      ];

      bind =
        [
          # HYPRLAND
          "$mainMod, RETURN, exec, $terminal"
          "$mainMod CTRL, RETURN, exec, $browser"
          "$mainMod, SPACE, exec, rofi -show drun"

          "$mainMod, L, exec, hyprlock"
          "$mainMod, M, exit"
          "$mainMod, Q, killactive"

          "$mainMod, PRINT, exec, hyprshot -m window -m active"
          "$mainMod SHIFT, PRINT, exec, hyprshot -m output"
          ", PRINT, exec, hyprshot -m region"

          # WINDOW MANAGEMENT
          "$mainMod, A, hy3:changefocus, raise"
          "$mainMod, E, hy3:changegroup, opposite"
          "$mainMod, F, fullscreen"
          "$mainMod SHIFT, F, togglefloating"
          "$mainMod, H, hy3:makegroup, h"
          "$mainMod, W, hy3:changegroup, tab"
          "$mainMod SHIFT, W, hy3:makegroup, tab, toggle"
          "$mainMod, V, hy3:makegroup, v"

          "$mainMod, Tab, focusurgentorlast"

          # MOVE WINDOWS
          "$mainMod, left, hy3:movefocus, l"
          "$mainMod, right, hy3:movefocus, r"
          "$mainMod, up, hy3:movefocus, u"
          "$mainMod, down, hy3:movefocus, d"

          "$mainMod SHIFT, left, hy3:movewindow, l"
          "$mainMod SHIFT, right, hy3:movewindow, r"
          "$mainMod SHIFT, up, hy3:movewindow, u"
          "$mainMod SHIFT, down, hy3:movewindow, d"

          # MOVE BETWEEN WORKSPACES
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"

          "$mainMod CTRL, left, movecurrentworkspacetomonitor, l"
          "$mainMod CTRL, right, movecurrentworkspacetomonitor, r"

          "$mainMod SHIFT, 1, movetoworkspacesilent, 1"
          "$mainMod SHIFT, 2, movetoworkspacesilent, 2"
          "$mainMod SHIFT, 3, movetoworkspacesilent, 3"
          "$mainMod SHIFT, 4, movetoworkspacesilent, 4"
          "$mainMod SHIFT, 5, movetoworkspacesilent, 5"
          "$mainMod SHIFT, 6, movetoworkspacesilent, 6"
          "$mainMod SHIFT, 7, movetoworkspacesilent, 7"
          "$mainMod SHIFT, 8, movetoworkspacesilent, 8"
          "$mainMod SHIFT, 9, movetoworkspacesilent, 9"
          "$mainMod SHIFT, 0, movetoworkspacesilent, 10"

          # RESIZE MODE / MOVE FLOATING
        ]
        ++ (mkKeypadBindings {
          mod = "";
          action = "resizeactive";
          d = 80;
        })
        ++ (mkKeypadBindings {
          mod = "CTRL";
          action = "resizeactive";
          d = 20;
        })
        ++ (mkKeypadBindings {
          mod = "CTRL SHIFT";
          action = "resizeactive";
          d = 5;
        })
        ++ (mkKeypadBindings {
          mod = "ALT";
          action = "moveactive";
          d = 160;
        })
        ++ (mkKeypadBindings {
          mod = "ALT CTRL";
          action = "moveactive";
          d = 40;
        })
        ++ (mkKeypadBindings {
          mod = "ALT CTRL SHIFT";
          action = "moveactive";
          d = 10;
        });

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = [
        "$mainMod, mouse:273, movewindow"
        "$mainMod, mouse:272, resizewindow"
      ];

      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      windowrule = [
        # Ignore maximize requests from apps. You'll probably like this.
        "suppressevent maximize, class:.*"
        "float, title:Bitwarden"
        "float, class:org.pulseaudio.pavucontrol"
        "size >900 >600, class:org.pulseaudio.pavucontrol"
        "noshadow, floating:0"
        "opacity 1 0.92, class:^(Alacritty|code)$"
      ];

      input = {
        kb_layout = "de";
        kb_options = [
          "grp:alt_caps_toggle"
          "caps:super"
        ];
        numlock_by_default = true;
        repeat_delay = 300;
        follow_mouse = 1;
        float_switch_override_focus = 0;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          scroll_factor = 0.8;
        };
      };

      gestures = {
        workspace_swipe = 1;
        workspace_swipe_fingers = 3;
        workspace_swipe_distance = 500;
        workspace_swipe_invert = 1;
        workspace_swipe_min_speed_to_force = 30;
        workspace_swipe_cancel_ratio = 0.5;
        workspace_swipe_create_new = 1;
        workspace_swipe_forever = 1;
      };

      general = {
        "$modifier" = "SUPER";
        layout = "hy3";
        gaps_in = 0;
        gaps_out = 0;
        border_size = 4;
        "col.active_border" = borderColor;
        "col.inactive_border" = inactiveBorderColor;
        resize_on_border = true;
      };

      animations = {
        enabled = true;
        bezier = [
          "pace,0.46, 1, 0.29, 0.99"
          "overshot,0.13,0.99,0.29,1.1"
          "md3_decel, 0.05, 0.7, 0.1, 1"
        ];
        animation = [
          "windowsIn,1,2,md3_decel,slide"
          "windowsOut,1,2,md3_decel,slide"
          "windowsMove,1,2,md3_decel,slide"
          "fade,1,10,md3_decel"
          "workspaces,1,2,md3_decel,slide"
          "workspaces, 1, 2, default"
          "specialWorkspace,1,2,md3_decel,slide"
          "border,0,2,md3_decel"
        ];
      };

      group = {
        "col.border_active" = borderColor;
        "col.border_inactive" = inactiveBorderColor;
        "col.border_locked_active" = inactiveBorderColor;
        "col.border_locked_inactive" = inactiveBorderColor;

        groupbar = {
          "col.active" = borderColor;
          "col.locked_active" = inactiveBorderColor;
          "col.inactive" = "rgba(ffffff33)";
          "col.locked_inactive" = "rgba(ffffff33)";
          font_size = theme.fontSize.small;
          font_family = theme.fontFamily.ui;
          text_color = toRgba theme.color.text;
          indicator_height = 3;
        };
      };

      plugin = {
        hy3 = {
          tabs = {
            radius = 0;
            padding = 0;
            text_font = theme.fontFamily.ui;
            "col.active" = borderColor;
            "col.active.border" = borderColor;
            "col.active.text" = toRgba theme.color.background;

            "col.focused" = inactiveBorderColor;
            "col.focused.border" = inactiveBorderColor;

            "col.inactive" = inactiveBorderColor;
            "col.inactive.border" = inactiveBorderColor;

            "col.urgent" = toRgba theme.color.notifications.urgent;
            "col.urgent.border" = toRgba theme.color.notifications.urgent;
            "col.urgent.text" = toRgba theme.color.notifications.urgentText;
          };
        };
      };

      misc = {
        layers_hog_keyboard_focus = true;
        initial_workspace_tracking = 0;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = false;
        disable_splash_rendering = true;
        disable_hyprland_logo = true;
        enable_swallow = false;
        focus_on_activate = true;
        vfr = true; # Variable Frame Rate
        vrr = 2; # Variable Refresh Rate  Might need to set to 0 for NVIDIA/AQ_DRM_DEVICES
        # Screen flashing to black momentarily or going black when app is fullscreen
        # Try setting vrr to 0

        #  Application not responding (ANR) settings
        enable_anr_dialog = true;
        anr_missed_pings = 20;

      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2;
      };

      decoration = {
        rounding = 0;
        blur = {
          enabled = true;
          size = 5;
          passes = 3;
          ignore_opacity = false;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 3;
          render_power = 1;
          offset = "1, 1";
          color = "rgba(00000022)";
        };
      };

      cursor = {
        sync_gsettings_theme = true;
        no_hardware_cursors = 2; # change to 1 if want to disable
        enable_hyprcursor = false;
        warp_on_change_workspace = 2;
        no_warps = true;
      };

      render = {
        explicit_sync = 1; # Change to 1 to disable
        explicit_sync_kms = 1;
        direct_scanout = 0;
      };

      master = {
        new_status = "master";
        new_on_top = 1;
        mfact = 0.5;
      };

      env = [
        "GTK_THEME,\"Adwaita-dark\""
        "NIXOS_OZONE_WL, 1"
        "NIXPKGS_ALLOW_UNFREE, 1"
        "XDG_CURRENT_DESKTOP, Hyprland"
        "XDG_SESSION_TYPE, wayland"
        "XDG_SESSION_DESKTOP, Hyprland"
        "GDK_BACKEND, wayland, x11"
        "CLUTTER_BACKEND, wayland"
        "QT_QPA_PLATFORM=wayland;xcb"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION, 1"
        "QT_AUTO_SCREEN_SCALE_FACTOR, 1"
        "SDL_VIDEODRIVER, x11"
        "MOZ_ENABLE_WAYLAND, 1"
        "AQ_DRM_DEVICES,/dev/dri/card0:/dev/dri/card1"
        "GDK_SCALE,1"
        "QT_SCALE_FACTOR,1"
        "EDITOR,micro"
      ];
    };

    extraConfig = "
      monitor=eDP-1,1920x1080@60,0x0,1.00
      monitor=DP-2,5120x1440@120,1920x0,1.00
      monitor=,preferred,auto,1
    ";
  };

}
