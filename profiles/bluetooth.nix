{
  hardware.bluetooth.enable = true;
  environment.state."/keep" = {
    directories = [
      "/var/lib/bluetooth"
    ];
  };
}
