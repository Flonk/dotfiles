{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
}:
rustPlatform.buildRustPackage rec {
  pname = "zeroclaw";
  version = "0.1.9";

  src = fetchFromGitHub {
    owner = "zeroclaw-labs";
    repo = "zeroclaw";
    rev = "744620bc3464732395b0b0e4f0f0bde0d2848ff6";
    hash = "sha256-FwWFbolE+2BsGYSW12VipRdGg3HfQRL0yBpXrOinMAs=";
  };

  cargoHash = "sha256-CcldFjukQfC2CGbeNOkYnxnW5iGHECcI35/OOL2TgF4=";
  cargoAuditable = false;

  CARGO_BUILD_JOBS = "1";
  CARGO_PROFILE_RELEASE_LTO = "off";
  CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
  CARGO_PROFILE_RELEASE_OPT_LEVEL = "2";

  nativeBuildInputs = [
    pkg-config
  ];

  doCheck = false;

  meta = {
    description = "Zero overhead. Zero compromise. 100% Rust AI assistant";
    homepage = "https://github.com/zeroclaw-labs/zeroclaw";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "zeroclaw";
    platforms = lib.platforms.linux;
  };
}
