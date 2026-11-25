{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];
  systemd.services.NetworkManager-wait-online.enable = false;

  time.timeZone = "Europe/Vienna";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_PAPER = "de_AT.UTF-8";
    LC_TELEPHONE = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = false;

  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };

  services.printing.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.package = lib.mkIf (lib.versionOlder pkgs.bluez.version "5.88") (pkgs.bluez.overrideAttrs (old: rec {
    version = "5.88";
    src = pkgs.fetchurl {
      url = "mirror://kernel/linux/bluetooth/bluez-${version}.tar.xz";
      hash = "sha256-aVLDnrX4sO5xLMUKs7z/A74XxBDdl8pkD0hJ2aFlO6M=";
    };
    patches = [ ];
    postInstall = builtins.replaceStrings [ "install -Dm755 attrib/gatttool $out/bin/gatttool" ] [ "" ] old.postInstall;
    postPatch = old.postPatch + ''
      sed -i 's/-lreadline/$(READLINE_LIBS)/' Makefile.tools
      sed -i -e '/AC_MSG_ERROR(readline header files are required))/d' \
        -e 's|AC_CHECK_HEADERS(readline/readline.h, enable_readline=yes,|PKG_CHECK_MODULES([READLINE], [readline], enable_readline=yes)|' configure.ac
    '';
  }));
  hardware.bluetooth.settings = {
    General = {
      Experimental = "true";
    };
    Policy = {
      AutoEnable = "true";
    };
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;

    extraConfig.pipewire."10-rtp-session" = {
      "context.modules" = [
        { name = "libpipewire-module-rtp-session"; }
      ];
    };

    #media-session.enable = true;

    wireplumber = {
      configPackages = [
        (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/11-bluetooth-policy.conf" ''
          wireplumber.settings = { bluetooth.autoswitch-to-headset-profile = false }
          monitor.bluez.properties = { bluez5.roles = [ a2dp_sink a2dp_source ] }
        '')
        (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/52-earbuds-priority.conf" ''
          monitor.bluez.rules = [
            {
              matches = [{ node.name = "bluez_output.80_C3_BA_53_78_8B.1" }]
              actions = {
                update-props = {
                  "priority.driver" = 2200
                  "priority.session" = 2200
                }
              }
            }
          ]
        '')
      ];
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.enableOnBoot = false;

  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
  systemd.services.bluetooth = {
    enable = true;
    description = "Bluetooth service";
    wantedBy = [ "basic.target" ];
    after = [ "sysinit.target" ];
    before = [
      "network.target"
      "multi-user.target"
      "graphical.target"
    ];
  };

  programs.firefox.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = false;
  };

  environment.systemPackages = with pkgs; [
    home-manager

    git
    micro

    curl
    wget

    foot
    alacritty
    upower

    iproute2
    nettools
    bind
    iputils
    nmap
    whois
  ];

  environment.variables.EDITOR = "micro";

  sops.age = {
    sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    keyFile = "/var/lib/sops-nix/key.txt";
    generateKey = true;
  };

  networking.firewall.allowedTCPPorts = [
    7071
    8082
    3131
  ];
  networking.firewall.allowedUDPPorts = [
    3131
  ];

  system.stateVersion = "25.05";

}
