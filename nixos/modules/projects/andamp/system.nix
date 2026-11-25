{
  config,
  lib,
  pkgs,
  ...
}:
let
  dir = "/run/andamp-vpn";
  secrets = config.sops.secrets;
  split = pkgs.writeShellScript "andamp-vpn-split" ''
    set -euo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
      ]
    }
    umask 077
    mkdir -p ${dir}
    ovpn=${secrets.andamp-vpn.path}
    for block in ca cert key tls-auth; do
      sed -n "/^<$block>/,/^<\/$block>/{//!p}" "$ovpn" > ${dir}/$block.pem
    done
    read -r _ host port _ < <(grep -m1 '^remote ' "$ovpn")
    {
      echo "ANDAMP_VPN_REMOTE=$host:$port"
      echo "ANDAMP_VPN_USER=$(cat ${secrets.andamp-vpn-user.path})"
      echo "ANDAMP_VPN_PASS=$(cat ${secrets.andamp-vpn-pass.path})"
    } > ${dir}/env
  '';
in
{
  config =
    lib.mkIf
      (config.t3os.module.projects.andamp.enable && config.networking.networkmanager.enable)
      {
        sops.secrets = {
          andamp-vpn = {
            format = "binary";
            sopsFile = ./secrets/andamp-vpn.ovpn;
          };
          andamp-vpn-user.sopsFile = ./secrets/andamp-vpn-auth.json;
          andamp-vpn-pass.sopsFile = ./secrets/andamp-vpn-auth.json;
        };

        systemd.services.andamp-vpn-split = {
          description = "Split the andamp-vpn ovpn into NetworkManager cert files";
          wantedBy = [ "NetworkManager-ensure-profiles.service" ];
          before = [ "NetworkManager-ensure-profiles.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = split;
          };
        };

        networking.networkmanager.ensureProfiles = {
          environmentFiles = [ "${dir}/env" ];
          profiles.andamp-vpn = {
            connection = {
              id = "andamp-vpn";
              uuid = "a7c1d3e0-5b2f-4c8e-9d61-3f0a8e2b4c10";
              type = "vpn";
              autoconnect = false;
            };
            vpn = {
              service-type = "org.freedesktop.NetworkManager.openvpn";
              connection-type = "password-tls";
              remote = "$ANDAMP_VPN_REMOTE";
              proto-tcp = "yes";
              dev = "tun";
              auth = "SHA1";
              cipher = "AES-256-CBC";
              comp-lzo = "adaptive";
              remote-cert-tls = "server";
              reneg-seconds = "0";
              ca = "${dir}/ca.pem";
              cert = "${dir}/cert.pem";
              key = "${dir}/key.pem";
              ta = "${dir}/tls-auth.pem";
              ta-dir = "1";
              challenge-response-flags = "2";
              username = "$ANDAMP_VPN_USER";
              password-flags = "0";
            };
            vpn-secrets.password = "$ANDAMP_VPN_PASS";
            ipv4.method = "auto";
            ipv6.method = "auto";
          };
        };
      };
}
