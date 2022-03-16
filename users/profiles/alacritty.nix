{
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "alacritty";
      };
      window = {
        dimensions.columns = 0;
        dimensions.lines = 0;
        padding.x = 0;
        padding.y = 2;
        dynamic_padding = false;
        decorations = "full";
        startup_mode = "Windowed";
        opacity = 1.0;
      };
      scrolling = {
        history = 10000;
        multiplier = 3;
      };
      draw_bold_text_with_bright_colors = true;
      font = {
        normal.family = "monospace";
        size = 9.0;
        offset.x = 0;
        offset.y = 0;
        glyph_offset.x = 0;
        glyph_offset.y = 0;
        use_thin_strokes = true;
      };
      mouse.hide_when_typing = true;
    };
  };
}
