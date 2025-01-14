{pkgs, ...}: let
  aider = pkgs.writeShellApplication {
    name = "aider";
    runtimeInputs = [ pkgs.aider-chat ];
    text = ''
      OPENAI_API_KEY="$(cat /run/agenix/copilot-api-key)"
      OPENAI_API_BASE=https://api.githubcopilot.com
      export OPENAI_API_KEY OPENAI_API_BASE
      exec aider "$@"
    '';
  };
in {
  home.packages = [ aider ];
}
