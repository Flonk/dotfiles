{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Python environment with Selenium + stealth deps (matching what
  # openconnect-pulse-launcher's default.nix bundles)
  selenium-stealth = pkgs.python3.pkgs.buildPythonPackage rec {
    pname = "selenium-stealth";
    version = "1.0.6";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/cb/ac/7877df8b819d54a4e317a093a0a9e0a38d21d884a7250aa713f2f0869442/selenium_stealth-1.0.6-py3-none-any.whl";
      hash = "sha256-ti2lRSqkqE8ppN+yGpaWr/IHiKfFcN0LgbwEqUCEi5c=";
    };
    propagatedBuildInputs = with pkgs.python3.pkgs; [
      selenium
      setuptools
    ];
    doCheck = false;
  };

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.selenium
    selenium-stealth
    ps.xdg-base-dirs
  ]);

  vpn3itConnect = pkgs.stdenv.mkDerivation {
    name = "vpn3it-connect";
    dontUnpack = true;
    installPhase = ''
      install -Dm644 ${./vpn3it-connect.py} $out/lib/vpn3it-connect.py
    '';
  };

  runtimePath = lib.makeBinPath [
    pkgs.chromedriver
    pkgs.chromium
    pkgs.openconnect
  ];

  vpn3it = pkgs.writeShellScriptBin "vpn3it" ''
    set -euo pipefail

    # --- Snapshot pre-VPN default route ---
    PRE_DEV="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/^default/ {print $5; exit}')"
    PRE_GW="$(${pkgs.iproute2}/bin/ip route show default | ${pkgs.gawk}/bin/awk '/^default/ {print $3; exit}')"

    # --- Authenticate & launch openconnect (headless, one Authy prompt) ---
    VPN_HOST_FILE="${config.sops.secrets.vpn3ithost.path}"
    VPN_USER_FILE="${config.sops.secrets.vpn3ituser.path}"
    VPN_PASS_FILE="${config.sops.secrets.vpn3itpass.path}"

    PATH="${runtimePath}:$PATH" \
    ${pythonEnv}/bin/python3 ${vpn3itConnect}/lib/vpn3it-connect.py \
      "$(${pkgs.bat}/bin/bat -pp "''${VPN_HOST_FILE}")" \
      "''${VPN_USER_FILE}" \
      "''${VPN_PASS_FILE}"

    # --- Check for VPN device ---
    # openconnect runs in the foreground in the Python script before returning,
    # so tun0 is already up by the time we get here.
    NEW_DEV="tun0"
    if ! ${pkgs.iproute2}/bin/ip link show "''${NEW_DEV}" > /dev/null 2>&1; then
      echo "Warning: ''${NEW_DEV} not found. Waiting up to 30s..."
      for i in $(seq 1 60); do
        ${pkgs.iproute2}/bin/ip link show "''${NEW_DEV}" > /dev/null 2>&1 && break
        sleep 0.5
      done
    fi

    if ! ${pkgs.iproute2}/bin/ip link show "''${NEW_DEV}" > /dev/null 2>&1; then
      echo "Error: ''${NEW_DEV} never appeared. openconnect may have failed."
      exit 1
    fi

    echo "VPN device ''${NEW_DEV} up, waiting for routing table to stabilize..."

    # --- Poll until the routing table stops changing ---
    # openconnect's vpnc-script modifies routes multiple times; wait for it
    # to settle before we enforce our own default route.
    STABLE_ROUNDS=0
    PREV_ROUTES=""
    for i in $(seq 1 120); do
      CUR_ROUTES="$(${pkgs.iproute2}/bin/ip route show)"
      if [ "''${CUR_ROUTES}" = "''${PREV_ROUTES}" ]; then
        STABLE_ROUNDS=$((STABLE_ROUNDS + 1))
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

    # --- Enforce: keep internet on the original interface ---
    sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" 2>/dev/null || true
    sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100

    # Guard: watch for late rogue route changes from openconnect
    for i in $(seq 1 10); do
      sleep 0.5
      ROGUE="$(${pkgs.iproute2}/bin/ip route show default dev "''${NEW_DEV}" 2>/dev/null || true)"
      if [ -n "''${ROGUE}" ]; then
        echo "Late VPN default route detected, removing..."
        sudo ${pkgs.iproute2}/bin/ip route del default dev "''${NEW_DEV}" 2>/dev/null || true
        sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100 2>/dev/null || true
      fi
    done

    echo ""
    echo "VPN up; internet via ''${PRE_DEV}. Press Ctrl+C to disconnect."
    echo ""

    # --- Wait for openconnect to exit (user hits Ctrl+C) ---
    cleanup() {
      echo "Disconnecting VPN..."
      sudo ${pkgs.procps}/bin/pkill -SIGINT openconnect 2>/dev/null || true
      sleep 1
      # Restore default route just in case
      sudo ${pkgs.iproute2}/bin/ip route replace default via "''${PRE_GW}" dev "''${PRE_DEV}" metric 100 2>/dev/null || true
      echo "VPN disconnected."
    }
    trap cleanup EXIT INT TERM

    # openconnect was launched with -b (background), so wait for it
    while ${pkgs.procps}/bin/pgrep -x openconnect > /dev/null 2>&1; do
      sleep 2
    done
  '';
in
{
  config =
    lib.mkIf (config.skynet.module.projects.andamp.CEFKM || config.skynet.module.projects.andamp.CEIFRS)
      {
        skynet.cli.scripts = [
          {
            command = [
              "3it"
              "vpn"
            ];
            title = "Connect to vpn3it VPN";
            script = "${vpn3it}/bin/vpn3it";
            usage = "Connect to vpn3it VPN. Only prompts for Authy token.";
          }
        ];

        sops.secrets.vpn3ithost = {
          key = "vpn3ithost";
          sopsFile = ./secrets/secrets.json;
        };

        sops.secrets.vpn3ituser = {
          key = "vpn3ituser";
          sopsFile = ./secrets/secrets.json;
        };

        sops.secrets.vpn3itpass = {
          key = "vpn3itpass";
          sopsFile = ./secrets/secrets.json;
        };
      };
}
