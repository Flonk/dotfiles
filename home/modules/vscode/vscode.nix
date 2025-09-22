{

  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  programs.vscode = {
    enable = true;

    profiles.default.userSettings = {
      "editor.fontFamily" = config.theme.fontFamily.mono;
      "editor.fontSize" = config.theme.fontSize.bigger;
      "window.zoomLevel" = -1;

      "workbench.colorTheme" = "Dainty – Nord (chroma 0, lightness 0)";
      "workbench.colorCustomizations" = {
        # backgrounds (all 150)
        "editor.background" = config.theme.color.app150;
        "terminal.background" = config.theme.color.app150;
        "peekViewEditor.background" = config.theme.color.app150;
        "editorGutter.background" = config.theme.color.app150;
        "editorPane.background" = config.theme.color.app150;

        "sideBar.background" = config.theme.color.app150;
        "activityBar.background" = config.theme.color.app150;
        "panel.background" = config.theme.color.app150;
        "editorGroupHeader.tabsBackground" = config.theme.color.app150;
        "tab.activeBackground" = config.theme.color.app150;
        "tab.inactiveBackground" = config.theme.color.app150;
        "titleBar.activeBackground" = config.theme.color.app150;
        "titleBar.inactiveBackground" = config.theme.color.app150;
        "statusBar.background" = config.theme.color.app150;
        "statusBar.noFolderBackground" = config.theme.color.app150;
        "statusBar.debuggingBackground" = config.theme.color.app150;
        "breadcrumb.background" = config.theme.color.app150;

        "editorWidget.background" = config.theme.color.app150;
        "input.background" = config.theme.color.app150;
        "dropdown.background" = config.theme.color.app150;
        "menu.background" = config.theme.color.app150;
        "notifications.background" = config.theme.color.app150;

        # borders (use solid main."200")
        "panel.border" = config.theme.color.app200;
        "sideBar.border" = config.theme.color.app200;
        "activityBar.border" = config.theme.color.app200;
        "editorGroup.border" = config.theme.color.app200;
        "editorGroupHeader.border" = config.theme.color.app200;
        "tab.border" = config.theme.color.app200;
        "titleBar.border" = config.theme.color.app200;
        "statusBar.border" = config.theme.color.app200;
        "editorWidget.border" = config.theme.color.app200;
        "dropdown.border" = config.theme.color.app200;
        "menu.border" = config.theme.color.app200;
        "notifications.border" = config.theme.color.app200;

        # sidebar section headers (e.g. “OPEN EDITORS”, “TIMELINE”, “OUTLINE”)
        "sideBarSectionHeader.background" = config.theme.color.app150;
        "sideBarSectionHeader.border" = config.theme.color.app200;

        # optional: tree views inside side bar (file explorer, outline, timeline rows)
        "tree.indentGuidesStroke" = "${config.theme.color.app300}44";
        "list.dropBackground" = config.theme.color.app200;
        "list.activeSelectionBackground" = config.theme.color.app200;
        "list.inactiveSelectionBackground" = config.theme.color.app200;
        "list.focusBackground" = config.theme.color.app200;
        "list.hoverBackground" = config.theme.color.app200;

        # Activity Bar (left ribbon)
        "activityBar.foreground" = config.theme.color.wm800;
        "activityBar.inactiveForeground" = config.theme.color.app400;
        "activityBarBadge.background" = config.theme.color.wm800; # badge (e.g., updates)
        "activityBarBadge.foreground" = config.theme.color.wm100; # badge text
        "activityBar.activeBorder" = "#00000000";
        "activityBar.activeFocusBorder" = "#00000000";

        # existing highlights
        "editor.findMatchBackground" = "${config.theme.color.wm800}77";
        "editor.findMatchHighlightBackground" = "${config.theme.color.wm800}77";
        "editor.selectionBackground" = "${config.theme.color.wm800}33";
        "editor.selectionHighlightBackground" = "${config.theme.color.wm800}33";
        "minimap.selectionHighlight" = "${config.theme.color.wm800}33";
        "minimap.findMatchHighlight" = "${config.theme.color.wm800}77";
        "minimap.findMatchHighlightForeground" = "${config.theme.color.wm800}22";

        "editorError.background" = "${config.theme.color.error600}49";
        "editorError.border" = "#ff0000";
        "editorRuler.foreground" = "#ffffff11";

        "minimap.errorHighlight" = "${config.theme.color.error600}aa";
        "minimap.warningHighlight" = "#ffaa00aa";
        "minimap.infoHighlight" = "#00aaffaa";

        "editor.lineHighlightBackground" = config.theme.color.app200;
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
