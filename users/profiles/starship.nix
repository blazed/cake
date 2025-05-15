{
  programs.starship = {
    enable = true;
    enableNushellIntegration = false;
    settings = {
      kubernetes.disabled = false;
      kubernetes.style = "bold blue";
      nix_shell.disabled = false;
      gcloud = {
        format = "on [$symbol(\\($project\\))]($style) ";
      };
      custom.jj = {
        detect_folders = [".jj"];
        symbol = "🥋 ";
        command = ''
          jj log -r::@ -n2 --no-graph --ignore-working-copy --color always --template '
            separate(" ",
              " ",
              change_id.shortest(4),
              bookmarks,
              tags,
              "|",
              concat(
                if(conflict, "💥"),
                if(divergent, "🚧"),
                if(hidden, "👻"),
                if(immutable, "🔒"),
              ),
              raw_escape_sequence("\x1b[1;32m") ++ if(empty, "(empty)"),
              raw_escape_sequence("\x1b[1;32m") ++ if(description.first_line().len() == 0,
                "(no description set)",
                if(description.first_line().substr(0, 29) == description.first_line(),
                  description.first_line(),
                  description.first_line().substr(0, 29) ++ "…",
                )
              ) ++ raw_escape_sequence("\x1b[0m"),
            )
          '
        '';
      };
    };
  };
}
