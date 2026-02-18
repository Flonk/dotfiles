{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.skynet.module.system.chrome-remote-desktop;

  chrome-remote-desktop = pkgs.stdenv.mkDerivation rec {
    pname = "chrome-remote-desktop";
    version = "145.0.7632.9";

    src = pkgs.fetchurl {
      url = "https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb";
      hash = "sha256-LzbIDlgdl/xCy5D/fRJfYFQeffsbH4mi94Ucp3+3oA4=";
    };

    nativeBuildInputs = [
      pkgs.dpkg
      pkgs.autoPatchelfHook
      pkgs.makeWrapper
      pkgs.wrapGAppsHook3
    ];

    buildInputs = [
      pkgs.glib
      pkgs.gtk3
      pkgs.libxkbcommon
      pkgs.nspr
      pkgs.nss
      pkgs.pam
      pkgs.expat
      pkgs.cairo
      pkgs.pango
      pkgs.xorg.libX11
      pkgs.xorg.libXdamage
      pkgs.xorg.libXext
      pkgs.xorg.libXfixes
      pkgs.xorg.libXrandr
      pkgs.xorg.libXtst
      pkgs.mesa
      pkgs.dbus
      pkgs.xorg.libxcb
      pkgs.gdk-pixbuf
      pkgs.at-spi2-atk
    ];

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/google/chrome-remote-desktop
      cp -r opt/google/chrome-remote-desktop/* $out/opt/google/chrome-remote-desktop/

      mkdir -p $out/etc/opt/chrome/native-messaging-hosts

      # Fix native messaging host JSON files to point to our store path
      for f in etc/opt/chrome/native-messaging-hosts/*.json; do
        name=$(basename "$f")
        sed "s|/opt/google/chrome-remote-desktop|$out/opt/google/chrome-remote-desktop|g" \
          "$f" > "$out/etc/opt/chrome/native-messaging-hosts/$name"
      done

      # Install the systemd service template
      mkdir -p $out/lib/systemd/system
      sed "s|/opt/google/chrome-remote-desktop|$out/opt/google/chrome-remote-desktop|g" \
        lib/systemd/system/chrome-remote-desktop@.service \
        > $out/lib/systemd/system/chrome-remote-desktop@.service

      # Patch the Python script to fix hardcoded paths
      substituteInPlace $out/opt/google/chrome-remote-desktop/chrome-remote-desktop \
        --replace-fail '#!/usr/bin/python3' '#!${pkgs.python3.withPackages (ps: [
          ps.dbus-python
          ps.packaging
          ps.psutil
          ps.pyxdg
        ])}/bin/python3' \
        --replace-fail '"/usr/bin/pkexec"' '"${pkgs.polkit}/bin/pkexec"' \
        --replace-fail '"/usr/bin/sudo"' '"${pkgs.sudo}/bin/sudo"' \
        --replace-fail '/usr/lib/xorg/Xorg' '${pkgs.xorg.xorgserver}/bin/Xorg' \
        --replace-fail 'ModulePath "/usr/lib/xorg/modules"' 'ModulePath "${pkgs.xorg.xorgserver}/lib/xorg/modules"'

      # Create convenience symlinks
      mkdir -p $out/bin
      ln -s $out/opt/google/chrome-remote-desktop/chrome-remote-desktop $out/bin/chrome-remote-desktop

      # Install .desktop file
      mkdir -p $out/share/applications
      cp -r usr/share/applications/* $out/share/applications/ 2>/dev/null || true

      runHook postInstall
    '';

    # The .deb URL uses "current" so the hash will change on upstream updates.
    # When that happens, update the hash above.
    meta = with lib; {
      description = "Chrome Remote Desktop - access your computer remotely";
      homepage = "https://remotedesktop.google.com";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

in
{
  config = lib.mkIf cfg {
    environment.systemPackages = [
      chrome-remote-desktop
      pkgs.xorg.xorgserver
      pkgs.xorg.xf86videodummy
      pkgs.xvfb-run
      pkgs.xfce.xfce4-session
      pkgs.xfce.xfce4-panel
      pkgs.xfce.xfwm4
      pkgs.xfce.xfce4-terminal
      pkgs.xfce.xfdesktop
      pkgs.xfce.xfce4-settings
      pkgs.xfce.thunar
    ];

    # XFCE services needed for the CRD X11 session
    services.xserver.desktopManager.xfce.enable = true;

    # Session script that CRD uses to launch a desktop in its X11 session.
    # CRD looks for ~/.chrome-remote-desktop-session first, then /etc/chrome-remote-desktop-session.
    # Symlink native messaging host configs so Chrome can find them
    environment.etc = {
      "chrome-remote-desktop-session" = {
        text = ''
          exec ${pkgs.xfce.xfce4-session}/bin/xfce4-session
        '';
        mode = "0755";
      };

      "opt/chrome/native-messaging-hosts/com.google.chrome.remote_desktop.json" = {
        source = "${chrome-remote-desktop}/etc/opt/chrome/native-messaging-hosts/com.google.chrome.remote_desktop.json";
      };
      "opt/chrome/native-messaging-hosts/com.google.chrome.remote_assistance.json" = {
        source = "${chrome-remote-desktop}/etc/opt/chrome/native-messaging-hosts/com.google.chrome.remote_assistance.json";
      };
      "opt/chrome/native-messaging-hosts/com.google.chrome.remote_webauthn.json" = {
        source = "${chrome-remote-desktop}/etc/opt/chrome/native-messaging-hosts/com.google.chrome.remote_webauthn.json";
      };
    };

    # Systemd service template for per-user CRD sessions
    # Use: systemctl start chrome-remote-desktop@flo
    systemd.services."chrome-remote-desktop@" = {
      description = "Chrome Remote Desktop instance for %i";
      after = [ "network.target" ];
      overrideStrategy = "asDropin";
      path = [
        pkgs.xorg.xorgserver
        pkgs.xorg.xf86videodummy
        pkgs.xvfb-run
        pkgs.coreutils
        pkgs.bash
        pkgs.psmisc
        pkgs.util-linux
        pkgs.dbus
        pkgs.xfce.xfce4-session
        pkgs.xfce.xfwm4
        pkgs.xfce.xfce4-panel
        pkgs.xfce.xfdesktop
        pkgs.xfce.xfce4-settings
        pkgs.xfce.xfce4-terminal
        pkgs.xfce.thunar
        "/run/current-system/sw"
      ];
      serviceConfig = {
        Type = "simple";
        User = "%i";
        ExecStart = "${chrome-remote-desktop}/opt/google/chrome-remote-desktop/chrome-remote-desktop --start --new-session";
        ExecReload = "${chrome-remote-desktop}/opt/google/chrome-remote-desktop/chrome-remote-desktop --reload";
        ExecStop = "${chrome-remote-desktop}/opt/google/chrome-remote-desktop/chrome-remote-desktop --stop";
        StandardOutput = "journal";
        StandardError = "inherit";
        Environment = [
          "XDG_SESSION_CLASS=user"
          "XDG_SESSION_TYPE=x11"
          # Force Xvfb mode — more reliable on NixOS than Xorg+dummy
          "CHROME_REMOTE_DESKTOP_USE_XVFB=1"
        ];
        RestartForceExitStatus = "41";
      };
      # Don't set wantedBy — this is a template unit. Enable a specific instance instead.
    };

    # Auto-start CRD for user flo
    systemd.services."chrome-remote-desktop@flo" = {
      overrideStrategy = "asDropin";
      wantedBy = [ "multi-user.target" ];
    };

    # PAM config for chrome-remote-desktop
    security.pam.services.chrome-remote-desktop = {
      text = ''
        auth      include login
        account   include login
        password  include login
        session   required pam_limits.so
        session   include login
        session   required pam_env.so readenv=1
      '';
    };
  };
}
