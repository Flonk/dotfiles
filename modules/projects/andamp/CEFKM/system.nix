{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.skynet.module.projects.andamp.CEFKM {
    security.pki.certificateFiles = [
      ./certs/ROOTCA2020.crt
      ./certs/obk-dev.crt
      ./certs/obk-int-server.crt
    ];
  };
}
