{ lib, pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      hello
      nautilus
      walker
      hyprpaper
      hyprshot

      brightnessctl
      playerctl
      networkmanagerapplet
      pavucontrol
    ];
    
    # This needs to actually be set to your username
    username = "flo";
    homeDirectory = "/home/flo";

    stateVersion = "25.05";
  };

  programs.zsh.shellAliases = {
  	update = "sudo nixos-rebuild --flake .#schnitzelwirt switch && home-manager switch --flake .#flo";
  };

  programs.kitty.enable = true;

  nixpkgs.config.allowUnfree = true;
  programs.waybar.enable = true;
  programs.vscode.enable = true;

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    
    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = ["--all"];
    };
    
    xwayland = {
      enable = true;
    };
    
    settings = {
      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
      "$menu" = "walker";
      "$mainMod" = "SUPER";
      "$code" = "codium";
      "$browser" = "firefox";
      "$editor" = "micro";
              
      exec-once = [
        "waybar"
        "kitty"
        "alacritty"
        "firefox"
        "micro"
      ];

      bind = [
      	"$mainMod, T, exec, $terminal"
      	"$mainMod, Z, exec, alacritty"
        "$mainMod, U, exec, xterm"
      	"$mainMod ALT, RETURN, exec, $browser"
        "$mainMod, RETURN, exec, $terminal"
      	"$mainMod, E, exec, $fileManager"
        "$mainMod, M, exit"
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
        layout = "dwindle";
        gaps_in = 6;
        gaps_out = 8;
        border_size = 2;
        resize_on_border = true;
      };

      misc = {
        layers_hog_keyboard_focus = true;
        initial_workspace_tracking = 0;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = false;
        # disable_hyprland_logo = true;
        disable_splash_rendering = true;
        enable_swallow = false;
        vfr = true;   # Variable Frame Rate 
        vrr = 2;   #Variable Refresh Rate  Might need to set to 0 for NVIDIA/AQ_DRM_DEVICES
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
        rounding = 10;
        blur = {
          enabled = true;
          size = 5;
          passes = 3;
          ignore_opacity = false;
          new_optimizations = true;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      environment = {
        no_donation_nag = true;
        no_update_news = false;
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
      monitor=,preferred,auto,1
    ";
  };
  
}
