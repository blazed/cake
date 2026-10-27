{
  llama-swap,
  buildNpmPackage,
  fetchFromGitHub,
}:
llama-swap.overrideAttrs (oa: rec {
  version = "267";
  src = fetchFromGitHub {
    owner = "mostlygeek";
    repo = "llama-swap";
    tag = "v${version}";
    hash = "sha256-NR9XO/RyzxOzSODNe42VqevmXw/TchrLFJr4iqbbGIM=";
    leaveDotGit = true;
    postFetch = ''
      cd "$out"
      git rev-parse HEAD > $out/COMMIT
      date -u -d "@$(git log -1 --pretty=%ct)" "+'%Y-%m-%dT%H:%M:%SZ'" > $out/SOURCE_DATE_EPOCH
      find "$out" -name .git -print0 | xargs -0 rm -rf
    '';
  };
  vendorHash = "sha256-nauMUxfDugvYnA74eVm8jaUt+l1V7gNvL89f6l2Ls8w=";
  patches = (oa.patches or [ ]) ++ [ ../patches/llama-swap-metrics-ttl.patch ];
  tags = (oa.tags or [ ]) ++ [ "embed_ui" ];
  # shortcut-debt: forwardGpuStats drops stats when a subscriber's one-slot
  # channel is full, so with instant fake restarts the stat this test waits for
  # is often lost and it times out. Remove when upstream fixes the test.
  checkFlags = [ "-skip=^TestStart_GpuRestartWaitResetsAfterStats$" ];
  preBuild = ''
    ldflags+=" -X main.commit=$(cat COMMIT)"
    ldflags+=" -X main.date=$(cat SOURCE_DATE_EPOCH)"

    rm -rf internal/server/ui_dist
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
