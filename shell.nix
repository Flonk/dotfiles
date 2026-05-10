with import <nixpkgs> { };

let
  skynetBootstrap = writeShellScriptBin "skynet-bootstrap" ''
    cd ${toString ./bootstrap}
    ${nodejs_22}/bin/npm install --silent 2>/dev/null
    ${nodejs_22}/bin/npx tsx src/index.tsx "$@"
  '';

  bootstrapRemote = writeShellScriptBin "bootstrap-remote" (builtins.readFile ./bootstrap/remote.sh);

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
    nodejs_22
    openssh
    qrencode
    ssh-to-age
    sops
    skynetBootstrap
    bootstrapRemote
    updateAllSecrets
  ];

  NIX_ENFORCE_PURITY = true;

  shellHook = ''
    echo "Welcome to SKYNET Development Shell." >&2
    if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
      echo "Are you on a new machine? Run 'bootstrap-remote' to set up SKYNET."
      echo "Or run 'skynet-bootstrap' from your dev laptop to bootstrap a remote machine via SSH."
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
