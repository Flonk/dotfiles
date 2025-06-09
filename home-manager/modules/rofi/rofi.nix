{
  pkgs,
  config,
  lib,
  ...
}: {
  
  programs.rofi = {
    enable = true;
   theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {  
     "*" = {
        font             = mkLiteral "\"DejaVu Sans Mono 10\"";
        background-color = mkLiteral "transparent";
        text-color       = mkLiteral "#111111";
        accent-color     = mkLiteral "#FFFFFF";
        margin           = mkLiteral "0px";
        padding          = mkLiteral "0px";
        spacing          = mkLiteral "0px";
      };

      window = {
        location         = mkLiteral "south";
        width            = mkLiteral "100%";
        background-color = mkLiteral "#111111";
        children         = mkLiteral "[ mainbox ]";
      };

      mainbox = {
        orientation = mkLiteral "horizontal";
        children    = mkLiteral "[ inputbar,listview ]";
        width       = mkLiteral "calc(100% min 1920px)";
        margin      = mkLiteral "0px 0px 0px calc(50% - 960px)";
      };

      inputbar = {
        background-color = mkLiteral "#ffa200";
        border           = mkLiteral "0px 2px 0px 0px";
        border-color     = mkLiteral "#111111";
        width            = mkLiteral "calc(25% min 480px)";
        padding          = mkLiteral "6px 8px";
        spacing          = mkLiteral "8px";
        children         = mkLiteral "[ prompt, entry ]";
      };

      prompt = {
        text-color     = mkLiteral "#111111";
        vertical-align = mkLiteral "0.5";
      };

      entry = {
        vertical-align = mkLiteral "0.5";
      };

      listview = {
        layout = mkLiteral "horizontal";
      };

      element = {
        padding    = mkLiteral "6px 8px 5px 8px";
        spacing    = mkLiteral "4px";
        text-color = mkLiteral "#ffa200";
      };

      "element normal urgent" = {
        text-color = mkLiteral "#ffa200";
      };
      "element normal active" = {
        text-color = mkLiteral "#FFFFFF";
      };
      "element selected" = {
        text-color = mkLiteral "#ffa200";
      };
      "element selected normal" = {
        background-color = mkLiteral "#ffa200";
        text-color       = mkLiteral "#111111";
      };
      "element selected urgent" = {
        background-color = mkLiteral "#ffa200";
      };
      "element selected active" = {
        background-color = mkLiteral "#ffa200";
        text-color       = mkLiteral "#111111";
      };

      element-icon = {
        size           = mkLiteral "0.75em";
        vertical-align = mkLiteral "0.5";
      };

      element-text = {
        text-color     = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
      };
    };
  };
  
}
