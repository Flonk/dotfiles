{
  pkgs,
  config,
  lib,
  ...
}:
let
  borderSize = 4;
  lockCommand = config.programs.t3-desktop.quickshell.lockCommand;
  t3Pkgs = import ../../packages.nix {
    inherit pkgs;
    accent = config.programs.t3-desktop.stylix.accent;
    ground = config.programs.t3-desktop.stylix.ground;
  };
  ground = (builtins.fromJSON (builtins.readFile "${t3Pkgs.chrome}/palette.json")).ground;
  loginLock = pkgs.writeShellScript "t3-desktop-login-lock" ''
    [ -n "''${T3_DESKTOP_LOGIN_LOCK:-}" ] || exit 0
    marker="$XDG_RUNTIME_DIR/t3-desktop-login-$HYPRLAND_INSTANCE_SIGNATURE"
    [ -e "$marker" ] && exit 0
    touch "$marker"
    for _ in $(seq 40); do
      ${pkgs.quickshell}/bin/quickshell ipc call lock login && exit 0
      sleep 0.25
    done
    exec ${pkgs.hyprlock}/bin/hyprlock
  '';

  hypr-scale = pkgs.writeShellApplication {
    name = "hypr-scale";
    runtimeInputs = with pkgs; [
      jq
      gawk
      libnotify
    ];
    text = builtins.readFile ./hypr-scale.sh;
  };
in
{
  imports = [
    ./style.nix
    ./hyprcursor.nix
    ./hyprpaper.nix
    ./hyprpicker.nix
  ];

  config = lib.mkIf config.programs.t3-desktop.hyprland.enable {
    home.packages = [ hypr-scale ];

    xdg.dataFile."t3-desktop/libhy3.so".source = "${t3Pkgs.hy3}/lib/libhy3.so";

    stylix.targets.hyprland.hyprpaper.enable = false;

    wayland.windowManager.hyprland = {
      enable = true;
      package = pkgs.hyprland;
      configType = "lua";
      plugins = [ "${config.xdg.dataHome}/t3-desktop/libhy3.so" ];

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
            gaps_in = {
              top = -borderSize;
              right = 0;
              bottom = 0;
              left = -borderSize;
            };
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

          layers.layers_hog_keyboard_focus = true;

          misc = {
            background_color = lib.mkForce "rgba(${lib.removePrefix "#" ground}ff)";
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
                text_font = "${config.stylix.fonts.monospace.name} Bold";
                text_height = config.programs.t3-desktop.label.size;
                text_uppercase = true;
                text_tracking = config.programs.t3-desktop.label.tracking;
                chrome_texture = false;
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
          { leaf = "fadeSwitch";       enabled = false; speed = 5;  bezier = "md3_decel"; }
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

      extraLuaFiles.bindings = ./bindings.lua;

      extraConfig = ''
        hl.exec_cmd("${loginLock}")
        hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd("${lockCommand}"))

        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      '';
    };
  };
}
