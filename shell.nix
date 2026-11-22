with import <nixpkgs> { };

let
  t3osBootstrap = writeShellScriptBin "t3os-bootstrap" ''
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
    t3osBootstrap
    bootstrapRemote
    updateAllSecrets
  ];

  NIX_ENFORCE_PURITY = true;

  shellHook = ''
    echo "Welcome to T3 OS Development Shell." >&2
    if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ ! -f "$HOME/.ssh/id_rsa" ] && [ ! -f "$HOME/.config/sops/age/keys.txt" ]; then
      echo "Are you on a new machine? Run 'bootstrap-remote' to set up T3 OS."
      echo "Or run 't3os-bootstrap' from your dev laptop to bootstrap a remote machine via SSH."
    fi
  '';
}

