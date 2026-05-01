{
  pkgs,
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.skynet.module.desktop."vicinae-bitwarden";

  pinentry-rbw = pkgs.writeShellApplication {
    name = "pinentry-rbw";
    text = ''
      PWFILE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rbw-pinentry"
      printf 'OK Pleased to meet you\n'
      while IFS= read -r line; do
        case "$line" in
          GETPIN*)
            if [ -f "$PWFILE" ]; then
              printf 'D %s\nOK\n' "$(cat "$PWFILE")"
            else
              printf 'ERR 83886179 Operation cancelled\n'
            fi
            ;;
          BYE*)  printf 'OK closing connection\n'; exit 0 ;;
          *)     printf 'OK\n' ;;
        esac
      done
    '';
  };

  extension = inputs.vicinae.packages.${pkgs.stdenv.system}.mkVicinaeExtension {
    name = "vicinae-bitwarden";
    version = "0.1.0";
    src = ./extension;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.rbw
      pkgs.gnupg
      pinentry-rbw
    ];

    home.activation.rbwSetPinentry = lib.hm.dag.entryAfter [ "installPackages" ] ''
      if [ -f "${config.xdg.configHome}/rbw/config.json" ]; then
        run ${pkgs.rbw}/bin/rbw config set pinentry ${pinentry-rbw}/bin/pinentry-rbw
      fi
    '';

    services.vicinae.extensions = [ extension ];
  };
}
