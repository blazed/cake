{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        font = "Monospace 9";
        markup = "yes";
        plain_text = "no";
        format = "<b>%s</b>\\n%b";
        sort = "no";
        indicate_hidden = "yes";
        alignment = "center";
        bounce_freq = 0;
        show_age_threshold = -1;
        word_wrap = "yes";
        ignore_newline = "no";
        stack_duplicates = "yes";
        hide_deplicates_count = "yes";
        geometry = "300x50-15+49";
        shrink = "no";
        transparency = 5;
        ide_threshold = 0;
        monitor = 0;
        follow = "none";
        stick_history = "yes";
        history_length = 15;
        show_indicators = "no";
        line_height = 3;
        separator_height = 2;
        padding = 6;
        horizontal_padding = 6;
        separator_color = "frame";
        startup_notification = false;
        icon_position = "off";
        max_icon_size = 80;
        frame_width = 3;
        frame_color = "#8EC07C";
      };

      shortcuts = {
        close = "mod4+m";
        close_all = "mod4+shift+m";
        history = "mod4+n";
        context = "mod4+shift+i";
      };

      urgency_low = {
        frame_color = "#3B7C87";
        foreground = "#3B7C87";
        background = "#191311";
        timeout = 3;
      };

      urgency_normal = {
        frame_color = "#5B8234";
        foreground = "#5B8234";
        background = "#191311";
        timeout = 5;
      };

      urgency_critical = {
        frame_color = "#B7472A";
        foreground = "#B7472A";
        background = "#191311";
        timeout = 0;
      };
    };
  };
}
