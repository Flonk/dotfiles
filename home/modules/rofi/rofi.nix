{
  pkgs,
  config,
  lib,
  ...
}:
{

  programs.rofi = {
    enable = true;
    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        "*" = {
          font = mkLiteral "\"${config.theme.font.ui.normal}\"";
          background-color = mkLiteral "transparent";
          text-color = mkLiteral config.theme.color.wm150;
          accent-color = mkLiteral config.theme.color.text;
          margin = mkLiteral "0px";
          padding = mkLiteral "0px";
          spacing = mkLiteral "0px";
        };

        window = {
          location = mkLiteral "south";
          width = mkLiteral "100%";
          background-color = mkLiteral config.theme.color.wm150;
          children = mkLiteral "[ mainbox ]";
        };

        mainbox = {
          orientation = mkLiteral "horizontal";
          children = mkLiteral "[ inputbar,listview ]";
          width = mkLiteral "calc(100% min 1920px)";
          margin = mkLiteral "0px 0px 0px calc(50% - 960px)";
        };

        inputbar = {
          background-color = mkLiteral config.theme.color.wm800;
          border = mkLiteral "0px 2px 0px 0px";
          border-color = mkLiteral config.theme.color.wm150;
          width = mkLiteral "calc(25% min 480px)";
          padding = mkLiteral "8px 8px";
          spacing = mkLiteral "8px";
          children = mkLiteral "[ prompt, entry ]";
        };

        prompt = {
          text-color = mkLiteral config.theme.color.wm150;
          vertical-align = mkLiteral "0.5";
        };

        entry = {
          vertical-align = mkLiteral "0.5";
        };

        listview = {
          layout = mkLiteral "horizontal";
        };

        element = {
          padding = mkLiteral "8px 8px 8px 8px";
          spacing = mkLiteral "4px";
          text-color = mkLiteral config.theme.color.wm800;
        };

        "element normal urgent" = {
          text-color = mkLiteral config.theme.color.wm800;
        };
        "element normal active" = {
          text-color = mkLiteral config.theme.color.text;
        };
        "element selected" = {
          text-color = mkLiteral config.theme.color.wm800;
        };
        "element selected normal" = {
          background-color = mkLiteral config.theme.color.wm800;
          text-color = mkLiteral config.theme.color.wm150;
        };
        "element selected urgent" = {
          background-color = mkLiteral config.theme.color.wm800;
        };
        "element selected active" = {
          background-color = mkLiteral config.theme.color.wm800;
          text-color = mkLiteral config.theme.color.wm150;
        };

        element-icon = {
          size = mkLiteral "0.75em";
          vertical-align = mkLiteral "0.5";
        };

        element-text = {
          text-color = mkLiteral "inherit";
          vertical-align = mkLiteral "0.5";
        };
      };
  };

}
