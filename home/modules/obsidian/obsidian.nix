{
  pkgs,
  config,
  lib,
  ...
}:
let
  c = config.theme.color;
  fs = config.theme.fontSize;
  ff = config.theme.fontFamily;
  floBaseCss = ''
    :root {
      /* Fonts */
      --font-interface: "${ff.ui}", system-ui, sans-serif;
      --font-text: "${ff.ui}", system-ui, sans-serif;
      --font-monospace: "${ff.mono}", ui-monospace, monospace;

      /* Surfaces */
      --background-primary:  ${c.app150};   /* editor bg */
      --background-secondary: ${c.app200};  /* sidebars */
      --background-modifier-hover: ${c.app200};
      --background-modifier-border: ${c.app200};

      /* Text */
      --text-normal:  ${c.wm800};
      --text-muted:   ${c.app600};
      --text-accent:  ${c.text};

      /* Sizing */
      --h1-size: ${toString fs.huge}px;
      --h2-size: ${toString fs.bigger}px;
      --h3-size: ${toString fs.big}px;
      --font-text-size: ${toString fs.normal}px;   /* editor body */
      --line-height-normal: 1.6;

      /* Interactive */
      --interactive-normal: ${c.app200};
      --interactive-hover: ${c.app250};
      --interactive-accent: ${c.wm800};
      --interactive-accent-hover: ${c.wm800};
    }

    /* Optional: preview/reader polish */
    .markdown-preview-view {
      max-width: 78ch;
    }
  '';
in
{
  programs.obsidian = {
    enable = true;
    package = pkgs.obsidian;
  };
  # Provide a theme-colored CSS snippet for Obsidian.
  # Enable it in Obsidian: Settings → Appearance → CSS snippets → toggle "flo-base".
  xdg.configFile."obsidian/snippets/flo-base.css".text = floBaseCss;
}
