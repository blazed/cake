{
  services.xserver = {
    enable = true;
    displayManager = {
      gdm.enable = true;
      defaultSession = "none+i3";
    };

    windowManager.i3 = {
      enable = true;
    };

    layout = "us";
    xkbVariant = "dvp";
    xkbOptions = "caps:escape,compose:ralt";
  };
}
