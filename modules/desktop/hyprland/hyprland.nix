{
  pkgs,
  config,
  lib,
  ...
}:
let
  mon = config.skynet.host.primaryMonitor;
  borderSize = 5;

  # Numpad resize/move bindings across modifier tiers -> hl.dsp lua calls
  kpKeys = [
    { key = "KP_Left";  x = -1; y =  0; }
    { key = "KP_Right"; x =  1; y =  0; }
    { key = "KP_Up";    x =  0; y = -1; }
    { key = "KP_Down";  x =  0; y =  1; }
    { key = "KP_Begin"; x =  0; y =  1; }
    { key = "KP_Home";  x = -1; y = -1; }
    { key = "KP_Prior"; x =  1; y = -1; }
    { key = "KP_End";   x = -1; y =  1; }
    { key = "KP_Next";  x =  1; y =  1; }
  ];
  kpTiers = [
    { mods = "mainMod";                     dispatch = "resize"; step =  80; }
    { mods = "mainMod .. \" + CTRL\"";        dispatch = "resize"; step =  20; }
    { mods = "mainMod .. \" + CTRL + SHIFT\""; dispatch = "resize"; step =   5; }
    { mods = "mainMod .. \" + ALT\"";         dispatch = "move";   step = 160; }
    { mods = "mainMod .. \" + ALT + CTRL\"";   dispatch = "move";   step =  40; }
    { mods = "mainMod .. \" + ALT + CTRL + SHIFT\""; dispatch = "move"; step = 10; }
  ];
  mkKpBindings = lib.concatStrings (lib.concatMap (tier:
    map (k:
      "hl.bind(${tier.mods} .. \" + ${k.key}\", hl.dsp.window.${tier.dispatch}({ x = ${toString (k.x * tier.step)}, y = ${toString (k.y * tier.step)}, relative = true }))\n"
    ) kpKeys
  ) kpTiers);

  lockCommand = config.programs.skynetshell.quickshell.lockCommand;
