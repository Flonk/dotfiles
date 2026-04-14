{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  vpnLauncher =
    inputs.openconnect-pulse-launcher.packages."${pkgs.stdenv.hostPlatform.system
    }".openconnect-pulse-launcher;

  # vpn lite via ssh tunnels; doesn't work for everything (especially kube port forwards
  # collide with this), but for simple tasks this is enough
  vpnLite = pkgs.writeShellScriptBin "vpn-obk" ''
    set -euo pipefail
    PRE_DEV="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/^default/ {print $5; exit}')"
    PRE_GW="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/^default/ {print $3; exit}')"

    VPN_HOST_FILE="${config.sops.secrets.vpn3ithost.path}"
    "${vpnLauncher}/bin/openconnect-pulse-launcher" "$(${pkgs.bat}/bin/bat -pp "''${VPN_HOST_FILE}")" &
    VPN_PID=$!

    # wait for a *new* default route dev (the VPN dev)
    for i in $(seq 1 60); do
      NEW_DEV="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk -v W="''${PRE_DEV}" '/^default/ && $5 != W {print $5; exit}')"
      [ -n "''${NEW_DEV}" ] && break
      sleep 0.5
    done

    if [ -n "''${NEW_DEV}" ]; then
      echo "VPN device ''${NEW_DEV} up, waiting for routing table to stabilize..."

      # Poll until the routing table stops changing, meaning openconnect's
      # vpnc-script is done adding/modifying routes. We snapshot the full
      # routing table and compare it after a short interval. Once two
      # consecutive snapshots match, the table is stable.
      STABLE_ROUNDS=0
      PREV_ROUTES=""
      for i in $(seq 1 120); do
        CUR_ROUTES="$(${pkgs.iproute2}/bin/ip route show)"
        if [ "''${CUR_ROUTES}" = "''${PREV_ROUTES}" ]; then
          STABLE_ROUNDS=$((STABLE_ROUNDS + 1))
          # Require 3 consecutive stable checks (~1.5s of no changes)
          if [ "''${STABLE_ROUNDS}" -ge 3 ]; then
            echo "Routing table stable after ''${i} checks."
            break
          fi
        else
          STABLE_ROUNDS=0
        fi
        PREV_ROUTES="''${CUR_ROUTES}"
        sleep 0.5
      done

      # Now enforce: remove VPN default route, restore original default
      sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" 2>/dev/null || true
      sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100

      # Guard: keep watching for a few more seconds in case openconnect
      # sneaks in a late route change (e.g. DNS reconfiguration trigger)
      for i in $(seq 1 10); do
        sleep 0.5
        ROGUE="$(${pkgs.iproute2}/bin/ip route show default dev "''${NEW_DEV}" 2>/dev/null || true)"
        if [ -n "''${ROGUE}" ]; then
          echo "Late VPN default route detected, removing..."
          sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" 2>/dev/null || true
          sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100 2>/dev/null || true
        fi
      done
    fi

    echo "VPN up; internet via ''${PRE_DEV}. Ctrl+C to stop."
    wait "''${VPN_PID}"
  '';
in
{
  config =
    lib.mkIf (config.skynet.module.projects.andamp.CEFKM || config.skynet.module.projects.andamp.CEIFRS)
      {
        home.packages = [
          vpnLauncher
        ];

        skynet.cli.scripts = [
          {
            command = [
              "vpn3it"
              "connect"
            ];
            title = "Connect to vpn3it VPN";
            script = "${vpnLite}/bin/vpn-obk";
            usage = "Connect to vpn3it VPN via openconnect-pulse-launcher.";
          }
        ];

        sops.secrets.vpn3ithost = {
          key = "vpn3ithost";
          sopsFile = ./secrets/secrets.json;
        };
      };
}
