{
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  llm = inputs.llm-agents.packages.${system};
in
{
  home.packages = [
    llm.backlog-md
  ];
}
