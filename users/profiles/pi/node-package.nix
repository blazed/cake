{
  pkgs,
  inputs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  pi = inputs.llm-agents.packages.${system}.pi;
in
# llm-agents compiles Pi into a standalone Bun binary. Bun binaries cannot
# resolve external native add-ons loaded by extensions (remote-pi's
# @napi-rs/keyring in particular), even when the .node package is installed.
# Reuse the same fetched npm source/dependency closure but retain Pi's normal
# Node entry point instead of compiling and deleting it.
pi.overrideAttrs {
  postUnpack = "";
  preInstall = "";
  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.fd
          pkgs.ripgrep
        ]
      } \
      --set PI_PACKAGE_DIR "$out/lib/node_modules/@earendil-works/pi-coding-agent" \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';
}
