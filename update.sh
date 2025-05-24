#!/usr/bin/env nix-shell
#! nix-shell -i bash --pure
#! nix-shell -p bash nixos-rebuild home-manager sudo

sudo nixos-rebuild --flake .#schnitzelwirt switch && home-manager switch --flake .#flo
