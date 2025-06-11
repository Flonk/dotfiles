let 
  primaryColor = "#ff2a00";
  backgroundColor = "#000000";
in {
  colors = {
    primary = primaryColor;
    background = backgroundColor;

    priority = {
      low = "#cccccc";
      normal = primaryColor;
      urgent = "#ff0000";
    };
  };

  fonts = {
    ui   = "monospace 10";
    mono = "monospace 10";
  };
}

