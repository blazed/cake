{
  llama-cpp,
  fetchFromGitHub,
  rocmPackages,
}:
(llama-cpp.override {
  rocmSupport = true;
  blasSupport = true;
  cudaSupport = false;
  rocmGpuTargets = [ "gfx1151" ];
}).overrideAttrs
  (oa: rec {
    version = "11935";
    src = fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${version}";
      hash = "sha256-PAAOOHKz0SZFgCodE2IQKYhbIBysrYr0Yesnw+xXy/I=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmRoot = "tools/ui";
    npmDepsHash = "sha256-XLtEZsSFdk+2SyfXzBp8HQ2e27PQPpDCn1YjePU1/9w=";
    # nixpkgs' backports target its older release and are already in ours.
    patches = [ ../patches/llama-cpp-amd-mmvf-odd-cols.patch ];
    # Needs a downloaded model; its fixture would re-enable test-download-model.
    disabledTests = (oa.disabledTests or [ ]) ++ [ "test-llama-context-model" ];

    cmakeFlags = (oa.cmakeFlags or [ ]) ++ [
      "-DGGML_NATIVE=ON"
      "-DGGML_HIP_ROCWMMA_FATTN=ON"
      "-DGGML_HIP_NO_VMM=ON"
      "-DGGML_HIP_MMQ_MFMA=ON"
      "-DCMAKE_HIP_FLAGS=-I${rocmPackages.rocwmma}/include"
      # nixpkgs hard-codes its own release's build number and commit.
      "-DLLAMA_BUILD_NUMBER=${version}"
    ];

    # Replaces nixpkgs' UI build so the web UI reports our build number too.
    preConfigure = ''
      export NIX_ENFORCE_NO_NATIVE=0
      appendToVar cmakeFlags "-DLLAMA_BUILD_COMMIT=$(cat COMMIT)"
      pushd ${npmRoot}
      LLAMA_BUILD_NUMBER=${version} npm run build
      popd
    '';
  })
