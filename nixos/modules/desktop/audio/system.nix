{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.skynet.module.desktop.audio;
in
{
  config = lib.mkIf cfg.enable {
    services.pipewire.wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-output-priority.conf" ''
        monitor.alsa.rules = [
          {
            matches = [{ device.name = "~alsa_card.pci-*" }]
            actions = {
              update-props = {
                # Keep the duplex profile when headphones are plugged in
                # so the internal mic stays available
                "api.acp.auto-profile" = false
              }
            }
          }
          {
            matches = [{ node.name = "~alsa_output.*Headphones.*" }]
            actions = {
              update-props = {
                "priority.driver" = 2000
                "priority.session" = 2000
              }
            }
          }
          {
            matches = [{ node.name = "~alsa_output.*Speaker.*" }]
            actions = {
              update-props = {
                "priority.driver" = 1900
                "priority.session" = 1900
              }
            }
          }
          {
            matches = [{ node.name = "~alsa_input.*" }]
            actions = {
              update-props = {
                "priority.driver" = 2000
                "priority.session" = 2000
              }
            }
          }
        ]

        monitor.bluez.rules = [
          {
            matches = [{ node.name = "~bluez_output.*" }]
            actions = {
              update-props = {
                "priority.driver" = 2100
                "priority.session" = 2100
              }
            }
          }
          {
            matches = [{ node.name = "~bluez_input.*" }]
            actions = {
              update-props = {
                "priority.driver" = 100
                "priority.session" = 100
              }
            }
          }
        ]
      '')
    ];
  };
}
