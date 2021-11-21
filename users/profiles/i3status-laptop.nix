{
  programs.i3status-rust = {
    enable = true;
    bars.default = {
      theme = "solarized-dark";
      icons = "awesome5";
      blocks = [
        {
          block = "net";
          format = "{ssid} {signal_strength} {ip} {speed_down;K*b} {speed_up;K*b}";
          interval = 5;
        }
        {
          block = "cpu";
        }
        {
          block = "battery";
          interval = 30;
          format = "{percentage}% {time}";
        }
        {
          block = "backlight";
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
