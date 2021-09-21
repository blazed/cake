{
  programs.alacritty = {
    enable = true;
    settings = rec {
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
      background_opacity = 1.0;
      mouse.hide_when_typing = true;

      colors = {
        primary.background = "0x1d2021";
        primary.foreground = "0xd5c4a1";
        cursor.text = "0x1d2021";
        cursor.cursor = "0xd5c4a1";
        normal = {
          black = "0x1d2021";
          red = "0xfb4934";
          green = "0xb8bb26";
          yellow = "0xfabd2f";
          blue = "0x83a598";
          magenta = "0xd3869b";
          cyan = "0x8ec07c";
          white = "0xd5c4a1";
        };

        bright = {
          black = "0x665c54";
          red = "0xfb4934";
          green = "0xb8bb26";
          yellow = "0xfabd2f";
          blue = "0x83a598";
          magenta = "0xd3869b";
          cyan = "0x8ec07c";
          white = "0xfbf1c7";
        };
      };
    };
  };
}
