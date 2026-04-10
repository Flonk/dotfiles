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
        "editor.fontFamily" = lib.mkDefault config.stylix.fonts.monospace.name;
        "editor.fontSize" = lib.mkDefault config.skynet.module.desktop.stylix.fontSizePx;
        "window.zoomLevel" = -1;

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
        "editor.rulers" = [
          65
          80
          120
        ];
      };
    };
  };
}
