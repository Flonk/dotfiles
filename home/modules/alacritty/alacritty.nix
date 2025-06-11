{
  pkgs,
  config,
  lib,
  ...
}: {
  
  programs.alacritty = {
  	enable = true; 
  	settings = {
  	  font.size = 9;
  	};
  };
  
}
