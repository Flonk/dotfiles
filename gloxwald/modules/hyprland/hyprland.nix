{
  pkgs,
  config,
  lib,
  ...
}:
let
  borderSize = 5;
  lockCommand = config.programs.gloxwald.quickshell.lockCommand;
in
{
  config = lib.mkIf config.programs.gloxwald.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      configType = "lua";
      plugins = [ pkgs.hyprlandPlugins.hy3 ];

      systemd = {
        enable = true;
        enableXdgAutostart = true;
        variables = [
          "--all"
        ];
      };

      xwayland = {
        enable = true;
      };

      settings = {
        mainMod = { _var = "SUPER"; };

        config = {
          input = {
            kb_options = "caps:hyper,hyper:mod3";
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
            workspace_swipe_distance = 500;
            workspace_swipe_invert = 1;
            workspace_swipe_min_speed_to_force = 30;
            workspace_swipe_cancel_ratio = 0.5;
            workspace_swipe_create_new = 1;
            workspace_swipe_forever = 1;
          };

          general = {
            layout = "hy3";
            gaps_in = { top = -borderSize; right = 0; bottom = 0; left = -borderSize; };
            gaps_out = 0;
            border_size = borderSize;
          };

          group = {
            groupbar = {
              font_size = config.stylix.fonts.sizes.desktop;
              font_family = config.stylix.fonts.sansSerif.name;
              indicator_height = 3;
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
            vrr = 2;
            enable_anr_dialog = true;
            anr_missed_pings = 20;
          };

          dwindle = {
            preserve_split = true;
            force_split = 2;
          };

          decoration = {
            rounding = 0;
            blur = {
              enabled = false;
              size = 5;
              passes = 3;
              ignore_opacity = false;
              new_optimizations = true;
            };
            shadow = {
              enabled = false;
              range = 3;
              render_power = 1;
              offset = "1, 1";
            };
          };

          cursor = {
            no_hardware_cursors = 2;
            warp_on_change_workspace = 2;
            no_warps = true;
          };

          render = {
            direct_scanout = 0;
          };

          master = {
            new_status = "master";
            new_on_top = 1;
            mfact = 0.5;
          };

          animations = {
            enabled = true;
          };

          plugin = {
            hy3 = {
              tabs = {
                radius = 0;
                padding = 0;
                text_font = config.stylix.fonts.sansSerif.name;
              };
            };
          };
        };

        curve = [
          { _args = [ "pace"      (lib.generators.mkLuaInline ''{ type = "bezier", points = { { 0.46, 1 }, { 0.29, 0.99 } } }'') ]; }
          { _args = [ "overshot"  (lib.generators.mkLuaInline ''{ type = "bezier", points = { { 0.13, 0.99 }, { 0.29, 1.1 } } }'') ]; }
          { _args = [ "md3_decel" (lib.generators.mkLuaInline ''{ type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } }'') ]; }
        ];

        animation = [
          { leaf = "windowsIn";        enabled = true;  speed = 2;  bezier = "md3_decel"; style = "slide"; }
          { leaf = "windowsOut";       enabled = true;  speed = 2;  bezier = "md3_decel"; style = "slide"; }
          { leaf = "windowsMove";      enabled = true;  speed = 2;  bezier = "md3_decel"; style = "slide"; }
          { leaf = "fade";             enabled = true;  speed = 10; bezier = "md3_decel"; }
          { leaf = "fadeLayers";       enabled = true;  speed = 5;  bezier = "md3_decel"; }
          { leaf = "workspaces";       enabled = true;  speed = 2;  bezier = "md3_decel"; style = "slide"; }
          { leaf = "specialWorkspace"; enabled = true;  speed = 2;  bezier = "md3_decel"; style = "slide"; }
          { leaf = "border";           enabled = false; speed = 2;  bezier = "md3_decel"; }
        ];

        env = map (e: { _args = e; }) [
          [ "XDG_CURRENT_DESKTOP" "Hyprland" ]
          [ "XDG_SESSION_TYPE" "wayland" ]
          [ "XDG_SESSION_DESKTOP" "Hyprland" ]
        ];

        window_rule = [
          { match.class = ".*";                         suppress_event = "maximize"; }
          { match.float = false;                        no_shadow = true; }
          { match.class = "org.pulseaudio.pavucontrol"; size = "900 600"; }
          { match.class = "org.pulseaudio.pavucontrol"; float = true; }
        ];
      };

      # Static keybindings live in bindings.lua; only host-dynamic config below.
      extraLuaFiles.bindings = ./bindings.lua;

      extraConfig = ''
        hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("${lockCommand}"))

        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      '';
    };
  };
}
