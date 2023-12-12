{
  programs.starship = {
    enable = true;
    enableNushellIntegration = false;
    settings = {
      kubernetes.disabled = false;
      nix_shell.disabled = false;
    };
  };
}
