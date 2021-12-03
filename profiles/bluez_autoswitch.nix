{
  services.pipewire = {
    media-session.config.bluez-monitor.rules = [
      {
        # Match all cards
        matches = [ { "device.name" = "~bluez_card.*"; } ];
        actions = {
          "update-props" = {
            "bluez5.autoswitch-profile" = true;
          };
        };
      }
    ];
  };
}
