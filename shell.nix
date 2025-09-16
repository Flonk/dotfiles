with import <nixpkgs> { };

mkShell {
  nativeBuildInputs = [
    age
    sops
  ];

  NIX_ENFORCE_PURITY = true;

  shellHook = ''
    echo "Welcome to SKYNET Development Shell."
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
