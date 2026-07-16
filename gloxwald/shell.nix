{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    go_1_25
    grub2
    imagemagick
    just
    mtools
    OVMF.fd
    python3
    qemu
    qt6.qtshadertools
    quickshell
    watchexec
    xorriso
  ];
}
