{
  config,
  pkgs,
  ...
}:
{
  home = {
    sessionVariables = {
      EDITOR = "nvim";
      MANPAGER = "nvim -c 'set ft=man bt=nowrite noswapfile nobk shada=\\\"NONE\\\" ro noma' +Man! -o -";
    };
    packages = [
      pkgs.candle
      pkgs.nvrh
    ];
  };
}
