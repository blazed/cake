{ pkgs, lib, ... }:
let
  commandNotFound = pkgs.writeShellScriptBin "command-not-found" ''
    # shellcheck disable=SC1091
    source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
    command_not_found_handle "$@"
  '';

  withinNetNS = executable: { netns ? "private" }:
    lib.concatStringsSep " " [
      "${pkgs.dbus}/bin/dbus-run-session" ## sway is actually wrapped and does this, but fish doesn't for example. No harm doing it even for sway.
      "${pkgs.netns-dbus-proxy}/bin/netns-dbus-proxy"
      "netns-exec"
      netns
      executable
    ];

  sway = pkgs.callPackage (pkgs.path + "/pkgs/applications/window-managers/sway/wrapper.nix") {
    extraSessionCommands = ''
      export XDG_SESSION_TYPE=wayland
      export XDG_CURRENT_DESKTOP=sway
      export XDG_SESSION_DESKTOP=sway
    '';
  };

  genLauncher = optionList: ''
    clear
    set RUN (echo -e "${genLaunchOptions optionList}" | \
        ${pkgs.skim}/bin/sk -p "start >> " --inline-info --margin 40%,40% \
                            --color=bw --height=40 --no-hscroll --no-mouse \
                            --reverse --delimiter='\t' --with-nth 1 | \
                                 ${pkgs.gawk}/bin/awk -F'\t' '{print $2}')
    eval "$RUN"
  '';

  privateSway = withinNetNS "${sway}/bin/sway" { };
  privateFish = withinNetNS "${pkgs.fish}/bin/fish" { };

  genLaunchOptions = optionList:
    lib.concatStringsSep "\\n" (lib.flatten (
      map
        (
          lib.mapAttrsToList (k: v: "${k}\\texec ${v}")
        )
        optionList
    ));

  swayDrmDebug = pkgs.writeStrictShellScriptBin "sway-drm-debug" ''
    echo 0xFE | sudo tee /sys/module/drm/parameters/debug # Enable verbose DRM logging
    sudo dmesg -C
    dmesg -w >dmesg.log & # Continuously write DRM logs to a file
    sway -d >sway.log 2>&1 # Reproduce the bug, then exit sway
    fg # Kill dmesg with Ctrl+C
    echo 0x00 | sudo tee /sys/module/drm/parameters/debug
  '';

  drmDebugLaunch = pkgs.writeStrictShellScriptBin "drm-debug-launch" ''
    ln -s ${swayDrmDebug}/bin/sway-drm-debug ~/sway-drm-debug
    echo Please execute ~/sway-drm-debug
    ${pkgs.fish}/bin/fish
  '';

  launcher = genLauncher [
    { "sway" = "${pkgs.libudev}/bin/systemd-cat --identifier=sway ${sway}/bin/sway"; }
    { "sway private" = "${pkgs.libudev}/bin/systemd-cat --identifier=sway ${privateSway}"; }
    { "fish" = "${pkgs.dbus}/bin/dbus-run-session ${pkgs.fish}/bin/fish"; }
    { "fish private" = privateFish; }
    { "sway debug" = "${sway}/bin/sway -d 2> ~/sway.log"; }
    { "sway drm debug" = "${drmDebugLaunch}/bin/drm-debug-launch"; }
  ];
in
{
  programs.autojump = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = [ pkgs.fishPlugins.foreign-env ];

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
      gunwip = "git log -n 1 | grep -q -c \"\-\-wip\-\-\" && git reset HEAD~1";
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

      setenv GPG_TTY (tty)
      setenv SSH_AUTH_SOCK "/run/user/"(id -u)"/gnupg/S.gpg-agent.ssh"
      gpg-connect-agent updatestartuptty /bye >/dev/null

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

    loginShellInit = ''
      if test "$DISPLAY" = ""; and test (tty) = /dev/tty1 || test (tty) = /dev/tty2; and test "$XDG_SESSION_TYPE" = "tty"
        ${launcher}
      end
    '';
  };
}
