{
  pkgs,
  ...
}:
{
  imports = [
    ./__USER__-userconfig.nix
    ../common.nix
  ];

  home = {
    packages = with pkgs; [
      nixfmt
      jq
      btop
      tree
    ];

    username = "__USER__";
    homeDirectory = "/home/__USER__";

    stateVersion = "24.11";
  };

  nixpkgs.config.allowUnfree = true;

  programs.eza.enable = true;
  programs.bat.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
