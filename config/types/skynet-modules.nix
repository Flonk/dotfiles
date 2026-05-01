{
  imports = [
    # assorted
    ../../modules/assorted/avahi/options.nix
    ../../modules/assorted/chrome-remote-desktop/options.nix
    ../../modules/assorted/jiratui/options.nix
    ../../modules/assorted/nchat/options.nix

    # core
    ../../modules/core/bitwarden/options.nix
    ../../modules/core/direnv/options.nix
    ../../modules/core/git/options.nix
    ../../modules/core/keyring/options.nix
    ../../modules/core/skynet-scripts/options.nix
    ../../modules/core/sops/options.nix
    ../../modules/core/zsh/options.nix

    # desktop
    ../../modules/desktop/alacritty/options.nix
    ../../modules/desktop/audio/options.nix
    ../../modules/desktop/csvlens/options.nix
    ../../modules/desktop/fastfetch/options.nix
    ../../modules/desktop/foot/options.nix
    ../../modules/desktop/google-chrome/options.nix
    ../../modules/desktop/hyprland/options.nix
    ../../modules/desktop/mako/options.nix
    ../../modules/desktop/skynetshell/options.nix
    ../../modules/desktop/stylix/options.nix
    ../../modules/desktop/vicinae/options.nix
    ../../modules/desktop/vicinae-bitwarden/options.nix
    ../../modules/desktop/waybar/options.nix

    # development
    ../../modules/development/claude-code/options.nix
    ../../modules/development/dnsmasq/options.nix
    ../../modules/development/obsidian/options.nix
    ../../modules/development/qemu/options.nix
    ../../modules/development/vscode/options.nix
    ../../modules/development/zed-editor/options.nix

    # leisure
    ../../modules/leisure/gopro-webcam/options.nix
    ../../modules/leisure/minecraft/options.nix
    ../../modules/leisure/obs-studio/options.nix
    ../../modules/leisure/spotify/options.nix

    # os
    ../../modules/os/ipu6/options.nix
    ../../modules/os/network-scripts/options.nix
    ../../modules/os/powersaver/options.nix

    # projects
    ../../modules/projects/andamp/options.nix
    ../../modules/projects/personal/options.nix
  ];
}
