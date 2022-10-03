{
  programs.i3status-rust = {
    enable = true;
    bars.default = {
      icons = "solarized-dark";
      theme = "awesome5";
      blocks = [
        {
          block = "disk_space";
          path = "/keep";
          alias = "/";
          info_type = "available";
          unit = "GB";
          interval = 60;
          warning = 20.0;
          alert = 10.0;
        }
        {
          block = "memory";
          display_type = "memory";
          format_mem = "{mem_used_percents}";
          format_swap = "{swap_used_percents}";
        }
        {
          block = "cpu";
          interval = 1;
        }
        {
          block = "temperature";
          collapsed = false;
          interval = 5;
          format = "{average}";
          inputs = ["Tdie"];
        }
        {
          block = "load";
          interval = 1;
          format = "{1m}";
        }
        {
          block = "nvidia_gpu";
          label = "1070 Ti";
          show_utilization = true;
          show_memory = false;
          show_clocks = false;
          show_temperature = true;
          show_fan_speed = true;
          interval = 1;
        }
        {
          block = "sound";
        }
        {
          block = "time";
          interval = 60;
          format = "%a %d/%m %I:%M %p";
        }
      ];
    };
  };
}
