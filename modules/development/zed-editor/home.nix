{

  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development."zed-editor".enable {
    programs.zed-editor = {
      enable = true;

      extensions = [
        "nix"
        "toml"
      ];

      userSettings = {
        base_keymap = "VSCode";
        auto_update = false;
        load_direnv = "shell_hook";

        buffer_font_family = config.skynet.theme.fontFamily.mono;
        buffer_font_size = config.skynet.theme.fontSize.bigger;
        ui_font_size = 16;

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

        theme = {
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
