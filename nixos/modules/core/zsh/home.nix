{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.core.zsh.enable {
    home.packages = with pkgs; [
      fortune
      cowsay
      tree
      figlet
      toilet
      btop
      chafa
      jq
    ];

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.bat.enable = true;
    programs.eza.enable = true;

    programs.starship = {
      enable = true;
      settings = lib.mkMerge [
        (builtins.fromTOML (builtins.readFile ./starship.toml))
        (lib.mkIf (config.lib ? stylix) { palettes.base16.accent = lib.mkDefault config.lib.stylix.colors.withHashtag.base0D; })
      ];
    };

    programs.zsh = {
      enable = true;

      dotDir = "${config.home.homeDirectory}/.config/zsh";
      enableCompletion = true;
      history.size = 10000;
      history.share = true;

      initContent =
        let
          motdCommand = config.t3os.host.motd.command;

          init = lib.mkBefore ''
            source ${./zshrc.sh}
            source ${./rlol.sh}
          '';

          end = lib.mkAfter ''
            cc_fn() {
              if [[ -n "$1" ]]; then
                cd "$1" || return 1
              fi
              claude --dangerously-skip-permissions --chrome
            }

            ticket_fn() {
              local ticket=$1
              if [[ -z $ticket ]]; then
                echo "usage: ticket <TICKET>" >&2
                return 1
              fi

              cd ~/repos/ce-ifrs || return 1

              local -a matches
              matches=(.claude/tickets/$ticket(N/) .claude/tickets/$ticket-*(N/))

              local dir=''${matches[1]:-.claude/tickets/$ticket}
              local name=''${dir:t}
              local idfile=$dir/sessionid.txt

              if [[ -s $idfile ]]; then
                claude --chrome --dangerously-skip-permissions \
                  --model opus --effort high --name $name \
                  --resume "$(<$idfile)"
              else
                mkdir -p $dir
                local sid
                sid=$(</proc/sys/kernel/random/uuid)
                print -r -- $sid > $idfile
                claude --chrome --dangerously-skip-permissions \
                  --model opus --effort high --name $name \
                  --session-id $sid "implement ticket $ticket"
              fi
            }

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
          COMPLETION_WAITING_DOTS="true"
        '';
      };

      sessionVariables = {
        EDITOR = "micro";
      };

      shellAliases = {

        bat = "command bat -P -p --color always --theme 'Visual Studio Dark+'";
        tt = "tree -L 2 -a -I '.git' --gitignore --dirsfirst";
        l = "eza -l --group --color-scale=size --git-ignore -I '.git' --group-directories-first -a --git -o --color=always";
        c = "cd_fzf";
        o = "open_fzf";

        ne = "nix-instantiate --eval";
        nb = "nix-build";
        ns = "nix-shell";
        t = "t3os";
        nr = "t3os rebuild";
        p = "nix-shell -p";
        run = "_nix-shell-run";
        appimage = "nix run nixpkgs#appimage-run --";
        nh = "nix-prefetch-url --unpack";

        gprune = "git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -d \"{}\"";
        "gprune!" =
          "git fetch -p && git branch -vv | awk '/: gone]/{print \$1}' | xargs -I {} git branch -D \"{}\"";
        b = "gcob";
        br = "gcobr";
        squash = "squash_wip";
        gc = "git commit --all --message";

        dka = "docker ps -q | xargs docker stop | xargs docker rm";
        "dka!" = "docker ps -aq | xargs docker stop | xargs docker rm";
        "dkav!" = "docker volume ls | xargs docker volume rm";
        "dk!" = "dka! && dkav!";

        cc = "cc_fn";
        ticket = "ticket_fn";

        k = "kubectl";

        future = "toilet -f future";
        x = "sudo env \"PATH=$PATH\"";
        n = "npmrun_fzf";

        musescore = "nix run nixpkgs#appimage-run -- ~/Downloads/MuseScore-Studio-4.5.2.251141401-x86_64.AppImage &";
      };
    };
  };
}
