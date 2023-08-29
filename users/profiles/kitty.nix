{
  programs.kitty = {
    enable = true;
    font = {
      name = "monospace";
      size = 9.0;
    };
    theme = "One Dark";
    shellIntegration.enableFishIntegration = true;
    settings = {
      cursor_shape = "block";
      scrollback_lines = 10000;
    };
  };
}
