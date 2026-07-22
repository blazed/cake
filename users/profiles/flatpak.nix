{
  services.flatpak = {
    enable = true;
    packages = [
      "com.discordapp.Discord"
      "com.github.tchx84.Flatseal"
      "com.usebottles.bottles"
    ];
    uninstallUnmanaged = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
