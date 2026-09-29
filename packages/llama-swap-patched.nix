{
  llama-swap,
  buildGo127Module,
  buildNpmPackage,
  fetchFromGitHub,
}:
(llama-swap.override { buildGoModule = buildGo127Module; }).overrideAttrs (oa: rec {
  version = "260";
  src = fetchFromGitHub {
    owner = "mostlygeek";
    repo = "llama-swap";
    tag = "v${version}";
    hash = "sha256-W5JJW1/qQm39U/g42jseRmGQobqqWRfVsJ2lT/7K9P8=";
    leaveDotGit = true;
    postFetch = ''
      cd "$out"
      git rev-parse HEAD > $out/COMMIT
      date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };
  vendorHash = "sha256-yelob7FlaGymASUP0DAUkALQm5vnXZnN5ThbnSkH2Ak=";
  patches = (oa.patches or [ ]) ++ [ ../patches/llama-swap-v250-shell.patch ];
  tags = (oa.tags or [ ]) ++ [ "embed_ui" ];
  preBuild = ''
    ldflags+=" -X main.commit=$(cat COMMIT)"
    ldflags+=" -X main.date=$(cat SOURCE_DATE_EPOCH)"

    rm -rf proxy/ui_dist internal/server/ui_dist
    cp -r ${passthru.ui}/ui_dist proxy/
    cp -r ${passthru.ui}/ui_dist internal/server/
  '';
  passthru = oa.passthru // {
    ui = buildNpmPackage {
      pname = "llama-swap-ui";
      inherit version src;
      sourceRoot = "${src.name}/ui";
      npmDepsHash = "sha256-lmhRJ8275PIQ+7vHdr9aZ31lYeXUkXrWnlvuwOadjRQ=";
      postPatch = ''
        substituteInPlace vite.config.ts \
          --replace-fail "../internal/server/ui_dist" "${placeholder "out"}/ui_dist"
      '';
      postInstall = ''
        rm -rf $out/lib
      '';
    };
  };
})
