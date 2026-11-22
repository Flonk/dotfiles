{

  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development."zed-editor".enable {
    home.packages = with pkgs; [
      nil
      nixd
      typescript-language-server
      typescript
      vscode-langservers-extracted
      jdt-language-server
      jdk21
      omnisharp-roslyn
      terraform-ls
      kotlin-language-server
      texlab
      pyright
      haskell-language-server
      tailwindcss-language-server
      vtsls
      eslint_d

    ];

    programs.zed-editor = {
      enable = true;

      userKeymaps = [
        {
          context = "Editor";
          bindings = {
            "ctrl-y" = [
              "workspace::SendKeystrokes"
              "ctrl-shift-e ctrl-left ctrl-shift-e ctrl-shift-e ctrl-shift-e"
            ];
          };
        }
      ];

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
        ui_font_family = lib.mkDefault config.stylix.fonts.monospace.name;
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
        zoomed_padding = true;
        minimum_contrast_for_highlights = 57.0;

        window_decorations = "client";
        active_pane_modifiers = {
          border_size = 0.0;
        };

        icon_theme = "VSCode Icons for Zed (Dark)";

        tab_bar = {
          show = false;
          show_tab_bar_buttons = true;
          show_nav_history_buttons = true;
        };

        tabs = {
          activate_on_close = "left_neighbour";
          git_status = false;
        };

        preview_tabs = {
          enable_preview_from_file_finder = false;
        };

        title_bar = {
          button_layout = "platform_default";
          show_menus = false;
          show_user_picture = true;
          show_branch_icon = true;
        };

        git_panel = {
          file_icons = true;
          tree_view = true;
          status_style = "icon";
        };

        project_panel = {
          hide_root = false;
          git_status_indicator = false;
          diagnostic_badges = false;
          bold_folder_labels = false;
          indent_size = 20.0;
          entry_spacing = "comfortable";
          hide_gitignore = false;
          default_width = 240.0;
          dock = "left";
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
