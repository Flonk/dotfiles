{
  pkgs,
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.jiratui.enable {
    home.packages = with pkgs; [
      jiratui
    ];

    sops.secrets.jira_api_username = {
      key = "jira_api_username";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    sops.secrets.jira_api_token = {
      key = "jira_api_token";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    sops.secrets.jira_api_base_url = {
      key = "jira_api_base_url";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    home.activation.writeJiratuiConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p ${config.xdg.configHome}/jiratui
      $DRY_RUN_CMD cat > ${config.xdg.configHome}/jiratui/config.yaml <<EOF
      jira_api_username: $(cat ${config.sops.secrets.jira_api_username.path})
      jira_api_token: $(cat ${config.sops.secrets.jira_api_token.path})
      jira_api_base_url: $(cat ${config.sops.secrets.jira_api_base_url.path})
      EOF
    '';

    programs.zsh.shellAliases.jira = "jiratui ui";

    xdg.desktopEntries.jiratui = {
      name = "Jira";
      comment = "Terminal UI for Jira";
      exec = "foot jiratui ui";
      icon = "jira";
      categories = [
        "Development"
        "Utility"
      ];
      terminal = false;
    };
  };
}
