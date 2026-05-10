{
  pkgs,
  ...
}:
{
  imports = [
    ./claude-userconfig.nix
    ../common.nix
  ];

  home = {
    packages = with pkgs; [
      nixfmt
      jq
      btop
      tree
    ];

    username = "claude";
    homeDirectory = "/home/claude";

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
