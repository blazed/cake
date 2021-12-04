{ config, lib, writeStrictShellScriptBin, ... }:

let
  inherit (lib) mapAttrsToList listToAttrs splitString concatStringsSep last flatten;
  inherit (builtins) filter match head foldl' replaceStrings;
  bootMode = if config.config.boot.loader.systemd-boot.enable then "UEFI" else "Legacy";
  encrypted = config.config.boot.initrd.luks != null;
  diskLabels = {
    boot = "boot";
    encCryptkey = "cryptkey";
    swap = "swap";
    encSwap = "encrypted_swap";
    root = "root";
    encRoot = "encrypted_root";
    encRoot2 = "encrypted_root2";
    extra = "extra";
    encExtra = "encrypted_extra";
  };
  efiSpace = "500M";
  luksKeySpace = "20M";
  ramGb = "$(free --giga | tail -n+2 | head -1 | awk '{print $2}')";
  uuidCryptKey = if config.config.boot.initrd.luks != null then config.config.boot.initrd.luks.devices.cryptkey.keyFile != null else false;
  subvolumes = lib.unique (filter (v: v != null)
        (flatten
            (map (match "^subvol=(.*)")
              (foldl' (a: b: a ++ b.options) []
                (filter (v: v.fsType == "btrfs") (mapAttrsToList (_: v: v) config.config.fileSystems))
              )
            )
        )
  );
