{

  pkgs,
  config,
  lib,
  inputs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.development.vscode.enable {
    programs.vscode = {
      enable = true;

      profiles.default.keybindings = [
        {
          key = "ctrl+y";
          command = "runCommands";
          args = {
            commands = [
              "git.openFile"
              "workbench.files.action.collapseExplorerFolders"
              "workbench.files.action.showActiveFileInExplorer"
            ];
          };
        }
        {
          key = "ctrl+shift+y";
          command = "runCommands";
          args = {
            commands = [
              "git.openFile"
              "workbench.action.editorLayoutSingle"
              "workbench.action.closeOtherEditors"
              "workbench.files.action.collapseExplorerFolders"
              "workbench.files.action.showActiveFileInExplorer"
            ];
          };
        }
        {
          key = "enter";
          command = "runCommands";
          args = {
            commands = [
              "workbench.action.acceptSelectedQuickOpenItem"
              "workbench.files.action.collapseExplorerFolders"
              "workbench.files.action.showActiveFileInExplorer"
            ];
          };
          when = "inQuickOpen";
        }
      ];

      profiles.default.userSettings = {
        "editor.fontFamily" = config.skynet.theme.fontFamily.mono;
        "editor.fontSize" = config.skynet.theme.fontSize.bigger;
        "window.zoomLevel" = -1;

        "workbench.colorTheme" = "Dainty – Nord (chroma 0, lightness 0)";
        "workbench.colorCustomizations" = {
          # backgrounds (all 150)
          "editor.background" = config.skynet.theme.color.app150;
          "terminal.background" = config.skynet.theme.color.app150;
          "peekViewEditor.background" = config.skynet.theme.color.app150;
          "editorGutter.background" = config.skynet.theme.color.app150;
          "editorPane.background" = config.skynet.theme.color.app150;

          "sideBar.background" = config.skynet.theme.color.app150;
          "activityBar.background" = config.skynet.theme.color.app150;
          "panel.background" = config.skynet.theme.color.app150;
          "editorGroupHeader.tabsBackground" = config.skynet.theme.color.app150;
          "tab.activeBackground" = config.skynet.theme.color.app150;
          "tab.inactiveBackground" = config.skynet.theme.color.app150;
          "titleBar.activeBackground" = config.skynet.theme.color.app150;
          "titleBar.inactiveBackground" = config.skynet.theme.color.app150;
          "statusBar.background" = config.skynet.theme.color.app150;
          "statusBar.noFolderBackground" = config.skynet.theme.color.app150;
          "statusBar.debuggingBackground" = config.skynet.theme.color.app150;
          "breadcrumb.background" = config.skynet.theme.color.app150;

          "editorWidget.background" = config.skynet.theme.color.app150;
          "input.background" = config.skynet.theme.color.app150;
          "dropdown.background" = config.skynet.theme.color.app150;
          "menu.background" = config.skynet.theme.color.app150;
          "notifications.background" = config.skynet.theme.color.app150;

          # borders (use solid main."200")
          "panel.border" = config.skynet.theme.color.app200;
          "sideBar.border" = config.skynet.theme.color.app200;
          "activityBar.border" = config.skynet.theme.color.app200;
          "editorGroup.border" = config.skynet.theme.color.app200;
          "editorGroupHeader.border" = config.skynet.theme.color.app200;
          "tab.border" = config.skynet.theme.color.app200;
          "titleBar.border" = config.skynet.theme.color.app200;
          "statusBar.border" = config.skynet.theme.color.app200;
          "editorWidget.border" = config.skynet.theme.color.app200;
          "dropdown.border" = config.skynet.theme.color.app200;
          "menu.border" = config.skynet.theme.color.app200;
          "notifications.border" = config.skynet.theme.color.app200;

          # sidebar section headers (e.g. “OPEN EDITORS”, “TIMELINE”, “OUTLINE”)
          "sideBarSectionHeader.background" = config.skynet.theme.color.app150;
          "sideBarSectionHeader.border" = config.skynet.theme.color.app200;

          # optional: tree views inside side bar (file explorer, outline, timeline rows)
          "tree.indentGuidesStroke" = "${config.skynet.theme.color.app300}44";
          "list.dropBackground" = config.skynet.theme.color.app200;
          "list.activeSelectionBackground" = config.skynet.theme.color.app200;
          "list.inactiveSelectionBackground" = config.skynet.theme.color.app200;
          "list.focusBackground" = config.skynet.theme.color.app200;
          "list.hoverBackground" = config.skynet.theme.color.app200;

          # Activity Bar (left ribbon)
          "activityBar.foreground" = config.skynet.theme.color.wm800;
          "activityBar.inactiveForeground" = config.skynet.theme.color.app400;
          "activityBarBadge.background" = config.skynet.theme.color.wm800; # badge (e.g., updates)
          "activityBarBadge.foreground" = config.skynet.theme.color.wm100; # badge text
          "activityBar.activeBorder" = "#00000000";
          "activityBar.activeFocusBorder" = "#00000000";

          # existing highlights
          "editor.findMatchBackground" = "${config.skynet.theme.color.wm900}77";
          "editor.findMatchHighlightBackground" = "${config.skynet.theme.color.wm900}77";
          "editor.selectionBackground" = "${config.skynet.theme.color.wm900}44";
          "editor.selectionHighlightBackground" = "${config.skynet.theme.color.wm900}44";
          "minimap.selectionHighlight" = "${config.skynet.theme.color.wm900}44";
          "minimap.findMatchHighlight" = "${config.skynet.theme.color.wm900}77";
          "minimap.findMatchHighlightForeground" = "${config.skynet.theme.color.wm900}22";

          "editorError.background" = "${config.skynet.theme.color.error600}49";
          "editorError.border" = "#ff0000";
          "editorRuler.foreground" = "#ffffff11";

          "minimap.errorHighlight" = "${config.skynet.theme.color.error600}aa";
          "minimap.warningHighlight" = "#ffaa00aa";
          "minimap.infoHighlight" = "#00aaffaa";

          "editor.lineHighlightBackground" = config.skynet.theme.color.app200;
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

        "chat.tools.autoApprove" = true;
        "chat.tools.terminal.autoApprove" = true;
        "chat.tools.browsing.autoApprove" = true;
        "chat.tools.global.autoApprove" = true;

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
  };
}
