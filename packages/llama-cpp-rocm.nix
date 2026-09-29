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
    version = "11254";
    src = fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${version}";
      hash = "sha256-13WW45yaY2UZ6e8ezQeBzmzQG/JJtwQWLDBoPDZX8CI=";
      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmRoot = "tools/ui";
    npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
    patches = (oa.patches or [ ]) ++ [ ../patches/llama-cpp-amd-mmvf-odd-cols.patch ];

    cmakeFlags = (oa.cmakeFlags or [ ]) ++ [
      "-DGGML_NATIVE=ON"
      "-DGGML_HIP_ROCWMMA_FATTN=ON"
      "-DGGML_HIP_NO_VMM=ON"
      "-DGGML_HIP_MMQ_MFMA=ON"
      "-DCMAKE_HIP_FLAGS=-I${rocmPackages.rocwmma}/include"
    ];

    preConfigure = ''
      export NIX_ENFORCE_NO_NATIVE=0
      ${oa.preConfigure or ""}
    '';
  })
