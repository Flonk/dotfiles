{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.gloxwald.greeter;
  grubCfg = config.programs.gloxwald.grub;
  t = config.programs.gloxwald.theme;

  gloxwaldPkgs = import ../packages.nix { inherit pkgs; };

  grubSrc = builtins.path {
    path = ../grub;
    name = "gloxwald-grub";
  };

  asciiDefault = builtins.readFile ../ascii.txt;

  greeterPkg = gloxwaldPkgs.greeter;

  asciiFile = pkgs.writeText "gloxwald-greeter-ascii.txt"
    (if t != null then t.asciiArt else asciiDefault);

  greeterFlags = concatStringsSep " " (
    [ "--ascii ${asciiFile}" "--exec ${escapeShellArg cfg.settings.exec}" ]
    ++ optional (cfg.settings.user != null) "--user ${escapeShellArg cfg.settings.user}"
    ++ optionals (t != null) [
      "--bg '${t.bg_base}'"
      "--fg '${t.fg_primary}'"
      "--accent '${t.accent}'"
    ]
  );

  # Kitty config for the greeter session — no decorations,
  # themed background, custom font rendering.
  kittyConf = pkgs.writeText "gloxwaldgreet-kitty.conf" (''
    font_family ${cfg.font.name}
    font_size ${toString cfg.font.size}
    cursor_shape block
    cursor_blink_interval 0
    enable_audio_bell no
    window_padding_width 0
    hide_window_decorations yes
    confirm_os_window_close 0
  '' + optionalString (t != null) ''
    background ${t.bg_base}
    foreground ${t.fg_primary}
  '');

  # The terminal + greeter the kiosk compositor launches.
  greeterClient = "${pkgs.kitty}/bin/kitty --config=${kittyConf} ${greeterPkg}/bin/gloxwaldgreet ${greeterFlags}";

  # Minimal sway kiosk config used when the greeter is pinned to a single
  # output: disable every output, then enable only the requested one, so the
  # greeter never spans multiple monitors.
  swayKioskConf = pkgs.writeText "gloxwaldgreet-sway.conf" ''
    output * disable
    output ${cfg.output} enable
    xwayland disable
    default_border none
    default_floating_border none
    for_window [app_id="kitty"] fullscreen enable, border none
    exec "${greeterClient}; ${pkgs.sway}/bin/swaymsg exit"
  '';

  # cage spans all outputs (extend); sway pins to one named output.
  greeterCommand =
    if cfg.output == null
    then "${pkgs.cage}/bin/cage -s -- ${greeterClient}"
    else "${pkgs.sway}/bin/sway --config ${swayKioskConf}";

  # --- GRUB theme derivation ---
  gloxwaldGrubTheme = pkgs.runCommand "gloxwald-grub-theme"
    {
      nativeBuildInputs = with pkgs; [ imagemagick grub2 ];

      GRUB_BG_COLOR     = if t != null then t.bg_base   else "#1a1a1a";
      GRUB_BORDER_COLOR = if t != null then t.accent    else "#ff9529";
      GRUB_BAR_BG       = if t != null then t.bg_active else "#1C1D24";

      GRUB_WIDTH = toString grubCfg.resolution.width;
      GRUB_HEIGHT = toString grubCfg.resolution.height;

      GRUB_ASCII_ART = pkgs.writeText "gloxwald-ascii.txt"
        (if t != null then t.asciiArt else asciiDefault);
      GRUB_FONT_FAMILY = grubCfg.font.family;
      GRUB_FONT_REGULAR = grubCfg.font.regular;
      GRUB_FONT_BOLD = grubCfg.font.bold;
      GRUB_OUTPUT_DIR = "placeholder";
    }
    ''
      export GRUB_OUTPUT_DIR="$out"
      mkdir -p "$out"
      bash ${grubSrc}/generate-assets.sh
    '';

in
{
  imports = [ ./hyprland/nixos.nix ];

  options.programs.gloxwald = {
    theme = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          asciiArt   = mkOption {
            type = types.lines;
            default = asciiDefault;
            description = "ASCII art displayed by greeter and rendered into the GRUB background";
          };
          bg_base    = mkOption { type = types.str; };
          bg_active  = mkOption { type = types.str; };
          accent     = mkOption { type = types.str; };
          fg_primary = mkOption { type = types.str; };
        };
      });
      default = null;
      description = "Shared theme for greeter and GRUB. If null, hardcoded defaults are used.";
    };

    grub = {
      enable = mkEnableOption "gloxwald GRUB theme";

      resolution = {
        width = mkOption {
          type = types.int;
          default = 1920;
        };
        height = mkOption {
          type = types.int;
          default = 1080;
        };
      };

      font = {
        family = mkOption {
          type = types.str;
          default = "DejaVu Sans Mono";
          description = "Font family name used in theme.txt";
        };
        regular = mkOption {
          type = types.path;
          default = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf";
          description = "Path to regular weight TTF";
        };
        bold = mkOption {
          type = types.path;
          default = "${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono-Bold.ttf";
          description = "Path to bold weight TTF";
        };
      };

      useOSProber = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable os-prober for detecting other OSes";
      };
    };

    greeter = {
      enable = mkEnableOption "gloxwaldgreet greeter for greetd";

      output = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "eDP-1";
        description = ''
          Wayland output to pin the greeter to (e.g. "eDP-1"). When null the
          greeter runs under cage and spans all connected outputs, which on a
          multi-monitor setup centres it across the seam between displays. When
          set, the greeter runs under sway on that single output only.
        '';
      };

      settings = {
        exec = mkOption {
          type = types.str;
          description = "Command to launch after successful login (e.g. \"start-hyprland\")";
        };
        user = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Username to prefill; initial focus moves to the password field";
        };
      };

      font = {
        name = mkOption {
          type = types.str;
          default = "monospace";
          description = "Font name for the greeter (rendered via kitty)";
        };
        size = mkOption {
          type = types.int;
          default = 18;
          description = "Font size in points for the greeter";
        };
        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Font package to install (e.g. pkgs.nerd-fonts.dejavu-sans-mono)";
        };
      };
    };
  };

  config = mkMerge [
    (mkIf grubCfg.enable {
      boot.loader.grub.enable = true;
      boot.loader.grub.useOSProber = grubCfg.useOSProber;
      boot.loader.grub.theme = gloxwaldGrubTheme;
    })

    (mkIf cfg.enable {
    # The greeter runs inside a minimal kiosk Wayland compositor (cage when
    # spanning all outputs, sway when pinned to greeter.output) with kitty as
    # the terminal emulator.  This gives full TrueType / Nerd Font rendering
    # via kitty's GPU-accelerated text pipeline — something the raw Linux TTY
    # (even with kmscon) cannot match.
    services.greetd = {
      enable = true;
      settings = {
        terminal.vt = 1;
        default_session = {
          command = greeterCommand;
          user = "greeter";
        };
      };
    };

    users.users.greeter = {
      isSystemUser = true;
      group = "greeter";
      home = "/var/lib/greeter";
      createHome = true;
    };
    users.groups.greeter = { };

    environment.systemPackages = [ greeterPkg pkgs.kitty ]
      ++ (if cfg.output == null then [ pkgs.cage ] else [ pkgs.sway ]);

    # Make the greeter font available system-wide so kitty can find it
    fonts.packages = mkIf (cfg.font.package != null) [ cfg.font.package ];

    security.polkit.enable = true;
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.login1.power-off" ||
             action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
             action.id == "org.freedesktop.login1.reboot" ||
             action.id == "org.freedesktop.login1.reboot-multiple-sessions") &&
            subject.user == "greeter") {
          return polkit.Result.YES;
        }
      });
    '';

    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
      # Suppress kernel messages (e.g. ucsi_acpi) from printing over the greeter
      ExecStartPre = "${pkgs.util-linux}/bin/dmesg --console-off";
      ExecStopPost = "${pkgs.util-linux}/bin/dmesg --console-on";
    };
  })
  ];
}
