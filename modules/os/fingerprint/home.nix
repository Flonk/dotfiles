{
  config,
  lib,
  ...
}:

{
  config = lib.mkIf config.skynet.module.os.fingerprint.enable {
    # Register skynet CLI scripts
    skynet.cli.scripts = [
      {
        command = [
          "fingerprint"
          "enroll"
        ];
        title = "Set up the fingerprint reader";
        script = ./skynet-scripts/enroll-fingerprints.ts;
        usage = "Launches an interactive wizard to enroll one or more fingerprints using fprintd.";
      }
    ];
  };
}
