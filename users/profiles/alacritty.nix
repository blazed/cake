{
  programs.alacritty = {
    enable = true;
    settings = {
      env = {
        TERM = "alacritty";
      };
      window = {
        dimensions.columns = 80;
        dimensions.lines = 24;
        padding.x = 2;
        padding.y = 2;
        dynamic_padding = false;
        opacity = 1.0;
      };
      scrolling = {
        history = 10000;
        multiplier = 3;
      };
      colors = {
        draw_bold_text_with_bright_colors = true;
      };
      font = {
        normal.family = "JetBrainsMono Nerd Font Mono";
        size = 10.0;
        offset.x = 0;
        offset.y = 0;
        glyph_offset.x = 0;
        glyph_offset.y = 0;
      };
      mouse.hide_when_typing = true;
      cursor = {
        style.blinking = "Never";
        unfocused_hollow = true;
      };
    };
  };
}
