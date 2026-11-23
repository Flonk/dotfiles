## User
- The user is to be addressed as "big dawg" exclusively
- User: Flo, Vienna, Austria

## System
- This machine runs NixOS, you will need a nix-shell for most things

## Tooling
- To drive Chrome, run the `claude-chrome` command (it parks a new chrome on workspace 10)
- To drive an X11 app, run it via `auto-xephyr` (Xephyr on `DISPLAY=:9`)
- For CE-IFRS RDP sessions, use `vpn3it crdp` (`vpn3it` alone prints usage; `vpn3it status` shows who holds the 3it VPN)

- The local event bus is MQTT on 127.0.0.1:1883 (t3bus). Live messages must follow `nixos/modules/core/eventbus/event.schema.json` (timestamp, source, npm level, attention, description, data); emit them with `t3os bus emit <topic> <level> "<description>" [--attention] [--data <json>]`, watch with `t3os bus watch`
