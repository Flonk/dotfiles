{

  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development."zed-editor".enable {
    home.packages = with pkgs; [
      # Nix
      nil
      nixd
      # TypeScript
      typescript-language-server
      typescript
      # SCSS / SASS / CSS
      vscode-langservers-extracted
      # Java (JDTLS needs Java 21+)
      jdt-language-server
      jdk21
      # C#
      omnisharp-roslyn
      # Terraform
      terraform-ls
      # Kotlin
      kotlin-language-server
      # LaTeX
      texlab
      # Python
      pyright
      # Haskell
      haskell-language-server
      # Web tooling (Node-based LSPs that fail to auto-download on NixOS)
      tailwindcss-language-server
      vtsls
      eslint_d

    ];

    programs.zed-editor = {
      enable = true;

      extensions = [
        "nix"
        "toml"
        "java"
        "scss"
        "csharp"
        "terraform"
        "kotlin"
        "astro"
        "latex"
        "haskell"
      ];

      userSettings = {
        base_keymap = "VSCode";
        auto_update = false;
        load_direnv = "shell_hook";

        buffer_font_family = lib.mkDefault config.stylix.fonts.monospace.name;
        buffer_font_size = lib.mkDefault config.skynet.module.desktop.stylix.fontSizePx;
        ui_font_size = lib.mkDefault (config.skynet.module.desktop.stylix.fontSizePx + 2);

        tab_size = 2;
        soft_wrap = "editor_width";
        wrap_guides = [
          65
          80
          120
        ];
        show_whitespaces = "all";
        format_on_save = "on";

        tab_bar = {
          show = false;
        };

        theme = lib.mkDefault {
          mode = "system";
          light = "One Light";
          dark = "One Dark";
        };

        code_actions_on_format = {
          "source.organizeImports" = true;
        };

        languages = {
          Nix = {
            formatter = "language_server";
          };
          JSON = {
            formatter = {
              external = {
                command = "prettier";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };
          TypeScript = {
            formatter = {
              external = {
                command = "prettier";
                arguments = [
                  "--stdin-filepath"
                  "{buffer_path}"
                ];
              };
            };
          };
        };
      };
    };
  };
}
