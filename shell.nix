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
    echo "Welcome to SKYNET Development Shell."
    echo "Are you on a new machine? Run 'bootstrap' to set up SKYNET."
  '';
}

/*
  # Hi! Are you a new user?

  mkdir -p ~/.config/sops/age
  age-keygen -o ~/.config/sops/age/keys.txt

  To create a new keypair. Add the public key to the .sops.yaml file.

  # Are you on a new machine?

  sudo ssh-keygen -A
  nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'

  # Need a new secret?

  sops ./assets/secrets/mysecret.json

  or if its binary..

  sops -e ~/blah.bin > ./assets/secrets/mysecret.bin
  sops -d ./assets/secrets/mysecret.bin > ~/blah.bin # decrypt

  # Update who can access a secret

  sops updatekeys ./assets/secrets/mysecret.txt
*/
