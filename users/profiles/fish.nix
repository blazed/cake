{
  pkgs,
  lib,
  ...
}: let
  commandNotFound = pkgs.writeShellScriptBin "command-not-found" ''
    # shellcheck disable=SC1091
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
    command_not_found_handle "$@"
  '';
in {
  programs.autojump = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = [pkgs.fishPlugins.foreign-env];

  xdg.configFile."fish/functions/gcloud_sdk_argcomplete.fish".source = "${pkgs.inputs.google-cloud-sdk-fish-completion}/functions/gcloud_sdk_argcomplete.fish";
  xdg.configFile."fish/completions/gcloud.fish".source = "${pkgs.inputs.google-cloud-sdk-fish-completion}/completions/gcloud.fish";
  xdg.configFile."fish/completions/gsutil.fish".source = "${pkgs.inputs.google-cloud-sdk-fish-completion}/completions/gsutil.fish";
  xdg.configFile."fish/completions/kubectl.fish".source = "${pkgs.inputs.fish-kubectl-completions}/completions/kubectl.fish";

  programs.fish = {
    enable = true;
    shellAbbrs = {
      e = "nvim";
      gcb = "git checkout -b";
      gcm = "git checkout main";
      gc = "git commit -v";
      gca = "git commit -v -a";
      gl = "git pull";
      gd = "git diff";
      glol = "git log --graph --pretty='%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      glola = "git log --graph --pretty='%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all";
      gunwip = ''git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'';
      gwip = "git add -A; git rm (git ls-files --deleted) 2> /dev/null; git commit -m \"--wip--\"";
      gss = "git status -s";
      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
      "......" = "../../../../..";
      "--" = "cd -";
      fly = "fly -t exsules";
    };

    shellInit = ''
      fish_vi_key_bindings ^ /dev/null

      setenv EDITOR nvim

      # GO STUFF
      setenv GOPATH "$HOME/code/go"
      setenv PATH "$GOPATH/bin:$PATH"
      setenv GOPRIVATE "github.com/exsules"

      function __fish_command_not_found_handler --on-event fish_command_not_found
        ${commandNotFound}/bin/command-not-found $argv
      end

      function k --wraps kubectl -d 'kubectl shorthand'
        kubectl $argv
      end

      function md
        mkdir -p $argv && cd $argv
      end

      function vault-proxy
        set -Ux VAULT_ADDR "https://127.0.0.1:8200"
        set -Ux VAULT_TLS_SERVER_NAME vault.dev.exsules.com
        set -l k8s (${pkgs.kubectl}/bin/kubectl config current-context)
        set msg "[vault] Starting port-forward on Kubernetes context $k8s"
        if test -n "$TMUX"
          ${pkgs.tmux}/bin/tmux split-pane -d -v -l 3 "echo \"$msg\"; ${pkgs.kubectl}/bin/kubectl -n vault port-forward svc/vault-active 8200; set -e VAULT_ADDR VAULT_TLS_SERVER_NAME; echo Disconnected ; sleep 3"
        else
          echo >&2 "Open new shell before using Vault:"
          echo >&2 "$msg"
          ${pkgs.kubectl}/bin/kubectl -n vault port-forward svc/vault-active 8200 >&2
          set -e VAULT_ADDR VAULT_TLS_SERVER_NAME
        end
      end

      function extract
        set --local ext (echo $argv[1] | awk -F. '{print $NF}')
        switch $ext
          case tar
            tar -xvf $argv[1]
          case gz
            if test (echo $argv[1] | awk -F. '{print $(NF-1)}') = tar
              tar -zxf $argv[1]
            else
              gunzip $argv[1]
            end
          case tar.bz2
            tar xjf $argv[1]
          case tar.gz
            tar xzf $argv[1]
          case zip
            unzip $argv[1]
          case tar.xz
            tar xf $argv[1]
          case '*'
            echo "'$argv[1]' cannot be extracted via extract()"
        end
      end

      function git --wraps hub --description 'Alias for hub, which wraps git to provide extra functionality with GitHub.'
          hub $argv
      end
    '';
  };
}
