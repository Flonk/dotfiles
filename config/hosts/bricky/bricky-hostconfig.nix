{ ... }:
{
  config.skynet = {
    host = {
      adminUser = "bricky";
      motd.command = "printf '%b' '\\033[38;5;208m┏┓ ┏━┓╻┏━╸╻┏ ╻ ╻\\n┣┻┓┣┳┛┃┃  ┣┻┓┗┳┛\\n┗━┛╹┗╸╹┗━╸╹ ╹ ╹\\033[94m    NixOS-WSL powered by Skynet.\\033[0m\\n'";
    };

    module = { };
  };
}
