{
  pkgs,
  config,
  lib,
  theme,
  inputs,
  ...
}: {
  
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = false;
    
    profiles.default.extensions = with pkgs.vscode-marketplace; [
      alexanderte.dainty-nord-vscode
      astro-build.astro-vscode
      bbenoist.nix
      brettm12345.nixfmt-vscode
      dandric.vscode-jq
      dbaeumer.vscode-eslint
      esbenp.prettier-vscode
      github.copilot
      github.copilot-chat
      hashicorp.terraform
      iliazeus.vscode-ansi
      jnoortheen.nix-ide
      mechatroner.rainbow-csv
      ms-azuretools.vscode-azureresourcegroups
      ms-azuretools.vscode-azurestorage
      ms-azuretools.vscode-cosmosdb
      ms-vscode.hexeditor
      oderwat.indent-rainbow
      unifiedjs.vscode-mdx
    ];
  };
  
}
