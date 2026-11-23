---
name: doubletunnel
description: Connect, disconnect or check the 3it VPN (doubletunnel) on this host. Use when Flo asks to connect/disconnect 3it, start/stop the doubletunnel, boot or free the VPN, or asks whether the VPN is up or who holds it.
---

# doubletunnel

The 3it VPN allows one session at a time. chonkler (Flo's work laptop) has priority: if chonkler connects, this host is kicked off automatically. Only use the `vpn3it` commands below. Never run openvpn, openconnect, `vpn3it doubletunnel run` or `sudo pkill` yourself.

## Check status

1. Run `vpn3it status`.
2. Report its lines to Flo exactly as printed.

## Connect

1. Run `vpn3it status`.
2. If it says "chonkler holds 3it": stop. Tell Flo chonkler holds the VPN. Do not connect.
3. If it says "this host: connected": tell Flo it is already connected. Stop.
4. You need Flo's current Authy token (6 digits). If Flo did not give you one in this message, ask for it and stop. Never guess or reuse an old token.
5. Run `vpn3it doubletunnel up <token>` with a 180 second timeout. It waits until the VPN is up.
6. If it prints "connected through andamp": tell Flo the VPN is up.
7. If it prints an error: show Flo the error and log lines exactly. Do not retry, a token only works once.

## Disconnect

1. Run `vpn3it doubletunnel down`.
2. Tell Flo what it printed ("disconnected", "already disconnected", or the error).

## Something looks wrong

1. Run `vpn3it doubletunnel log`.
2. Show Flo the output. Do not try to fix it yourself.
