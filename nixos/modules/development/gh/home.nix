{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.t3os.module.development.gh.enable {
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings.git_protocol = "https";
    };
  };
}
