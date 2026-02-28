{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.skynet.module.openclaw.enable {
    sops.secrets.discord_bot_token = {
      key = "discord_bot_token";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    sops.secrets.anthropic_api_key = {
      key = "anthropic_api_key";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    sops.secrets.openrouter_api_key = {
      key = "openrouter_api_key";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    sops.secrets.whatsapp_phone_number = {
      key = "whatsapp_phone_number";
      sopsFile = ../../../assets/secrets/secrets.json;
    };

    programs.openclaw = {
      enable = true;

      config = {
        agents.defaults = {
          # Main model: Sonnet with fallback chain across providers
          model = {
            primary = "anthropic/claude-haiku-4-5";
            fallbacks = [
              "openrouter/google/gemini-3-flash-preview"
              "openrouter/deepseek/deepseek-r1"
            ];
          };

          # Image analysis: Gemini Flash (cheap, fast, capable)
          imageModel = {
            primary = "openrouter/google/gemini-3-flash-preview";
            fallbacks = [ "anthropic/claude-haiku-4-5" ];
          };

          # Named model aliases for /model switching
          models = {
            "anthropic/claude-haiku-4-5" = {
              alias = "haiku";
            };
            "anthropic/claude-sonnet-4-6" = {
              alias = "sonnet";
            };
            "anthropic/claude-opus-4-6" = {
              alias = "opus";
            };
            "openrouter/google/gemini-3-flash-preview" = {
              alias = "flash";
            };
            "openrouter/deepseek/deepseek-r1" = {
              alias = "r1";
            };
          };

          # Heartbeats use the cheapest model — no intelligence needed
          heartbeat = {
            every = "30m";
            model = "openrouter/google/gemini-2.5-flash-lite";
            activeHours = {
              start = "08:00";
              end = "23:00";
              timezone = "Europe/Vienna";
            };
            target = "last";
          };

          # Sub-agents: Haiku — good reasoning, 10x cheaper than Sonnet
          subagents = {
            model = "anthropic/claude-haiku-4-5";
            maxConcurrent = 3;
            archiveAfterMinutes = 60;
          };

          workspace = "/home/flo/.openclaw/workspace";
          compaction = {
            mode = "safeguard";
          };
        };

        commands = {
          native = "auto";
          nativeSkills = "auto";
        };

        gateway = {
          mode = "local";
          auth.token = "openclaw-local-gateway";
        };

        # Browser: Chrome extension relay
        browser.profiles."my-chrome" = {
          cdpUrl = "http://127.0.0.1:18792";
          driver = "extension";
          color = "#00AA00";
        };

        models.providers = {
          anthropic = {
            api = "anthropic-messages";
            baseUrl = "https://api.anthropic.com";
            # Placeholder replaced at activation time by the script below
            apiKey = "ANTHROPIC_API_KEY_PLACEHOLDER";
            models = [
              {
                name = "claude-haiku-4-5";
                id = "claude-haiku-4-5";
              }
              {
                name = "claude-sonnet-4-6";
                id = "claude-sonnet-4-6";
              }
              {
                name = "claude-opus-4-6";
                id = "claude-opus-4-6";
              }
            ];
          };

          openrouter = {
            api = "openai-completions";
            baseUrl = "https://openrouter.ai/api/v1";
            # Placeholder replaced at activation time by the script below
            apiKey = "OPENROUTER_API_KEY_PLACEHOLDER";
            models = [
              {
                name = "gemini-2.5-flash-lite";
                id = "google/gemini-2.5-flash-lite";
              }
              {
                name = "gemini-3-flash-preview";
                id = "google/gemini-3-flash-preview";
              }
              {
                name = "deepseek-r1";
                id = "deepseek/deepseek-r1";
              }
            ];
          };
        };

        channels.discord = {
          # Placeholder replaced at activation time by the script below
          token = "DISCORD_BOT_TOKEN_PLACEHOLDER";
          allowFrom = [ config.skynet.discordId ];
        };

        channels.whatsapp = {
          accounts = {
            main = {
              allowFrom = [ "WHATSAPP_PHONE_NUMBER_PLACEHOLDER" ];
              dmPolicy = "allowlist";
              selfChatMode = true;
            };
          };
        };

        plugins.entries = {
          whatsapp = {
            enabled = true;
          };
          discord = {
            enabled = true;
          };
        };
      };
    };

    # Allow HM to overwrite the openclaw config symlink when it changes between generations
    home.file.".openclaw/openclaw.json".force = lib.mkForce true;

    # Patch placeholders with real secrets from sops-managed files
    # Runs after openclaw writes ~/.openclaw/openclaw.json
    home.activation.openclawInjectSecrets =
      lib.hm.dag.entryAfter [ "openclawConfigFiles" "sops-nix" ]
        ''
          _discord_token_file="${config.sops.secrets.discord_bot_token.path}"
          _anthropic_key_file="${config.sops.secrets.anthropic_api_key.path}"
          _openrouter_key_file="${config.sops.secrets.openrouter_api_key.path}"
          _whatsapp_phone_file="${config.sops.secrets.whatsapp_phone_number.path}"
          _config_file="${config.programs.openclaw.stateDir}/openclaw.json"
          _runtime_config="${config.programs.openclaw.stateDir}/openclaw-runtime.json"
          if [ -f "$_discord_token_file" ] && [ -f "$_anthropic_key_file" ] && [ -f "$_openrouter_key_file" ] && [ -f "$_whatsapp_phone_file" ] && [ -f "$_config_file" ]; then
            _discord_token=$(${pkgs.coreutils}/bin/cat "$_discord_token_file")
            _anthropic_key=$(${pkgs.coreutils}/bin/cat "$_anthropic_key_file")
            _openrouter_key=$(${pkgs.coreutils}/bin/cat "$_openrouter_key_file")
            _whatsapp_phone=$(${pkgs.coreutils}/bin/cat "$_whatsapp_phone_file")
            $DRY_RUN_CMD ${pkgs.gnused}/bin/sed \
              "s|DISCORD_BOT_TOKEN_PLACEHOLDER|$_discord_token|g;s|ANTHROPIC_API_KEY_PLACEHOLDER|$_anthropic_key|g;s|OPENROUTER_API_KEY_PLACEHOLDER|$_openrouter_key|g;s|WHATSAPP_PHONE_NUMBER_PLACEHOLDER|$_whatsapp_phone|g" \
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
