with import <nixpkgs> { };

let
  bootstrap = writeShellScriptBin "bootstrap" (builtins.readFile ./bootstrap/bootstrap.sh);

  bootstrapPart2 = writeShellScriptBin "bootstrap-part-2" (
    builtins.readFile ./bootstrap/bootstrap-part-2.sh
  );

  updateAllSecrets = writeShellScriptBin "update-all-secrets" (
    builtins.readFile ./bootstrap/update-all-secrets.sh
  );
in
mkShell {
  nativeBuildInputs = [
    age
    curl
    fzf
    git
    micro
    openssh
    qrencode
    ssh-to-age
    sops
    bootstrap
    bootstrapPart2
    updateAllSecrets
  ];

  NIX_ENFORCE_PURITY = true;

  shellHook = ''
    echo "Welcome to SKYNET Development Shell." >&2
    if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
      echo "Are you on a new machine? Run 'bootstrap' to set up SKYNET."
    fi
  '';
}

/*
  # Need a new secret?

  sops ./assets/secrets/mysecret.json

  or if its binary..

  sops -e ~/blah.bin > ./assets/secrets/mysecret.bin
  sops -d ./assets/secrets/mysecret.bin > ~/blah.bin # decrypt
*/
