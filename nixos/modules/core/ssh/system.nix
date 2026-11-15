{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.host.ssh.knock;
  serverConf = pkgs.writeText "fwknopd.conf" ''
    PCAP_INTF ${cfg.interface};
  '';
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets.fwknop-key.sopsFile = ./secrets/fwknop.json;
    sops.secrets.fwknop-hmac.sopsFile = ./secrets/fwknop.json;

    sops.templates."fwknop-access.conf".content = ''
      SOURCE ANY
      KEY_BASE64 ${config.sops.placeholder.fwknop-key}
      HMAC_KEY_BASE64 ${config.sops.placeholder.fwknop-hmac}
      OPEN_PORTS tcp/22
      FW_ACCESS_TIMEOUT 30
    '';

    services.openssh.openFirewall = false;

    systemd.services.fwknopd = {
      description = "fwknop single packet authorization";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "firewall.service"
      ];
      restartTriggers = [ config.sops.templates."fwknop-access.conf".file ];
      path = [ pkgs.iptables ];
      serviceConfig = {
        ExecStart = "${pkgs.fwknop}/bin/fwknopd -f -c ${serverConf} -a ${
          config.sops.templates."fwknop-access.conf".path
        }";
        Restart = "always";
        RestartSec = 5;
        RuntimeDirectory = "fwknop";
      };
    };
  };
}
