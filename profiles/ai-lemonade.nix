{
  config,
  lib,
  inputs,
  adminUser,
  ...
}:
let
  cfg = config.hardware.amd-npu;
in
{
  # Lemonade AI server (noamsto/nix-amd-ai) as an alternative to profiles/ai.nix
  # (llama-swap). Swap which one margot imports to switch between them.
  #
  # nixosModules.default sets `nixpkgs.overlays`; cake injects a prebuilt pkgs via
  # `nixpkgs.pkgs`, and NixOS appends overlays to it (misc/nixpkgs.nix: appendOverlays),
  # so the AMD packages land on margot's package set without a setup.nix change.
  imports = [ inputs.nix-amd-ai.nixosModules.default ];

  hardware.amd-npu = {
    enable = true;

    # NPU (XDNA2 / amdxdna) stays OFF on purpose. profiles/hardware/framework-desktop.nix
    # sets amd_iommu=off (≈6% memory-bandwidth win, avoids the >64 GB loader hang) and
    # blacklists amdxdna. The NPU needs IOMMU on for SVA, so enabling it would undo that
    # tune and turn the ai.nix <-> ai-lemonade.nix swap into a kernel-param change + reboot.
    # To try FastFlowLM on the NPU later: drop amd_iommu=off and the amdxdna blacklist in
    # framework-desktop.nix, then set enableNPU = enableFastFlowLM = true here.
    enableNPU = false;
    enableFastFlowLM = false;

    enableLemonade = true;
    enableVulkan = true; # RADV STRIX_HALO — the working in-lemonade GPU backend (full 115 GB).
    # ROCm stays OFF: lemonade 10.8.0 implements its ROCm backend by downloading AMD's own
    # "TheRock" gfx1151 ROCm runtime at load time and ignores a system llama-cpp-rocm binary,
    # so wiring enableROCm here just adds a redundant ~1.5 GB closure lemonade never uses.
    # ROCm-in-lemonade is instead a runtime opt-in (`lemonade backends install llamacpp:rocm`),
    # which works now that .cache/lemonade is persisted (TheRock extracts to /keep, not the
    # 8 GB tmpfs that made it fail). For maximally-tuned gfx1151 ROCm, use profiles/ai.nix.
    enableROCm = false;
    enableImageGen = false; # LLM-only; flip on for stable-diffusion.cpp.

    lemonade = {
      user = adminUser.name;
      host = "0.0.0.0"; # mirror ai.nix's LAN exposure; reachable for the tailscale serve below.
      desktopApp.enable = false; # headless server — skip the Tauri/Rust/npm build path.
    };

    # GTT pool is already sized to 112 GiB via ttm.pages_limit in
    # profiles/hardware/framework-desktop.nix, so gpuMemory.* is left at its default
    # (null) to avoid a second, conflicting modprobe setting.
  };

  # lemond runs as the admin user; it needs the iGPU render node for the Vulkan backend.
  users.users.${adminUser.name}.extraGroups = [
    "video"
    "render"
  ];

  networking.firewall.allowedTCPPorts = [ cfg.lemonade.port ];

  # HuggingFace model cache. margot's / is an 8 GB tmpfs and impermanence wipes
  # anything not under /keep, so lemonade's default ~/.cache/huggingface runs out of
  # space (the "Insufficient disk space" download error) and would be lost on reboot.
  # Persist it onto the btrfs /keep pool (hundreds of GB free) so multi-GB GGUFs land
  # there and survive reboots. (The old profiles/ai.nix achieved the same for
  # llama-swap via XDG_CACHE_HOME=/var/cache + a systemd CacheDirectory.)
  environment.persistence."/keep" = lib.mkIf config.ephemeralRoot {
    users.${adminUser.name}.directories = [
      ".cache/huggingface" # multi-GB GGUF blobs
      # lemonade state: config.json (regenerates from the nix seed, but persisting it
      # is harmless since the module uses stable /etc/lemonade/backends/* paths) and
      # user_models.json (the imported custom models — NOT reproducible from the seed,
      # so this is what actually needs persisting across the nightly autoUpgrade reboot).
      ".cache/lemonade"
    ];
  };

  # Mirror profiles/ai.nix: expose the server over Tailscale HTTPS.
  systemd.services.tailscale-serve-lemonade = {
    description = "Expose lemonade over Tailscale HTTPS";
    after = [
      "tailscaled.service"
      "tailscale-auth.service"
      "lemond.service"
    ];
    wants = [
      "tailscaled.service"
      "lemond.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=443 http://127.0.0.1:${toString cfg.lemonade.port}";
      ExecStop = "${lib.getExe config.services.tailscale.package} serve --https=443 off";
    };
  };
}