in
  writeStrictShellScriptBin "diskformat" ''
    DIR=$(CDPATH=''' cd -- "$(dirname -- "$0")" && pwd -P)

    retry() {
      n=''${1:-1}
      sleepwait=5
      shift
      if [ "$n" -le 0 ]; then
         echo "\"$*\"" failed - giving up
         sleep 10
         exit 1
      fi
      n=$((n - 1))
      if ! eval "$@"; then
        echo "\"$*\" failed, will retry in 5 seconds"
        sleep "$sleepwait"
        echo retrying "\"$*\""
        retry "$n" "$@"
      else
          echo "\"$*\"" succeeded
      fi
    }
    retryDefault() {
        retry 2 "$@"
    }

    BOOTMODE="${bootMode}"
    DEVRANDOM=/dev/urandom

    if [ "$(systemd-detect-virt)" = "none" ]; then
      CRYPTKEYFILE="''${CRYPTKEYFILE:-/sys/class/dmi/id/product_uuid}"
    else
      CRYPTKEYFILE="''${CRYPTKEYFILE:-/sys/class/dmi/id/product_version}"
    fi

    USER_DISK_PASSWORD=${if uuidCryptKey then "no" else "yes"}

    ENCRYPTED=${if encrypted then "yes" else "no"}

    DISK_PASSWORD=""
    if [ "$ENCRYPTED" = "yes" ]; then
      if [ "$USER_DISK_PASSWORD" = "yes" ]; then
        while true; do
          echo -n Disk password:
          read -r -s DISK_PASSWORD
          echo
          echo -n Enter disk password again:
          read -r -s DISK_PASSWORD2
          if [ "$DISK_PASSWORD" = "$DISK_PASSWORD2" ]; then
            if [ -z "$DISK_PASSWORD" ]; then
              unset DISK_PASSWORD
              unset DISK_PASSWORD2
              echo "Passwords are empty, please enter them again"
            else
              unset DISK_PASSWORD2
              break
            fi
          else
            unset DISK_PASSWORD
            unset DISK_PASSWORD2
            echo "Passwords don't match, please enter them again"
          fi
        done
      fi
    fi 

    if [ ! -d "/secrets" ]; then
      mkdir -p /secrets
      mount -t tmpfs -o size=64m tmpfs /secrets
    fi

    if [ -n "$DISK_PASSWORD" ]; then
      CRYPTKEYFILE=/secrets/disk_password
      echo -n "$DISK_PASSWORD" > "$CRYPTKEYFILE"
    fi

    if [ "$(stat -c %s "$CRYPTKEYFILE")" -lt 2 ]; then
        echo "$CRYPTKEYFILE too small, less than 2 bytes"
        exit 1
    fi

    DISK=/dev/nvme0n1
    DISK2=/dev/sdb
    PARTITION_PREFIX="p"

    if [ ! -b "$DISK" ]; then
      echo "$DISK" is not a block device
      PARTITION_PREFIX=""
      DISK=/dev/sda
    fi

    if [ ! -b "$DISK" ]; then
      echo "$DISK" is not a block device
      PARTITION_PREFIX=""
      DISK=/dev/vda
    fi

    if [ ! -b "$DISK" ]; then
      echo "$DISK" is not a block device
      echo Giving up
      exit 1
    fi

    echo Formatting disk "$DISK"

    set -x

    wipefs -fa "$DISK"
    sgdisk -z "$DISK"
    partprobe "$DISK"

    if [ -b "$DISK2" ]; then
      wipefs -fa "$DISK2"
      sgdisk -z "$DISK2"
      partprobe "$DISK2"
    fi

    efi_space="${efiSpace}"
    luks_key_space="${luksKeySpace}"
    ramgb="${ramGb}"
    swap_space="$((ramgb / 2))"
    if [ "$swap_space" = "0" ]; then
      swap_space="1"
    else
      swap_space="$((swap_space + ramgb))"
    fi
    swap_space="$swap_space"G
    echo Will use a "$swap_space" swap space partition

    sgdisk -og "$DISK"
    partprobe "$DISK"

    if [ -b "$DISK2" ]; then
      sgdisk -og "$DISK2"
      partprobe "$DISK2"
    fi

    partnum=0

    if [ "$BOOTMODE" = "Legacy" ]; then
      partnum=$((partnum + 1))
      sgdisk -n 0:0:+20M -t 0:ef02 -c 0:"biosboot" -u 0:"21686148-6449-6E6F-744E-656564454649" "$DISK" # 1
    fi
    sgdisk -n 0:0:+$efi_space -t 0:ef00 -c 0:"efi" "$DISK" # 1
    sgdisk -n 0:0:+$luks_key_space -t 0:8300 -c 0:"cryptkey" "$DISK" # 2
    sgdisk -n 0:0:+$swap_space -t 0:8300 -c 0:"swap" "$DISK" # 3
    sgdisk -n 0:0:0 -t 0:8300 -c 0:"root" "$DISK" # 4
    partprobe "$DISK"

    if [ -b "$DISK2" ]; then
      if [ "$BOOTMODE" = "Legacy" ]; then
        sgdisk -n 0:0:+20M -t 0:ef02 -c 0:"biosboot" -u 0:"21686148-6449-6E6F-744E-656564454649" "$DISK" # 1
      fi
      sgdisk -n 0:0:+$efi_space -t 0:ef00 -c 0:"efi" "$DISK2" # 1
      sgdisk -n 0:0:+$luks_key_space -t 0:8300 -c 0:"cryptkey" "$DISK2" # 2
      sgdisk -n 0:0:+$swap_space -t 0:8300 -c 0:"swap" "$DISK2" # 3
      sgdisk -n 0:0:0 -t 0:8300 -c 0:"root" "$DISK2" # 4
      partprobe "$DISK2"
    fi

    echo "PREFIX: $PARTITION_PREFIX"

    partnum=$((partnum + 1))
    DISK_EFI="$DISK$PARTITION_PREFIX$partnum"
    partnum=$((partnum + 1))
    DISK_CRYPTKEY="$DISK$PARTITION_PREFIX$partnum"
    partnum=$((partnum + 1))
    DISK_SWAP="$DISK$PARTITION_PREFIX$partnum"
    partnum=$((partnum + 1))
    if [ -b "$DISK2" ]; then
      DISK_ROOT2="$DISK2$PARTITION_PREFIX$partnum"
    fi
    DISK_ROOT="$DISK$PARTITION_PREFIX$partnum"

    sgdisk -p "$DISK"

    partprobe "$DISK"
    fdisk -l "$DISK"

    if [ -b "$DISK2" ]; then
      sgdisk -p "$DISK2"
      partprobe "$DISK2"
      fdisk -l "$DISK2"
    fi

    if [ "$ENCRYPTED" = "yes" ]; then
      echo Set up encrypted disks
      echo Formatting cryptkey disk "$DISK_CRYPTKEY", using keyfile "$CRYPTKEYFILE"
      cryptsetup luksFormat --label=${diskLabels.encCryptkey} -q --key-file="$CRYPTKEYFILE" "$DISK_CRYPTKEY"
      DISK_CRYPTKEY=/dev/disk/by-label/${diskLabels.encCryptkey}

      echo Opening cryptkey disk "$DISK_CRYPTKEY", using keyfile "$CRYPTKEYFILE"
      cryptsetup luksOpen --key-file="$CRYPTKEYFILE" "$DISK_CRYPTKEY" ${diskLabels.encCryptkey}

      echo Writing random data to /dev/mapper/${diskLabels.encCryptkey}
      dd if=$DEVRANDOM of=/dev/mapper/${diskLabels.encCryptkey} bs=1024 count=14000 || true

      echo Creating encrypted swap
      cryptsetup luksFormat --label=${diskLabels.encSwap} -q --key-file=/dev/mapper/${diskLabels.encCryptkey} "$DISK_SWAP"

      echo Creating encrypted root
      cryptsetup luksFormat --label=${diskLabels.encRoot} -q --key-file=/dev/mapper/${diskLabels.encCryptkey} "$DISK_ROOT"

      if [ -b "$DISK2" ]; then
        echo Creating encrypted root 2
        cryptsetup luksFormat --label=${diskLabels.encRoot2} -q --key-file=/dev/mapper/${diskLabels.encCryptkey} "$DISK_ROOT2"
      fi

      echo Opening encrypted swap using keyfile
      cryptsetup luksOpen --key-file=/dev/mapper/${diskLabels.encCryptkey} "$DISK_SWAP" ${diskLabels.encSwap}
      mkswap -L ${diskLabels.swap} /dev/mapper/${diskLabels.encSwap}

      echo Opening encrypted root using keyfile
      cryptsetup luksOpen --key-file=/dev/mapper/${diskLabels.encCryptkey} "$DISK_ROOT" ${diskLabels.encRoot}

      if [ -b "$DISK2" ]; then
        echo Opening encrypted root2 using keyfile
        cryptsetup luksOpen --key-file=/dev/mapper/${diskLabels.encCryptkey} "$DISK_ROOT2" ${diskLabels.encRoot2}
      fi

      if [ -b "$DISK2" ]; then
        echo Creating btrfs RAID0 filesystem on /dev/mapper/${diskLabels.encRoot} and /dev/mapper/${diskLabels.encRoot2}
        mkfs.btrfs -f -L ${diskLabels.root} -d raid0 /dev/mapper/${diskLabels.encRoot} /dev/mapper/${diskLabels.encRoot2}
      else
        echo Creating btrfs filesystem on /dev/mapper/${diskLabels.encRoot}
        mkfs.btrfs -f -L ${diskLabels.root} /dev/mapper/${diskLabels.encRoot}
      fi

      echo Creating vfat disk at "$DISK_EFI"
      mkfs.vfat -n ${diskLabels.boot} "$DISK_EFI"

      partprobe /dev/mapper/${diskLabels.encSwap}
      partprobe /dev/mapper/${diskLabels.encCryptkey}
      # partprobe /dev/mapper/${diskLabels.encRoot}
    else
      echo Set up unencrypted disks
      mkswap -L ${diskLabels.swap} "$DISK_SWAP"

      echo Creating btrfs filesystem on $DISK_ROOT
      mkfs.btrfs -f -L ${diskLabels.root} $DISK_ROOT

      echo Creating vfat disk at "$DISK_EFI"
      mkfs.vfat -n ${diskLabels.boot} "$DISK_EFI"

      partprobe $DISK_SWAP
      partprobe $DISK_ROOT
    fi 

    mount -t tmpfs none /mnt
    mkdir -p "/mnt/tmproot" ${concatStringsSep " " (map (v: "/mnt/${replaceStrings ["@"] [""] v}") subvolumes)} "/mnt/boot"

    echo Temporarily mounting root btrfs volume from "/dev/disk/by-label/$DISK_ROOT_LABEL" to /mnt/tmproot
    retryDefault mount -o rw,noatime,compress=zstd,ssd,space_cache /dev/disk/by-label/${diskLabels.root} /mnt/tmproot

    # now create the btrfs subvolumes we're interested in having
    echo Creating btrfs subvolumes at /mnt/tmproot
    cd /mnt/tmproot
    ${concatStringsSep "\n" (map (v: "btrfs sub create ${v}") subvolumes)}

    cd "$DIR"

    echo Unmounting /mnt/tmproot
    umount /mnt/tmproot
    rmdir /mnt/tmproot

    echo Devices with uuids
    ls -lah /dev/disk/by-uuid/

    echo Devices with labels
    ls -lah /dev/disk/by-label/

    ${concatStringsSep "\n" (map (v: ''mount -o rw,noatime,compress=zstd,ssd,space_cache,subvol=${v} /dev/disk/by-label/${diskLabels.root} /mnt/${replaceStrings ["@"] [""] v}'') subvolumes)}

    # and mount the boot partition
    echo Mounting boot partition
    mount /dev/disk/by-label/"$DISK_EFI_LABEL" /mnt/boot
 ''