in
{
  config = lib.mkIf config.skynet.module.desktop.hyprland.enable {
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
            kb_layout = "de";
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
          [ "NIXOS_OZONE_WL" "1" ]
          [ "NIXPKGS_ALLOW_UNFREE" "1" ]
          [ "XDG_CURRENT_DESKTOP" "Hyprland" ]
          [ "XDG_SESSION_TYPE" "wayland" ]
          [ "XDG_SESSION_DESKTOP" "Hyprland" ]
          [ "GDK_BACKEND" "wayland,x11" ]
          [ "CLUTTER_BACKEND" "wayland" ]
          [ "QT_QPA_PLATFORM" "wayland;xcb" ]
          [ "QT_WAYLAND_DISABLE_WINDOWDECORATION" "1" ]
          [ "QT_AUTO_SCREEN_SCALE_FACTOR" "1" ]
          [ "MOZ_ENABLE_WAYLAND" "1" ]
          [ "AQ_DRM_DEVICES" "/dev/dri/card0:/dev/dri/card1" ]
          [ "GDK_SCALE" "1" ]
          [ "QT_SCALE_FACTOR" "1" ]
          [ "EDITOR" "micro" ]
          [ "HYPRSHOT_DIR" "$HOME/Pictures/Screenshots" ]
        ];

        window_rule = [
          { match.class = ".*";                                                  suppress_event = "maximize"; }
          { match.class = "org.pulseaudio.pavucontrol";                          size = "900 600"; }
          { match.float = false;                                                 no_shadow = true; }
          { match.class = "^(Alacritty|code)$";                                  opacity = "1 1"; }
          { match = { class = "Alacritty"; title = "^(initial-shell)$"; };       size = "500 100"; }
          { match.class = "^chrome-nngceckbapebfimnlniiiahkandclblb.*$";         float = true; }
          { match.class = "org.pulseaudio.pavucontrol";                          float = true; }
        ];

        layer_rule = lib.optionals config.skynet.module.desktop.mako.enable [
          { match.namespace = "notifications"; animation = "slide right"; }
        ];
      };

      extraConfig = ''
        local terminal = "foot"
        local browser = "env LIBVA_DRIVER_NAME=iHD qutebrowser"
        local lockscreen = "${lockCommand}"

        hl.exec_cmd("hyprctl setcursor macOS-White 28")
        hl.exec_cmd("systemctl start docker")

        -- HYPRLAND
        hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
        hl.bind(mainMod .. " + CTRL + RETURN", hl.dsp.exec_cmd(browser))
        hl.bind(mainMod .. " + ESCAPE", hl.dsp.exec_cmd(lockscreen))
        hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("obsidian daily"))
        hl.bind(mainMod .. " + Q", hl.dsp.window.close())

        hl.bind(mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window -m active"))
        hl.bind(mainMod .. " + O", hl.dsp.exec_cmd([[bash -lc 'text="$(hyprshot -m region --raw | tesseract stdin stdout -l deu 2>/dev/null)"; wl-copy <<< "$text"; notify-send "📸 OCR copied" "$(echo "$text" | head -c 300)"']]))
        hl.bind(mainMod .. " + SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m output -m active"))
        hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region"))

        -- WINDOW MANAGEMENT (hy3)
        hl.bind(mainMod .. " + A", hl.plugin.hy3.change_focus("raise"))
        hl.bind(mainMod .. " + E", hl.plugin.hy3.change_group("opposite"))
        hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
        hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
        hl.bind(mainMod .. " + H", hl.plugin.hy3.make_group("h"))
        hl.bind(mainMod .. " + W", hl.plugin.hy3.change_group("tab"))
        hl.bind(mainMod .. " + SHIFT + W", hl.plugin.hy3.make_group("tab", { toggle = true }))
        hl.bind(mainMod .. " + V", hl.plugin.hy3.make_group("v"))

        -- FOCUS / MOVE WINDOWS (hy3)
        hl.bind(mainMod .. " + left", hl.plugin.hy3.move_focus("l"))
        hl.bind(mainMod .. " + right", hl.plugin.hy3.move_focus("r"))
        hl.bind(mainMod .. " + up", hl.plugin.hy3.move_focus("u"))
        hl.bind(mainMod .. " + down", hl.plugin.hy3.move_focus("d"))

        hl.bind(mainMod .. " + SHIFT + left", hl.plugin.hy3.move_window("l"))
        hl.bind(mainMod .. " + SHIFT + right", hl.plugin.hy3.move_window("r"))
        hl.bind(mainMod .. " + SHIFT + up", hl.plugin.hy3.move_window("u"))
        hl.bind(mainMod .. " + SHIFT + down", hl.plugin.hy3.move_window("d"))

        -- RESIZE (ijkl)
        hl.bind(mainMod .. " + i", hl.dsp.window.resize({ x = 0, y = 15, relative = true }))
        hl.bind(mainMod .. " + j", hl.dsp.window.resize({ x = -15, y = 0, relative = true }))
        hl.bind(mainMod .. " + k", hl.dsp.window.resize({ x = 0, y = -15, relative = true }))
        hl.bind(mainMod .. " + l", hl.dsp.window.resize({ x = 15, y = 0, relative = true }))
        hl.bind(mainMod .. " + SHIFT + i", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))
        hl.bind(mainMod .. " + SHIFT + j", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
        hl.bind(mainMod .. " + SHIFT + k", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
        hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))

        -- NUMPAD RESIZE/MOVE
        ${mkKpBindings}
        -- WORKSPACES
        hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
        hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
        hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
        hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
        hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
        hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
        hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
        hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
        hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
        hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

        hl.bind(mainMod .. " + CTRL + left", hl.dsp.workspace.move({ monitor = "l" }))
        hl.bind(mainMod .. " + CTRL + right", hl.dsp.workspace.move({ monitor = "r" }))

        hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9, follow = false }))
        hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10, follow = false }))

        -- MOUSE
        hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
        hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

        -- AUDIO / BRIGHTNESS (locked, repeating)
        hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
        hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
        hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
        hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
        hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

        -- MEDIA (locked)
        hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
        hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
        hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

        -- MONITORS
        hl.monitor({ output = "eDP-1", mode = "${toString mon.width}x${toString mon.height}@${toString mon.hz}", position = "0x0", scale = 1.00 })
        hl.monitor({ output = "DP-2", mode = "5120x1440@120", position = "${toString mon.width}x0", scale = 1.00 })
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
      '';
    };
  };
}
