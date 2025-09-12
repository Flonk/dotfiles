{

  pkgs,
  config,
  lib,
  theme,
  inputs,
  ...
}:
let
  color = theme.color.app;
in
{
  programs.vscode = {
    enable = true;

    profiles.default.userSettings = {
      "editor.fontFamily" = theme.fontFamily.mono;
      "editor.fontSize" = theme.fontSize.bigger;
      "window.zoomLevel" = -1;

      "workbench.colorTheme" = "Dainty – Nord (chroma 0, lightness 0)";
      "workbench.colorCustomizations" = {
        # backgrounds (all 150)
        "editor.background" = color."150";
        "terminal.background" = color."150";
        "peekViewEditor.background" = color."150";
        "editorGutter.background" = color."150";
        "editorPane.background" = color."150";

        "sideBar.background" = color."150";
        "activityBar.background" = color."150";
        "panel.background" = color."150";
        "editorGroupHeader.tabsBackground" = color."150";
        "tab.activeBackground" = color."150";
        "tab.inactiveBackground" = color."150";
        "titleBar.activeBackground" = color."150";
        "titleBar.inactiveBackground" = color."150";
        "statusBar.background" = color."150";
        "statusBar.noFolderBackground" = color."150";
        "statusBar.debuggingBackground" = color."150";
        "breadcrumb.background" = color."150";

        "editorWidget.background" = color."150";
        "input.background" = color."150";
        "dropdown.background" = color."150";
        "menu.background" = color."150";
        "notifications.background" = color."150";

        # borders (use solid main."200")
        "panel.border" = color."200";
        "sideBar.border" = color."200";
        "activityBar.border" = color."200";
        "editorGroup.border" = color."200";
        "editorGroupHeader.border" = color."200";
        "tab.border" = color."200";
        "titleBar.border" = color."200";
        "statusBar.border" = color."200";
        "editorWidget.border" = color."200";
        "dropdown.border" = color."200";
        "menu.border" = color."200";
        "notifications.border" = color."200";

        "focusBorder" = color."200";
        "contrastActiveBorder" = color."200";

        # sidebar section headers (e.g. “OPEN EDITORS”, “TIMELINE”, “OUTLINE”)
        "sideBarSectionHeader.background" = color."150";
        "sideBarSectionHeader.border" = color."200";

        # optional: tree views inside side bar (file explorer, outline, timeline rows)
        "tree.indentGuidesStroke" = color."200";
        "list.dropBackground" = color."200";
        "list.activeSelectionBackground" = color."200";
        "list.inactiveSelectionBackground" = color."200";

        # Activity Bar (left ribbon)
        "activityBar.foreground" = theme.color.wm800;
        "activityBar.inactiveForeground" = theme.color.app400;
        "activityBar.activeBorder" = theme.color.wm800; # thin highlight on the active icon
        "activityBarBadge.background" = theme.color.wm800; # badge (e.g., updates)
        "activityBarBadge.foreground" = theme.color.wm50; # badge text

        # existing highlights
        "editor.findMatchBackground" = "${color."800"}77";
        "editor.findMatchHighlightBackground" = "${color."800"}77";
        "editor.selectionBackground" = "${color."800"}55";
        "editor.selectionHighlightBackground" = "${color."800"}55";
        "editorError.background" = "#ff000049";
        "editorError.border" = "#ff0000";
        "editorRuler.foreground" = "#ffffff11";

        "editor.lineHighlightBackground" = color."200";
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
