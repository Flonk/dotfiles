{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Build node_modules from package.json
  nodeModules = pkgs.buildNpmPackage {
    pname = "skynet-scripts-deps";
    version = "1.0.0";
    src = ./.;
    npmDepsHash = "sha256-aINlEcFIuu0QW+hgsZF2gyj3EuK1+j5Am5IqZm7zjZg=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # Collect scripts from modules based on hostconfig flags
  scriptsDir = pkgs.runCommand "skynet-scripts" { } ''
    mkdir -p $out

    # Copy global package.json
    cp ${./package.json} $out/package.json

    # Copy node_modules
    cp -r ${nodeModules}/node_modules $out/

    # Conditionally copy scripts based on enabled modules
    ${lib.optionalString config.skynet.module.system.fingerprint ''
      cp ${../../../nixos/modules/fingerprint/skynet-scripts/enroll-fingerprints.ts} $out/enroll-fingerprints.ts
    ''}
  '';

  # Create wrapper scripts that run via tsx from ~/.skynet/scripts
  mkScript =
    name:
    pkgs.writeShellScriptBin name ''
      cd ~/.skynet/scripts
      exec ./node_modules/.bin/tsx ${name}.ts "$@"
    '';

  # List of scripts to create wrappers for (based on enabled modules)
  scriptWrappers = lib.flatten [
    (lib.optional config.skynet.module.system.fingerprint (mkScript "enroll-fingerprints"))
  ];
in
{
  config = lib.mkIf config.skynet.module.home.skynet-scripts {
    # Symlink the scripts directory to ~/.skynet/scripts
    home.file.".skynet/scripts".source = scriptsDir;

    # Add wrapper scripts to PATH
    home.packages = scriptWrappers;
  };
}
