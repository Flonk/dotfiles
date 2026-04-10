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
          "editor.background" = config.skynet.theme.color.app150.hex;
          "terminal.background" = config.skynet.theme.color.app150.hex;
          "peekViewEditor.background" = config.skynet.theme.color.app150.hex;
          "editorGutter.background" = config.skynet.theme.color.app150.hex;
          "editorPane.background" = config.skynet.theme.color.app150.hex;

          "sideBar.background" = config.skynet.theme.color.app150.hex;
          "activityBar.background" = config.skynet.theme.color.app150.hex;
          "panel.background" = config.skynet.theme.color.app150.hex;
          "editorGroupHeader.tabsBackground" = config.skynet.theme.color.app150.hex;
          "tab.activeBackground" = config.skynet.theme.color.app150.hex;
          "tab.inactiveBackground" = config.skynet.theme.color.app150.hex;
          "titleBar.activeBackground" = config.skynet.theme.color.app150.hex;
          "titleBar.inactiveBackground" = config.skynet.theme.color.app150.hex;
          "statusBar.background" = config.skynet.theme.color.app150.hex;
          "statusBar.noFolderBackground" = config.skynet.theme.color.app150.hex;
          "statusBar.debuggingBackground" = config.skynet.theme.color.app150.hex;
          "breadcrumb.background" = config.skynet.theme.color.app150.hex;

          "editorWidget.background" = config.skynet.theme.color.app150.hex;
          "input.background" = config.skynet.theme.color.app150.hex;
          "dropdown.background" = config.skynet.theme.color.app150.hex;
          "menu.background" = config.skynet.theme.color.app150.hex;
          "notifications.background" = config.skynet.theme.color.app150.hex;

          # borders (use solid main."200")
          "panel.border" = config.skynet.theme.color.app200.hex;
          "sideBar.border" = config.skynet.theme.color.app200.hex;
          "activityBar.border" = config.skynet.theme.color.app200.hex;
          "editorGroup.border" = config.skynet.theme.color.app200.hex;
          "editorGroupHeader.border" = config.skynet.theme.color.app200.hex;
          "tab.border" = config.skynet.theme.color.app200.hex;
          "titleBar.border" = config.skynet.theme.color.app200.hex;
          "statusBar.border" = config.skynet.theme.color.app200.hex;
          "editorWidget.border" = config.skynet.theme.color.app200.hex;
          "dropdown.border" = config.skynet.theme.color.app200.hex;
          "menu.border" = config.skynet.theme.color.app200.hex;
          "notifications.border" = config.skynet.theme.color.app200.hex;

          # sidebar section headers (e.g. “OPEN EDITORS”, “TIMELINE”, “OUTLINE”)
          "sideBarSectionHeader.background" = config.skynet.theme.color.app150.hex;
          "sideBarSectionHeader.border" = config.skynet.theme.color.app200.hex;

          # optional: tree views inside side bar (file explorer, outline, timeline rows)
          "tree.indentGuidesStroke" = "${config.skynet.theme.color.app400.hex}44";
          "list.dropBackground" = config.skynet.theme.color.app200.hex;
          "list.activeSelectionBackground" = config.skynet.theme.color.app200.hex;
          "list.inactiveSelectionBackground" = config.skynet.theme.color.app200.hex;
          "list.focusBackground" = config.skynet.theme.color.app200.hex;
          "list.hoverBackground" = config.skynet.theme.color.app200.hex;

          # Activity Bar (left ribbon)
          "activityBar.foreground" = config.skynet.theme.color.wm800.hex;
          "activityBar.inactiveForeground" = config.skynet.theme.color.app400.hex;
          "activityBarBadge.background" = config.skynet.theme.color.wm800.hex; # badge (e.g., updates)
          "activityBarBadge.foreground" = config.skynet.theme.color.wm100.hex; # badge text
          "activityBar.activeBorder" = "#00000000";
          "activityBar.activeFocusBorder" = "#00000000";

          # existing highlights
          "editor.findMatchBackground" = "${config.skynet.theme.color.wm900.hex}77";
          "editor.findMatchHighlightBackground" = "${config.skynet.theme.color.wm900.hex}77";
          "editor.selectionBackground" = "${config.skynet.theme.color.wm900.hex}44";
          "editor.selectionHighlightBackground" = "${config.skynet.theme.color.wm900.hex}44";
          "minimap.selectionHighlight" = "${config.skynet.theme.color.wm900.hex}44";
          "minimap.findMatchHighlight" = "${config.skynet.theme.color.wm900.hex}77";
          "minimap.findMatchHighlightForeground" = "${config.skynet.theme.color.wm900.hex}22";

          "editorError.background" = "${config.skynet.theme.color.error600.hex}49";
          "editorError.border" = "#ff0000";
          "editorRuler.foreground" = "#ffffff11";

          "minimap.errorHighlight" = "${config.skynet.theme.color.error600.hex}aa";
          "minimap.warningHighlight" = "#ffaa00aa";
          "minimap.infoHighlight" = "#00aaffaa";

          "editor.lineHighlightBackground" = config.skynet.theme.color.app200.hex;
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
        "[csharp]" = {
          "editor.defaultFormatter" = "csharpier.csharpier-vscode";
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
