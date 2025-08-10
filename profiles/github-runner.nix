{
  pkgs,
  hostName,
  ...
}:
{
  users.users.github-runner = {
    isSystemUser = true;
    group = "github-runner";
    extraGroups = [ "docker" ];
  };

  users.groups.github-runner = { };

  services.github-runners = {
    exsules-runner = {
      enable = true;
      name = hostName;
      url = "https://github.com/exsules";
      nodeRuntimes = [
        "node24"
        "node20"
        "node16"
      ];
      ephemeral = true;
      user = "github-runner";
      group = "github-runner";
      replace = true;
      extraLabels = [
        "exsules-org-wide"
      ];
      extraPackages = with pkgs; [
        acl
        autoconf
        automake
        binutils
        bzip2
        codecov-cli
        coreutils
        curl
        devenv
        dnsutils
        docker-client
        file
        findutils
        gawk
        git
        gnupg
        jq
        nodejs_20
        nodejs_24
        openssh
        rsync
        shellcheck
        sudo
        tree
        unzip
        unzip
        wget
        xz
      ];
      tokenFile = "/run/agenix/github-runner";
    };
  };

  nix.settings.trusted-users = [
    "github-runner"
  ];
}
