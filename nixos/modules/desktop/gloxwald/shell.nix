{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    go
    grub2
    imagemagick
    jq
    just
    mtools
    OVMF.fd
    python3
    qemu
    qt6.qtshadertools
    quickshell
    tmux
    watchexec
    xorriso
  ];

  GLOXWALD_DEJAVU = "${pkgs.dejavu_fonts}/share/fonts/truetype";
}
