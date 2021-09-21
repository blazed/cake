{ writeShellScriptBin, writeStrictShellScriptBin, nix-linter, pixiecore, gnugrep, gnused, findutils, kubernetes-helm, hostname }:
let
  clusterPoolIPv4CIDR = "10.244.0.0/16";
  clusterPoolIPv4MaskSize = "24";

  cake-generate-k8s-cilium-manifest = writeStrictShellScriptBin "cake-generate-k8s-cilium-manifest" ''
    export PATH=${kubernetes-helm}/bin:$PATH
    _CAKE_HELP=''${_CAKE_HELP:-}
    if [ -n "$_CAKE_HELP" ]; then
      echo generate cilium manifest for latest version
      exit 0
    fi
    helm repo add cilium https://helm.cilium.io/ > /dev/null 2>&1
    helm template cilium cilium/cilium \
      --set cni.confPath=/var/lib/rancher/k3s/agent/etc/cni/net.d \
      --set cni.binPath=/var/lib/rancher/k3s/data/current/bin \
      --set ipam.operator.clusterPoolIPv4CIDR=${clusterPoolIPv4CIDR} \
      --set ipam.operator.clusterPoolIPv4MaskSize=${clusterPoolIPv4MaskSize} \
      --set kubeProxyReplacement=strict \
      --set endpointRoutes.enabled=true \
      --namespace=kube-system
  '';

  cake-pixieboot = writeStrictShellScriptBin "cake-pixieboot" ''
    export PATH=${gnugrep}/bin:$PATH
    _CAKE_HELP=''${_CAKE_HELP:-}
    if [ -n "$_CAKE_HELP" ]; then
      echo start pixiecore for automated network installation
      exit 0
    fi
    echo Hey, you may need to turn off the firewall for this to work
    nix build .#pxebooter -o /tmp/netboot
    n="$(realpath /tmp/netboot)"
    init="$(grep -ohP 'init=\S+' "$n/netboot.ipxe")"
    sudo ${pixiecore}/bin/pixiecore boot "$n/bzImage" "$n/initrd" \
      --cmdline "$init loglevel=4" \
      --debug --dhcp-no-bind --port 64172 --status-port 64172
  '';

  cake-repl = writeStrictShellScriptBin "cake-repl" ''
    export PATH=${hostname}/bin:$PATH
    _CAKE_HELP=''${_CAKE_HELP:-}
    if [ -n "$_CAKE_HELP" ]; then
      echo start a nix repl in host context
      exit 0
    fi
    host="$(hostname)"
    trap 'rm -f ./nix-repl.nix' EXIT
    cat<<EOF>./nix-repl.nix
    (builtins.getFlake (toString ./.)).nixosConfigurations.$host
    EOF
    nix repl ./nix-repl.nix
  '';

  cake-help = writeStrictShellScriptBin "cake-help" ''
    export PATH=${gnugrep}/bin:${gnused}/bin:${findutils}/bin:$PATH
    _CAKE_HELP=''${_CAKE_HELP:-}
    if [ -n "$_CAKE_HELP" ]; then
      echo this help text
      exit 0
    fi
    cat<<HELP
      Available sub commands:
    HELP
    export _CAKE_HELP=yes
    # shellcheck disable=SC2086
    for cmd in $(printf '%s\n' ''${PATH//:/\/* } | xargs -n 1 basename | \
      grep -E '^cake-' | sed 's|cake-||g'); do
    # shellcheck disable=SC1087
      cat<<HELP
          $cmd
             - $(cake-$cmd)
    HELP
    done
  '';

  ## requires docker configured on system since docker requires more than just the cli tools
  cake-container = writeShellScriptBin "cake-container" ''
    _CAKE_HELP=''${_CAKE_HELP:-}
    if [ -n "$_CAKE_HELP" ]; then
      echo run a nix container with this repo mounted at /cake
      exit 0
    fi
    docker run --privileged -v /etc/nix/nix.conf:/etc/nix/nix.conf -v ./:/cake -w /cake -ti --entrypoint bash --rm nixpkgs/nix-unstable -c bash
  '';

  cake-lint= writeShellScriptBin "cake-lint" ''
    export PATH=${nix-linter}/bin:${gnugrep}/bin:${gnused}/bin:${findutils}/bin:$PATH
    _CAKE_HELP=''${_CAKE_HELP:-}
    if [ -n "$_CAKE_HELP" ]; then
      echo lint all nix files
      exit 0
    fi
    shopt -s globstar
    # shellcheck disable=SC2016
    lintout="$(mktemp lintout.XXXXXXX)"
    trap 'rm -f $lintout' EXIT
    nix-linter -W no-FreeLetInFunc -W no-SetLiteralUpdate ./**/*.nix | \
      grep -v 'Unused argument `final`' | \
      grep -v 'Unused argument `prev`' | \
      grep -v 'Unused argument `plugins`' | \
      grep -v 'Unused argument `isNixOS`' \
      > "$lintout"
    cat "$lintout"
    if [ -s "$lintout" ]; then
      exit 1
    fi
  '';

  cake = writeShellScriptBin "cake" ''
    cmd=''${1:-help}
    if [ "$cmd" = "help" ]; then
      ${cake-help}/bin/cake-help
      exit 0
    fi
    name="$(basename "$0")"
    subcmd="$name-$cmd"
    shift
    if ! command -v "$subcmd" > /dev/null; then
      echo Unknown command "\"$cmd\""
      ${cake-help}/bin/cake-help
      exit 1
    fi
    "$subcmd" "$@"
  '';

in

{
  inherit cake cake-pixieboot cake-container
    cake-help cake-lint cake-repl cake-generate-k8s-cilium-manifest;
}
