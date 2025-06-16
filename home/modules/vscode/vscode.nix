{
  pkgs,
  config,
  lib,
  theme,
  inputs,
  ...
}:
{

  programs.vscode = {
    enable = true;

    profiles.default.userSettings = {
      "workbench.colorTheme" = "Dainty – Nord (chroma 0, lightness 0)";
      "workbench.colorCustomizations" = {
        "editor.findMatchBackground" = "${theme.color.accent}77";
        "editor.findMatchHighlightBackground" = "${theme.color.accent}77";
        "editor.selectionBackground" = "${theme.color.accent}55";
        "editor.selectionHighlightBackground" = "${theme.color.accent}55";
        "editorError.background" = "#ff000049";
        "editorError.border" = "#ff0000";
        "editorRuler.foreground" = "#ffffff11";
      };

      "workbench.editor.showTabs" = "none";
      "workbench.editor.revealIfOpen" = true;

      "[json]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[typescript]" = {
        "editor.defaultFormatter" = "esbenp.prettier-vscode";
      };
      "[nix]" = {
        "editor.defaultFormatter" = "jnoortheen.nix-ide";
      };

      "editor.codeActionsOnSave" = {
        "source.organizeImports" = "always";
      };

      "editor.formatOnSave" = true;
      "editor.defaultFormatter" = "esbenp.prettier-vscode";
      "editor.wordWrap" = "on";
      "editor.tabSize" = 2;

      "git.enableSmartCommit" = true;
      "javascript.updateImportsOnFileMove.enabled" = "always";
      "typescript.updateImportsOnFileMove.enabled" = "always";

      "github.copilot.enable" = {
        "*" = true;
        "plaintext" = false;
        "markdown" = false;
        "scminput" = false;
      };

      "indentRainbow.colors" = [
        "#2e344022"
        "#3b425222"
        "#434c5e22"
        "#4c566a22"
      ];
      "editor.rulers" = [
        65
        80
        120
      ];
    };

  };

}
