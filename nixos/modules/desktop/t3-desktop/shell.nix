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
    (python3.withPackages (p: [ p.numpy p.pillow ]))
    qemu
    qt6.qtshadertools
    quickshell
    tmux
    watchexec
    xorriso
  ];

  T3_DESKTOP_DEJAVU = "${pkgs.dejavu_fonts}/share/fonts/truetype";
}
