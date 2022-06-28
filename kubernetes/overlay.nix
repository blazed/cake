{inputs, ...}: final: prev: {
  kured-yaml = prev.runCommand "kured.yaml" {} ''
    cp ${inputs.kured}/kured-ds.yaml .
    cp ${inputs.kured}/kured-rbac.yaml .
    cat<<PATCH>kured-ds-cmd.yaml
    apiVersion: apps/v1
    kind: DaemonSet
    metadata:
      name: kured
      namespace: kube-system
    spec:
      template:
        spec:
          containers:
            - name: kured
              env:
                - name: PATH
                  value: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/run/wrappers/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin
              command:
                - /usr/bin/kured
                - --reboot-command=/run/current-system/sw/bin/systemctl reboot
                - --period=10m
    PATCH
    cat<<KUSTOMIZATION>kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    resources:
    - kured-ds.yaml
    - kured-rbac.yaml
    patchesStrategicMerge:
    - kured-ds-cmd.yaml
    KUSTOMIZATION
    mkdir -p $out
    ${prev.kustomize}/bin/kustomize build . > $out/kured.yaml
  '';

  argocd-yaml = prev.runCommand "argocd.yaml" {} ''
    cp ${inputs.argocd-install} ./argocd.yaml
    cat<<PATCH>patch.yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: argocd-dex-server
    spec:
      ports:
      - name: http
        port: 5556
        protocol: TCP
        targetPort: 5556
      - name: http-grpc
        port: 5557
        protocol: TCP
        targetPort: 5557
      - name: http-metrics
        port: 5558
        protocol: TCP
        targetPort: 5558
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: argocd-metrics
    spec:
      ports:
      - name: http-metrics
        port: 8082
        protocol: TCP
        targetPort: 8082
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: argocd-repo-server
    spec:
      ports:
      - name: https-server
        port: 8081
        protocol: TCP
        targetPort: 8081
      - name: http-metrics
        port: 8084
        protocol: TCP
        targetPort: 8084
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: argocd-server-metrics
    spec:
      ports:
      - name: http-metrics
        port: 8083
        protocol: TCP
        targetPort: 8083
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: argocd-server
    spec:
      ports:
      - port: 80
        \$patch: delete
      - name: https-argocd-server
        port: 443
        protocol: TCP
        targetPort: 8080
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: argocd-repo-server
    spec:
      template:
        spec:
          serviceAccount: argocd-repo-server
          automountServiceAccountToken: true
          initContainers:
          - name: download-tools
            image: alpine:3.8
            command: [sh, -c]
            args:
            - wget -O argocd-vault-plugin
              https://github.com/argoproj-labs/argocd-vault-plugin/releases/download/v1.11.0/argocd-vault-plugin_1.11.0_linux_amd64

              chmod +x argocd-vault-plugin && mv argocd-vault-plugin /custom-tools/
            volumeMounts:
            - name: custom-tools
              mountPath: /custom-tools
          containers:
          - name: argocd-repo-server
            volumeMounts:
            - name: custom-tools
              mountPath: /usr/local/bin/argocd-vault-plugin
              subPath: argocd-vault-plugin
            envFrom:
            - secretRef:
                name: argocd-vault-configuration
          volumes:
          - name: custom-tools
            emptyDir: {}
    ---
    \$patch: delete
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-cm
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-rbac-cm
    data:
      policy.default: role:admin

    PATCH

    cat <<EXTRAS>argo-extras.yaml
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: argocd-metrics
      namespace: argocd
      labels:
        release: prometheus-k8s
    spec:
      endpoints:
      - port: http-metrics
      selector:
        matchLabels:
          app.kubernetes.io/name: argocd-metrics
    ---
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: argocd-repo-server-metrics
      namespace: argocd
      labels:
        release: prometheus-k8s
    spec:
      endpoints:
      - port: http-metrics
      selector:
        matchLabels:
          app.kubernetes.io/name: argocd-repo-server
    ---
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: argocd-server-metrics
      namespace: argocd
      labels:
        release: prometheus-k8s
    spec:
      endpoints:
      - port: http-metrics
      selector:
        matchLabels:
          app.kubernetes.io/name: argocd-server-metrics
    ---
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: argocd
      namespace: argocd
    spec:
      gateways:
      - istio-ingress/external
      hosts:
      - argocd.exsules.dev
      http:
      - match:
        - uri:
            prefix: /
        route:
        - destination:
            host: argocd-server.argocd.svc.cluster.local
            port:
              number: 443
    ---
    apiVersion: "networking.istio.io/v1alpha3"
    kind: "DestinationRule"
    metadata:
      name: "argocd-web-no-mtls"
      namespace: argocd
    spec:
      host: argocd-server.argocd.svc.cluster.local
      trafficPolicy:
        tls:
          mode: SIMPLE

    EXTRAS

    cat <<KUSTOMIZATION>kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    namespace: argocd
    resources:
    - argocd.yaml
    - argo-extras.yaml
    patchesStrategicMerge:
    - patch.yaml

    KUSTOMIZATION

    mkdir -p $out
    cat patch.yaml
    ${prev.kustomize}/bin/kustomize build . > $out/argocd.yaml
  '';
}
