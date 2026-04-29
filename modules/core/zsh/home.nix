{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.core.zsh.enable {
    home.packages = with pkgs; [
      fortune
      cowsay
      tree
    ];

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.bat.enable = true;
    programs.eza.enable = true;

    programs.zsh = {
      enable = true;

      # relative to ~
      dotDir = "${config.home.homeDirectory}/.config/zsh";
      enableCompletion = true;
      history.size = 10000;
      history.share = true;

      plugins = [
        {
          name = "powerlevel10k-config";
          src = ./.;
          file = "p10k.zsh";
        }
        {
          name = "zsh-powerlevel10k";
          src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
          file = "powerlevel10k.zsh-theme";
        }
      ];

      initContent =
        let
          motdCommand = config.skynet.host.motd.command;

          init = lib.mkBefore ''
            source ${./zshrc.sh}
          '';

          end = lib.mkAfter ''
            if [[ -n ${lib.escapeShellArg (if motdCommand == null then "" else motdCommand)} ]]; then
              eval ${lib.escapeShellArg (if motdCommand == null then "" else motdCommand)}
            fi
          '';

        in
        lib.mkMerge [
          init
          end
        ];

      oh-my-zsh = {
        enable = true;
        # Standard OMZ plugins pre-installed to $ZSH/plugins/
        # Custom OMZ plugins are added to $ZSH_CUSTOM/plugins/
        # Enabling too many plugins will slowdown shell startup
        plugins = [
          "aliases"
          "git"
          "docker"
          "docker-compose"
          "isodate"
          "kubectl"
          "z"
        ];
        extraConfig = ''
          # Display red dots whilst waiting for completion.
          COMPLETION_WAITING_DOTS="true"
        '';
      };

      sessionVariables = {
        EDITOR = "micro";
      };

      shellAliases = {
        # Overrides those provided by OMZ libs, plugins, and themes.
        # For a full list of active aliases, run `alias`.

        ##### Navigation
        bat = "command bat -P -p --color always --theme 'Visual Studio Dark+'";
        t = "tree -L 2 -a -I '.git' --gitignore --dirsfirst";
        l = "eza -l --group --color-scale=size --git-ignore -I '.git' --group-directories-first -a --git -o --color=always";
        c = "cd_fzf";
        o = "open_fzf";

        ##### Nix
        ne = "nix-instantiate --eval";
        nb = "nix-build";
        ns = "nix-shell";
        s = "skynet";
        nr = "skynet rebuild";
        nrsys = "skynet system rebuild";
        p = "nix-shell -p";
        run = "_nix-shell-run";
        appimage = "nix run nixpkgs#appimage-run --";
        nh = "nix-prefetch-url --unpack"; # url is ref like https://github.com/normen/whatscli/archive/refs/tags/v1.0.11.tar.gz

        ##### Git
        gprune = "git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -d \"{}\"";
        "gprune!" =
          "git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -D \"{}\"";
        b = "gcob";
        squash = "squash_wip";
        gc = "git commit --all --message";

        ##### Docker
        dka = "docker ps -q | xargs docker stop | xargs docker rm";
        "dka!" = "docker ps -aq | xargs docker stop | xargs docker rm";
        "dkav!" = "docker volume ls | xargs docker volume rm";
        "dk!" = "dka! && dkav!";

        ##### Claude
        cc = "z claude && claude --dangerously-skip-permissions";

        ##### Assorted
        future = "toilet -f future";
        x = "sudo env \"PATH=$PATH\"";
        n = "npmrun_fzf";

        ##### Musescore -- the nix package does not work
        musescore = "nix run nixpkgs#appimage-run -- ~/Downloads/MuseScore-Studio-4.5.2.251141401-x86_64.AppImage &";
      };
    };
  };
}
/*
  old stuff.. evalulate if still needed

  # ansible
  export ANSIBLE_NOCOWS=1

  # azure
  az-select-subscription() {
    az account list --output table | tail -n +3 | fzf --layout reverse --height 10 --header "Select Azure subscription" | awk '{print $(NF-3)}' | xargs -I {} az account set --subscription {}
  }
*/
