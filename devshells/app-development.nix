with import <nixpkgs> {
  config.android_sdk.accept_license = true;
};

let
  pkgs = import <nixpkgs> { config.android_sdk.accept_license = true; };

  android = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [
      "34"
      "35"
    ];
    buildToolsVersions = [
      "34.0.0"
      "35.0.0"
    ];
    includeNDK = true;
    ndkVersions = [ "26.1.10909125" ];
    includeCmake = true;
    cmakeVersions = [ "3.22.1" ];
  };

  repoRootBin = pkgs.writeShellScriptBin "repo-root" ''
    set -euo pipefail
    if command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
      git rev-parse --show-toplevel
    else
      pwd
    fi
  '';

  setupTransporter = pkgs.writeShellScriptBin "setup-transporter" ''
        set -euo pipefail
        [ "''${TRANSPORTER_DEBUG:-}" = "1" ] && set -x

        PROJ_ROOT="$(${repoRootBin}/bin/repo-root)"
        INSTALL_BASE="''${PROJ_ROOT}/install"
        INSTALL_DIR="''${INSTALL_BASE}/itms"
        INSTALLER="''${INSTALL_BASE}/iTMSTransporter_installer_linux.sh"
        DRIVER="''${INSTALL_BASE}/itms_installer_expect.exp"
        mkdir -p "''${INSTALL_BASE}"

        # Already installed? Bail quietly.
        if [ -e "''${INSTALL_DIR}/bin/iTMSTransporter" ] || [ -e "''${INSTALL_DIR}/lib/itmstransporter.jar" ] || [ -e "''${INSTALL_DIR}/lib/osgibootstrapper.jar" ]; then
          exit 0
        fi

        # Reuse existing installer unless forced
        if [ ! -s "''${INSTALLER}" ] || [ "''${TRANSPORTER_FORCE:-0}" = "1" ]; then
          : "''${TRANSPORTER_URL:=https://itunesconnect.apple.com/WebObjects/iTunesConnect.woa/ra/resources/download/public/Transporter__Linux/bin}"
          # Quiet download; still fail if it breaks
          ${pkgs.curl}/bin/curl -sS -fL --retry 3 --connect-timeout 15 \
            -o "''${INSTALLER}.tmp" "''${TRANSPORTER_URL}"
          mv -f "''${INSTALLER}.tmp" "''${INSTALLER}" || true
          chmod +x "''${INSTALLER}"
        fi
        [ -s "''${INSTALLER}" ] || { echo "Transporter installer missing/empty at ''${INSTALLER}" >&2; exit 1; }

        # Expect driver (no output)
        cat > "''${DRIVER}" <<'EOF'
    log_user 0
    set timeout -1
    set inst $env(INSTALLER)
    spawn sh $inst
    expect {
      -re {--More--}                       { send "q"; exp_continue }
      -re {Do you agree.*\[yes or no\]}    { send "yes\r"; exp_continue }
      -re {Continue\?.*\[yes or no\]}      { send "yes\r"; exp_continue }
      eof
    }
    EOF

        # Run installer inside sandbox, completely silent; preserve exit code
        ${pkgs.bubblewrap}/bin/bwrap \
          --ro-bind /nix /nix \
          --dev-bind /dev /dev \
          --proc /proc \
          --tmpfs /tmp \
          --bind "''${INSTALL_BASE}" /usr/local \
          --bind "''${INSTALL_BASE}" "''${INSTALL_BASE}" \
          --dir /bin \
          --ro-bind ${pkgs.bash}/bin/sh /bin/sh \
          --ro-bind ${pkgs.coreutils}/bin/cat /bin/more \
          --ro-bind ${pkgs.coreutils}/bin/cat /bin/less \
          --dir /usr/bin \
          --ro-bind ${pkgs.coreutils}/bin/env /usr/bin/env \
          --ro-bind ${pkgs.coreutils}/bin/cat /usr/bin/more \
          --ro-bind ${pkgs.coreutils}/bin/cat /usr/bin/less \
          --setenv TMPDIR /tmp \
          --setenv TEMP /tmp \
          --setenv TMP /tmp \
          --setenv PAGER cat \
          --setenv INSTALLER "''${INSTALLER}" \
          --setenv PATH '${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gawk}/bin:${pkgs.gnused}/bin:${pkgs.util-linux}/bin:${pkgs.procps}/bin:${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.which}/bin:${pkgs.diffutils}/bin:${pkgs.gnupatch}/bin:/bin:/usr/bin' \
          --unshare-all --die-with-parent \
          ${pkgs.bash}/bin/bash -c 'export HOME=/tmp; exec '"${pkgs.expect}/bin/expect"' "$1"' _ "''${DRIVER}" \
          >/dev/null 2>&1

        # Verify result; print nothing on success, error on failure
        if [ ! -x "''${INSTALL_DIR}/bin/iTMSTransporter" ] && [ ! -e "''${INSTALL_DIR}/lib/osgibootstrapper.jar" ] && [ ! -e "''${INSTALL_DIR}/lib/itmstransporter.jar" ]; then
          echo "Transporter install failed (no itms/ under ''${INSTALL_BASE})" >&2
          exit 1
        fi
  '';

  transporterBin = pkgs.writeShellScriptBin "iTMSTransporter" ''
    set -euo pipefail
    PROJ_ROOT="$(${repoRootBin}/bin/repo-root)"
    ITMS_HOME="''${TRANSPORTER_HOME:-$PROJ_ROOT/install/itms}"

    if [ ! -x "''${ITMS_HOME}/bin/iTMSTransporter" ]; then
      echo "Transporter not installed (missing ''${ITMS_HOME}/bin/iTMSTransporter). Run: setup-transporter" >&2
      exit 1
    fi

    export JAVA_HOME=${pkgs.openjdk17}
    export PATH="''${JAVA_HOME}/bin:''${PATH}"

    # Force no logging unless user provided -v
    args=("$@")
    if ! printf '%s\n' "''${args[@]}" | grep -q -- '^-v\>'; then
      args=(-v off "''${args[@]}")
    fi

    if [ "''${ITMS_QUIET:-1}" = "1" ]; then
      set +e
      out="$(${pkgs.steam-run}/bin/steam-run ${pkgs.bash}/bin/bash \
        "''${ITMS_HOME}/bin/iTMSTransporter" "''${args[@]}" 2>&1)"
      rc=$?
      set -e
      printf '%s\n' "$out" | ${pkgs.gawk}/bin/awk '
        $0 !~ /^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [A-Z]+] <[^>]+> / { print; next }
        / ERROR: / || / CRITICAL:/ { print }
      '
      exit $rc
    else
      exec ${pkgs.steam-run}/bin/steam-run ${pkgs.bash}/bin/bash \
        "''${ITMS_HOME}/bin/iTMSTransporter" "''${args[@]}"
    fi
  '';
