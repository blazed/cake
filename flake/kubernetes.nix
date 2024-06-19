{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages = {
      kured-yaml = pkgs.runCommand "kured.yaml" {} ''
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
              tolerations:
              - effect: NoExecute
                key: CriticalAddonsOnly
                operator: Exists
        PATCH
        cat<<KUSTOMIZATION>kustomization.yaml
        apiVersion: kustomize.config.k8s.io/v1beta1
        kind: Kustomization
        resources:
        - kured-ds.yaml
        - kured-rbac.yaml
        patches:
        - path: kured-ds-cmd.yaml
        KUSTOMIZATION
        mkdir -p $out
        ${pkgs.kustomize}/bin/kustomize build . > $out/kured.yaml
      '';
    };
  };
}
