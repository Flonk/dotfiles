{
  pkgs,
  config,
  lib,
  theme,
  inputs,
  ...
}:
{

  imports = [
    inputs.walker.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    csvlens
  ];

  programs.walker = {
    enable = true;
    runAsService = true;

    # All options from the config.json can be used here.
    config = {
      search.placeholder = "Example";
      ui.fullscreen = true;
      list = {
        height = 200;
      };
      websearch.prefix = "?";
      switcher.prefix = "/";

      providers = {
        default = [
          "desktopapplications"
          "calc"
          "menus"
          "websearch"
        ];
        empty = [ "desktopapplications" ];
      };
    };

  };

  home.activation.walkerTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/walker/themes/mytheme"
    cat > "${config.xdg.configHome}/walker/themes/mytheme/style.css" <<'CSS'
    @define-color window_bg_color ${theme.color.main."100"};
    @define-color accent_bg_color ${theme.color.main."800"};
    @define-color theme_fg_color ${theme.color.main."800"};
    @define-color theme_fg_dark ${theme.color.main."600"};

    * {
      all: unset;
      font-family: "DejaVu Sans Mono";
    }

    .normal-icons {
      -gtk-icon-size: 16px;
    }

    .large-icons {
      -gtk-icon-size: 32px;
    }

    scrollbar {
      opacity: 0;
    }

    .box-wrapper {
      box-shadow: 0 19px 38px rgba(0, 0, 0, 0.3), 0 15px 12px rgba(0, 0, 0, 0.22);
      background: @window_bg_color;
      padding: 20px;
      border: 4px solid @accent_bg_color;
    }

    .preview-box,
    .elephant-hint,
    .placeholder {
      color: @theme_fg_color;
    }

    .box {
    }

    .search-container {
      border-radius: 10px;
    }

    .input placeholder {
      opacity: 0.5;
    }

    .input {
      font-size: 20px;
      caret-color: @theme_fg_color;
      padding: 10px;
      color: @theme_fg_color;
    }

    .input:focus,
    .input:active {
    }

    .content-container {
    }

    .placeholder {
    }

    .scroll {
    }

    .list {
      color: @theme_fg_color;
    }

    child {
    }

    .item-box {
      border-radius: 10px;
      padding: 10px;
    }

    .item-quick-activation {
      margin-left: 10px;
      background: alpha(@accent_bg_color, 0.25);
      border-radius: 5px;
      padding: 10px;
    }

    child:selected,
    child:selected * {
      background: @accent_bg_color;
      color: @window_bg_color;
    }

    .item-text-box {
    }

    .item-text {
    }

    .item-subtext {
      font-size: 12px;
      color: @theme_fg_dark;
    }

    .item-image {
      margin-right: 10px;
    }

    .keybind-hints {
      opacity: 0.5;
      color: @theme_fg_color;
    }

    .preview {
      border: 1px solid alpha(@accent_bg_color, 0.25);
      padding: 10px;
      border-radius: 10px;
      color: @theme_fg_color;
    }

    .calc .item-text {
      font-size: 24px;
    }

    .calc .item-subtext {
    }

    .symbols .item-image {
      font-size: 24px;
    }

    .todo.done .item-text-box {
      opacity: 0.25;
    }

    .todo.urgent {
      font-size: 24px;
    }

    .todo.active {
      font-weight: bold;
    }

    .preview .large-icons {
      -gtk-icon-size: 64px;
    }
    CSS
  '';

}