in

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    nodejs_22
    azure-functions-core-tools
    azure-cli
    jq
    moreutils
    gradle
    openjdk17
    eas-cli

    steam-run
    gawk

    android.androidsdk
    android.platform-tools
    android."ndk-bundle"

    curl
    bubblewrap
    repoRootBin
    setupTransporter
    transporterBin
  ];

  NIX_ENFORCE_PURITY = true;

  shellHook = ''
    export ANDROID_SDK_ROOT=${android.androidsdk}/libexec/android-sdk
    export ANDROID_HOME="''${ANDROID_SDK_ROOT}"
    export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=''${ANDROID_SDK_ROOT}/build-tools/35.0.0/aapt2"

    PROJ_ROOT="$(repo-root)"
    if [ ! -e "''${PROJ_ROOT}/install/itms/bin/iTMSTransporter" ] && \
       [ ! -e "''${PROJ_ROOT}/install/itms/lib/osgibootstrapper.jar" ] && \
       [ ! -e "''${PROJ_ROOT}/install/itms/lib/itmstransporter.jar" ]; then
      echo "Installing Apple Transporter..."
      setup-transporter || echo "Transporter bootstrap failed. Run 'setup-transporter' manually." >&2
    fi

    export TRANSPORTER_HOME="''${PROJ_ROOT}/install/itms"
  '';
}
