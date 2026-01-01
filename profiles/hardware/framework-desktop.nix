{ inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
  ];

  boot.kernelParams = [
    # Kernel params set according to https://github.com/rjmalagon/ollama-linux-amd-apu
    # https://wiki.archlinux.org/title/Framework_Desktop#Unified_memory
    "ttm.pages_limit=4194304"
    "ttm.page_pool_size=4194304"
  ];
}
