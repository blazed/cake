{ pkgs, piNode }:
let
  piPackageDir = "${piNode}/lib/node_modules/@earendil-works/pi-coding-agent";
in
pkgs.buildNpmPackage {
  pname = "pi-subagents-extension";
  version = "0-unstable";
  src = ./extensions/subagents;
  npmDepsHash = "sha256-X0fJ3rmZUPuXjzrHjfAML4xph/IoHH1svavMJ7YCgVI=";

  buildPhase = ''
    runHook preBuild

    test -d ${piPackageDir}/node_modules/@earendil-works/pi-ai
    test -d ${piPackageDir}/node_modules/@earendil-works/pi-tui
    test -d ${piPackageDir}/node_modules/typebox
    mkdir -p node_modules/@earendil-works
    ln -s ${piPackageDir} node_modules/@earendil-works/pi-coding-agent
    ln -s ${piPackageDir}/node_modules/@earendil-works/pi-ai \
      node_modules/@earendil-works/pi-ai
    ln -s ${piPackageDir}/node_modules/@earendil-works/pi-tui \
      node_modules/@earendil-works/pi-tui
    ln -s ${piPackageDir}/node_modules/typebox node_modules/typebox

    npm run check
    npm test

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    npm prune --omit=dev --ignore-scripts --offline
    rm -rf \
      node_modules/@earendil-works \
      node_modules/typebox \
      docs \
      *.test.ts \
      *.live.ts \
      package-lock.json \
      tsconfig.json \
      src/backends/stub.ts
    mkdir -p $out
    cp -r index.ts package.json src node_modules $out/

    runHook postInstall
  '';
}
