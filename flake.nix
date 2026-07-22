{
  description = "NixOS Configurations";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://blazed.cachix.org"
      "https://cachix.cachix.org"
      "https://hyprland.cachix.org"
      "https://cache.numtide.com"
      "https://nix-amd-ai.cachix.org"
      "https://niri.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "blazed.cachix.org-1:e9Rx3vtlQSp3nckCdGYpSFJbOb/hi1KuTyvWTBkiwAI="
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };

  inputs = {
    agenix.inputs.home-manager.follows = "nixpkgs";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.systems.follows = "systems";
    agenix.url = "github:ryantm/agenix";
    age-plugin-yubikey.flake = false;
    age-plugin-yubikey.url = "github:str4d/age-plugin-yubikey";
    cachix.url = "github:cachix/cachix";
    cachix.inputs = {
      devenv.follows = "devenv";
      flake-compat.follows = "flake-compat";
      nixpkgs.follows = "nixpkgs";
    };
    cilium-chart.url = "https://github.com/cilium/charts/raw/refs/heads/master/cilium-1.18.9.tgz";
    cilium-chart.flake = false;
    claude-code.url = "github:sadjow/claude-code-nix";
    claude-code.inputs.nixpkgs.follows = "nixpkgs";
    crane.url = "github:ipetkov/crane";
    dank-greeter.url = "github:AvengeMedia/dank-greeter";
    dank-greeter.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.flake-compat.follows = "flake-compat";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    devenv.inputs.cachix.follows = "cachix";
    devenv.url = "github:cachix/devenv";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    dms.url = "github:AvengeMedia/DankMaterialShell/stable";
    dms.inputs.nixpkgs.follows = "nixpkgs";
    fenix.inputs.nixpkgs.follows = "nixpkgs";
    fenix.url = "github:nix-community/fenix";
    flake-compat.flake = false;
    flake-compat.url = "github:edolstra/flake-compat";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    hyprland.url = "github:hyprwm/Hyprland";
    impermanence.url = "github:nix-community/impermanence";
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    kured.flake = false;
    kured.url = "github:kubereboot/kured";
    # Keep llm-agents on its pinned nixpkgs: its agent-browser package currently
    # uses pnpm 11 with a fetcher version incompatible with our newer nixpkgs.
    llm-agents.url = "github:numtide/llm-agents.nix";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    niri.url = "github:sodiboo/niri-flake";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    # AMD AI stack (Lemonade server, XRT/NPU, ROCm/Vulkan backends). Deliberately
    # NOT `.follows`-ing nixpkgs: the overlay is built against this flake's own
    # pinned nixpkgs so its Cachix (nix-amd-ai.cachix.org) substitutes; following
    # our nixpkgs would re-hash every backend and force a from-source rebuild.
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-hardware.url = "github:nixos/nixos-hardware";
    # Newer nixpkgs currently breaks input-remapper and avante.nvim builds;
    # keep the last known-good revision until those regressions are fixed.
    nixpkgs.url = "github:NixOS/nixpkgs/d407951447dcd00442e97087bf374aad70c04cea";
    nur.url = "github:nix-community/NUR";
    persway.inputs.crane.follows = "crane";
    persway.inputs.devenv.follows = "devenv";
    candle.url = "github:blazed/candle/add-nixvim";
    candle.inputs.nixpkgs.follows = "nixpkgs";
    persway.inputs.fenix.follows = "fenix";
    persway.inputs.flake-parts.follows = "flake-parts";
    persway.inputs.flake-utils.follows = "flake-utils";
    persway.inputs.mk-shell-bin.follows = "mk-shell-bin";
    persway.inputs.nix2container.follows = "nix2container";
    persway.inputs.nixpkgs.follows = "nixpkgs";
    persway.url = "github:johnae/persway";
    pre-commit-hooks.inputs.flake-compat.follows = "flake-compat";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./flake/checks.nix
        ./flake/devenv.nix
        ./flake/github-actions.nix
        ./flake/helper-packages.nix
        ./flake/hosts.nix
        ./flake/kubernetes.nix
        ./flake/packages.nix
        ./flake/setup.nix
      ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
}
