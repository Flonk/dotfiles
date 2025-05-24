.PHONY: update
update:
  sudo nixos-rebuild --flake .#schnitzelwirt switch && home-manager switch --flake .#flo
