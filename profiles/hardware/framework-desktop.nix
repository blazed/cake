{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
  ];

  boot.kernelParams = [
    # Kernel params set according to https://github.com/rjmalagon/ollama-linux-amd-apu
    # https://wiki.archlinux.org/title/Framework_Desktop#Unified_memory
    # Required to avoid the loader hang on >64GB models and gives ~6% more memory
    # bandwidth (the dominant bottleneck on this APU).
    "amd_iommu=off"
    "ttm.pages_limit=29360128"
    "ttm.page_pool_size=29360128"
  ];

  # The XDNA2 NPU (amdxdna) is unused by the llama.cpp iGPU stack and can't bind SVA
  # with the IOMMU off above, so the ROCm accel-node probe spams "SVA bind device
  # failed, ret -19" on every model load. Blacklist the leaf driver to silence it.
  boot.blacklistedKernelModules = [ "amdxdna" ];
}
