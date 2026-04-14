{
  config,
  lib,
  pkgs,
  ...
}:
let
  sopsFile = ../modules/vpn3it/secrets/secrets.json;
  renderedPath = config.sops.templates."user-mapping.xml".path;

  rdp3it = pkgs.writeShellScriptBin "rdp3it" ''
    set -euo pipefail
    HOST="$(${pkgs.bat}/bin/bat -pp "${config.sops.secrets.rdp3ithost.path}")"
    PORT="$(${pkgs.bat}/bin/bat -pp "${config.sops.secrets.rdp3itport.path}")"
    USER="$(${pkgs.bat}/bin/bat -pp "${config.sops.secrets.rdp3ituser.path}")"
    PASS="$(${pkgs.bat}/bin/bat -pp "${config.sops.secrets.rdp3itpass.path}")"
    ${pkgs.freerdp}/bin/xfreerdp /v:"''${HOST}":"''${PORT}" /u:"''${USER}" /p:"''${PASS}" \
      /cert:ignore /bpp:32 /dynamic-resolution \
      -gfx +rfx
  '';
in
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEIFRS {
    home.packages = with pkgs; [
      freerdp
    ];

    skynet.cli.scripts = [
      {
        command = [
          "3it"
          "rdp"
        ];
        title = "Connect to CEIFRS via RDP";
        script = "${rdp3it}/bin/rdp3it";
        usage = "Launch xfreerdp session to CEIFRS with credentials from sops.";
      }
    ];

    sops.secrets.rdp3ithost = {
      key = "rdp3ithost";
      inherit sopsFile;
    };

    sops.secrets.rdp3itport = {
      key = "rdp3itport";
      inherit sopsFile;
    };

    sops.secrets.rdp3ittitle = {
      key = "rdp3ittitle";
      inherit sopsFile;
    };

    sops.secrets.rdp3ituser = {
      key = "rdp3ituser";
      inherit sopsFile;
    };

    sops.secrets.rdp3itpass = {
      key = "rdp3itpass";
      inherit sopsFile;
    };

    sops.templates."user-mapping.xml" = {
      content = ''
        <user-mapping>
            <authorize username="flo" password="flo">
                <connection name="${config.sops.placeholder.rdp3ittitle}">
                    <protocol>rdp</protocol>
                    <param name="hostname">${config.sops.placeholder.rdp3ithost}</param>
                    <param name="port">${config.sops.placeholder.rdp3itport}</param>
                    <param name="ignore-cert">true</param>
                    <param name="width">1920</param>
                    <param name="height">1080</param>
                    <param name="dpi">96</param>
                    <param name="color-depth">32</param>
                    <param name="resize-method">display-update</param>
                    <param name="username">${config.sops.placeholder.rdp3ituser}</param>
                    <param name="password">${config.sops.placeholder.rdp3itpass}</param>
                </connection>
            </authorize>
        </user-mapping>
      '';
    };

    systemd.user.services.deploy-guacamole-user-mapping = {
      Unit = {
        Description = "Deploy Guacamole user-mapping.xml to /etc/guacamole";
        After = [ "sops-nix.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "deploy-guacamole-user-mapping" ''
          set -euo pipefail
          sudo ${pkgs.coreutils}/bin/cp "${renderedPath}" /etc/guacamole/user-mapping.xml
          sudo ${pkgs.coreutils}/bin/chown tomcat:tomcat /etc/guacamole/user-mapping.xml
          sudo ${pkgs.coreutils}/bin/chmod 0400 /etc/guacamole/user-mapping.xml
        '';
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
