{pkgs, ...}: {
  programs.obs-studio = {
    enable = true;
    plugins = [
      pkgs.obs-studio-plugins.obs-vkcapture
      pkgs.obs-studio-plugins.obs-pipewire-audio-capture
    ];
  };
}
