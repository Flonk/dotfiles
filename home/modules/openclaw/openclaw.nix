{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.home.openclaw {
    sops.secrets.discord_bot_token = {
      key = "discord_bot_token";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    programs.openclaw = {
      enable = true;

      config = {
        gateway = {
          mode = "local";
          auth.token = "openclaw-local-gateway";
        };

        # Use a local ollama model (no API key required)
        models.providers = {
          ollama-local = {
            api = "ollama";
            baseUrl = "http://localhost:11434";
            models = [
              {
                name = "llama3.2";
                id = "llama3.2";
              }
            ];
          };
        };

        channels.discord = {
          # Placeholder replaced at activation time by the script below
          token = "DISCORD_BOT_TOKEN_PLACEHOLDER";
          allowFrom = [ config.skynet.discordId ];
        };
      };
    };

    # Patch the placeholder with the real token from the sops-managed secret
    # Runs after openclaw writes ~/.openclaw/openclaw.json
    home.activation.openclawInjectDiscordToken = lib.hm.dag.entryAfter [ "openclawConfigFiles" ] ''
      _token_file="${config.sops.secrets.discord_bot_token.path}"
      _config_file="${config.programs.openclaw.stateDir}/openclaw.json"
      _runtime_config="${config.programs.openclaw.stateDir}/openclaw-runtime.json"
      if [ -f "$_token_file" ] && [ -f "$_config_file" ]; then
        _token=$(cat "$_token_file")
        $DRY_RUN_CMD ${pkgs.gnused}/bin/sed \
          "s|DISCORD_BOT_TOKEN_PLACEHOLDER|$_token|g" \
          "$_config_file" > "$_runtime_config"
      fi
    '';

    # Point the service at the patched runtime copy
    systemd.user.services.openclaw-gateway = lib.mkIf config.programs.openclaw.systemd.enable {
      Service.Environment = lib.mkForce [
        "HOME=${config.home.homeDirectory}"
        "OPENCLAW_CONFIG_PATH=${config.programs.openclaw.stateDir}/openclaw-runtime.json"
        "OPENCLAW_STATE_DIR=${config.programs.openclaw.stateDir}"
        "OPENCLAW_NIX_MODE=1"
      ];
    };
  };
}
