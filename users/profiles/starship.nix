{
  programs.starship = {
    enable = true;
    settings = {
      kubernetes.disabled = false;
      nix_shell.disabled = false;
    };
  };
}
