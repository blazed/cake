{
  pkgs,
  config,
  inputs,
  tailnet,
  hostName,
  ...
}:
let
  inherit (config.services.k3s) settings;
  cluster-cidr = "10.244.0.0/16";
  service-cidr = "10.96.0.0/12";
  cluster-dns = "10.96.0.10";
in
{
  imports = [
    ./k3s.nix
  ];
  services.k3s = {
    enable = true;
    role = "server";
    settings = {
      disable = [
        "servicelb"
        "traefik"
        "metrics-server"
      ];
      flannel-backend = "none";
      disable-network-policy = true;
      disable-kube-proxy = true;
      disable-cloud-controller = true;
      node-name = hostName;
      advertise-address = "\"$(get-iface-ip eth0)\"";
      inherit cluster-cidr service-cidr cluster-dns;
      kube-controller-manager-arg.node-cidr-mask-size = 24;
      node-label."svccontroller.k3s.cattle.io/enablelb" = "true";
      secrets-encryption = true;
      tls-san = [
        "10.0.10.33"
        hostName
        "${hostName}.${tailnet}.ts.net"
      ];
    };
    autoDeploy =
      let
        cilium = pkgs.runCommand "helm-template" { allowSubstitution = false; } ''
          mkdir -p $out
          ${pkgs.kubernetes-helm}/bin/helm template cilium ${inputs.cilium-chart} \
            --namespace kube-system \
            --set kubeProxyReplacement=true \
            --set socketLB.hostNamespaceOnly=true \
            --set k8sServiceHost="10.0.10.33" \
            --set k8sServicePort=6443 \
            --set enableExternalIPs=true \
            --set enableHostPort=true \
            --set enableNodePort=true \
            --set ipam.operator.clusterPoolIPv4PodCIDRList=${settings.cluster-cidr} \
            --set gatewayAPI.enabled=true \
            --set encryption.enabled=false \
            --set encryption.type=wireguard \
            --set encryption.nodeEncryption=true > "$out"/cilium.yaml
        '';
      in
      {
        kured = "${pkgs.kured-yaml}/kured.yaml";
        cilium = "${cilium}/cilium.yaml";
      };
  };
}
