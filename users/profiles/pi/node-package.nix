{
  pkgs,
  inputs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  pi = inputs.llm-agents.packages.${system}.pi;
in
# llm-agents compiles Pi into a standalone Bun binary. Some extensions use
# native Node add-ons that Bun binaries cannot reliably load.
# Reuse the same fetched npm source/dependency closure but retain Pi's normal
# Node entry point instead of compiling and deleting it.
pi.overrideAttrs (_: {
  postUnpack = "";
  preInstall = "";
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
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';
})
