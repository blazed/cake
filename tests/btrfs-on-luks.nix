{ pkgs, ... }:
# Regression test for the cryptkey -> encrypted_root LUKS chain used by
# profiles/disk/btrfs-on-luks.nix. The original failure (systemd 260) was a
# new rule in 99-systemd.rules that marks any CRYPT-* dm device with no
# detected partition table and no detected filesystem as SYSTEMD_READY=0
# (intended to skip half-formatted encrypted volumes mid-mke2fs). Our
# cryptkey volume is intentionally raw LUKS-wrapped key material, so it
# matched, dev-mapper-cryptkey.device never activated, and the whole
# chain hung in initrd waiting for /dev/disk/by-label/root.
#
# This test reproduces the chain at runtime and ships the same udev rule
# override that profiles/disk/btrfs-on-luks.nix installs into the initrd.
# It pins linuxPackages_latest so the check follows whatever the latest
# flake input bump pulled in; if a future systemd/udev change breaks
# dm-device readiness in a way the current override doesn't cover, CI
# fails here instead of a router failing to boot at 05:00.
let
  # Mirror of the rule shipped by profiles/disk/btrfs-on-luks.nix. Keep in
  # sync: if the override condition or filename changes there, change here.
  cryptkeySystemdReadyOverride =
    pkgs.writeTextDir "lib/udev/rules.d/999-cryptkey-systemd-ready.rules"
      ''
        SUBSYSTEM=="block", ENV{DM_NAME}=="cryptkey", ENV{SYSTEMD_READY}="1"
      '';
in
pkgs.testers.runNixOSTest {
  name = "btrfs-on-luks-cryptchain";

  nodes.machine =
    { pkgs, ... }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.initrd.systemd.enable = true;

      services.udev.packages = [ cryptkeySystemdReadyOverride ];

      environment.systemPackages = [
        pkgs.cryptsetup
        pkgs.btrfs-progs
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Lay out the same chain btrfs-on-luks.nix uses in production:
    # cryptkey LUKS volume opened by a static keyfile, then a second LUKS
    # volume (encrypted_root) whose keyfile is /dev/mapper/cryptkey. The
    # production setup uses /sys/.../product_serial for the outer keyfile;
    # that DMI path is APU-specific and unrelated to the bug we're guarding
    # against, so we substitute a plain file.
    machine.succeed("printf cryptkey-test-material > /tmp/keyfile")
    # LUKS2 defaults to a 16 MiB metadata header, so the backing files have
    # to leave room for actual data beyond that. cryptkey only ever holds a
    # short keyfile, but the volume must be > header size to activate at
    # all. encrypted_root needs enough for mkfs.btrfs to succeed.
    machine.succeed("truncate -s 32M /tmp/cryptkey.img")
    machine.succeed("truncate -s 256M /tmp/encrypted_root.img")

    machine.succeed(
        "cryptsetup luksFormat -q --type=luks2 --pbkdf=pbkdf2 --pbkdf-force-iterations=1000 "
        "/tmp/cryptkey.img /tmp/keyfile"
    )
    machine.succeed(
        "cryptsetup luksOpen --key-file=/tmp/keyfile /tmp/cryptkey.img cryptkey"
    )
    # cryptsetup caps keyfile reads at 8 MiB. The cryptkey mapper device is
    # the full LUKS data area (volume size minus the 16 MiB LUKS2 header),
    # which here is larger than that cap. Cap the keyfile read explicitly;
    # production's cryptkey partition is sized to stay under the cap, but
    # making the test independent of that sizing is cleaner.
    machine.succeed(
        "cryptsetup luksFormat -q --type=luks2 --pbkdf=pbkdf2 --pbkdf-force-iterations=1000 "
        "--keyfile-size=4096 --key-file=/dev/mapper/cryptkey /tmp/encrypted_root.img"
    )
    machine.succeed(
        "cryptsetup luksOpen --keyfile-size=4096 --key-file=/dev/mapper/cryptkey "
        "/tmp/encrypted_root.img encrypted_root"
    )
    machine.succeed("mkfs.btrfs -L root /dev/mapper/encrypted_root")

    # Let udev finish processing the dm events before we read the properties.
    machine.succeed("udevadm settle --timeout=15")

    with subtest("cryptkey dm device is marked SYSTEMD_READY=1"):
        props = machine.succeed(
            "udevadm info --query=property --name=/dev/mapper/cryptkey"
        )
        assert "SYSTEMD_READY=1" in props, (
            "cryptkey dm device was not marked SYSTEMD_READY=1 by udev; "
            "this is the regression that prevents systemd-cryptsetup@*.service "
            "from ever activating during initrd. udev properties:\n" + props
        )

    with subtest("encrypted_root dm device is not marked SYSTEMD_READY=0"):
        # blkid finds btrfs inside encrypted_root, so systemd's rule that
        # marks empty CRYPT-* devices as not-ready doesn't fire and
        # SYSTEMD_READY is left unset (which systemd treats as ready). We
        # only need to assert it isn't explicitly =0.
        props = machine.succeed(
            "udevadm info --query=property --name=/dev/mapper/encrypted_root"
        )
        assert "SYSTEMD_READY=0" not in props, (
            "encrypted_root dm device was marked SYSTEMD_READY=0 unexpectedly. "
            "udev properties:\n" + props
        )

    with subtest("systemd activates the dm-mapper device units"):
        # If SYSTEMD_READY=1 above but these units don't activate, that's a
        # different (but related) regression in systemd's device-unit handling.
        machine.succeed("systemctl is-active dev-mapper-cryptkey.device")
        machine.succeed("systemctl is-active dev-mapper-encrypted_root.device")

    with subtest("by-label/root surfaces from the encrypted btrfs volume"):
        # The original symptom was /dev/disk/by-label/root timing out in
        # initrd. Verify the symlink shows up here as a final belt-and-braces.
        machine.succeed("test -L /dev/disk/by-label/root")
  '';
}
