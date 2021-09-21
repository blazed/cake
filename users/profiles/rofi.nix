{
  programs.rofi = {
    enable = true;
    font = "monofur 13";
    lines = 5;
    padding = 5;
    scrollbar = false;
    separator = "solid";
    borderWidth = 1;

    colors = {
      window = {
        background = "#2f2f38";
        border = "#688486";
        separator = "#688486";
      };
      rows = {
        normal = {
          background = "#2f2f38";
          foreground = "#688486";
          backgroundAlt = "#2f2f38";
          highlight = {
            background = "#2f2f38";
            foreground = "#cfd2cf";
          };
        };
        active = {
          background = "#2f2f38";
          foreground = "#688486";
          backgroundAlt = "#2f2f38";
          highlight = {
            background = "#2f2f38";
            foreground = "#cfd2cf";
          };
        };
        urgent = {
          background = "#2f2f38";
          foreground = "#688486";
          backgroundAlt = "#2f2f38";
          highlight = {
            background = "#2f2f38";
            foreground = "#cfd2cf";
          };
        };
      };
    };
  };
}
