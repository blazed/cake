{
  pkgs,
  inputs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  # Use upstream's Node mode so install hooks and checks match the npm layout.
  # Some extensions use native Node add-ons that Bun binaries cannot reliably load.
  pi = inputs.llm-agents.packages.${system}.pi.override { useBun = false; };
in
pi.overrideAttrs (_: {
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.stdenv.cc
          pkgs.gnumake
          pkgs.fd
          pkgs.ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR "$out/lib/node_modules/@earendil-works/pi-coding-agent" \
      --set JJ_EDITOR echo \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';
})
