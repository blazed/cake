{
  stable-diffusion-cpp,
  fetchFromGitHub,
  rocmPackages,
}:
(stable-diffusion-cpp.override {
  rocmSupport = true;
  cudaSupport = false;
  rocmGpuTargets = [ "gfx1151" ];
}).overrideAttrs
  (old: rec {
    version = "master-1015-e41fbcf";
    src = fetchFromGitHub {
      owner = "leejet";
      repo = "stable-diffusion.cpp";
      tag = version;
      hash = "sha256-anmxAF+4OkjS8gQfgPBVnR9B3CDNi8bMQ7phXtrPCYA=";
      fetchSubmodules = true;
    };
    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      "-DCMAKE_HIP_COMPILER=${rocmPackages.clr.hipClangPath}/clang++"
      "-DGGML_HIP_NO_VMM=ON"
      "-DGGML_NATIVE=OFF"
      # llama-swap provides the UI; avoid the frontend's networked pnpm build.
      "-DSD_SERVER_BUILD_FRONTEND=OFF"
    ];
    # Upstream installs the library, but not its example executables.
    postPatch = (old.postPatch or "") + ''
      echo 'install(TARGETS sd-cli sd-server RUNTIME DESTINATION bin)' >> examples/CMakeLists.txt
    '';
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      $out/bin/sd-server --help > help.txt
      grep -q -- '--diffusion-model' help.txt
      grep -q -- '--max-vram' help.txt
      grep -q -- '--listen-port' help.txt
      runHook postInstallCheck
    '';
    meta = old.meta // {
      mainProgram = "sd-server";
    };
  })
