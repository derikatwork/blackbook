#!/usr/bin/env bash
# Install NixOS on the Lenovo 14e Chromebook, from the NixOS 26.05 minimal
# installer USB. See README.md, section 7.
#
# Usage, from the folder you cloned this repo into:
#   sudo ./scripts/install.sh /dev/mmcblk0
#
# !!! This ERASES the whole disk you name, including ChromeOS. !!!
#
# What it does, in order:
#   1. Partition the disk (GPT: 1 GiB EFI partition + the rest)
#   2. Format (FAT32 "BOOT", btrfs "nixos")
#   3. Create btrfs subvolumes @, @home, @nix, @log
#   4. Mount everything under /mnt
#   5. Copy this repo to /mnt/home/<user>/nixos-config
#   6. Check the detected hardware's kernel modules against the repo
#   7. Install NixOS (nixos-install)
#   8. Set your password
#   9. Give the repo to your user
#  10. Print the next steps
set -euo pipefail

# The flake output to install; also the folder under hosts/.
HOST="liara"

# Make sure flakes work, even if the installer does not enable them.
export NIX_CONFIG="experimental-features = nix-command flakes"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DETECTED="/tmp/hardware-detected.nix"
BTRFS_OPTS="compress=zstd:1,noatime"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    WARNING: %s\033[0m\n' "$*"; }
die() {
  printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2
  exit 1
}

usage() {
  cat >&2 <<EOF
Usage: sudo $0 DISK

DISK is the whole internal disk, for example /dev/mmcblk0.
Find it with:  lsblk -o NAME,SIZE,MODEL,TRAN,RM
Everything on DISK will be erased.
EOF
  exit 1
}

# Read one value out of hosts/$HOST/configuration.nix without downloading
# anything. (The file is a function that ignores its arguments.)
config_value() {
  CONF="$REPO/hosts/$HOST/configuration.nix" nix eval --impure --raw --expr \
    "(import (builtins.getEnv \"CONF\") { }).$1"
}

# Print one kernel-module list from a hardware-configuration.nix file, one
# name per line. Only the requested list is evaluated, so the stand-in
# arguments below are never used for anything else.
module_list() {
  HW="$1" nix eval --impure --raw --expr "
    let
      hw = import (builtins.getEnv \"HW\") {
        config = { };
        lib = { };
        pkgs = { };
        modulesPath = \"/\";
      };
      get = path: (builtins.foldl' (set: name: set.\${name} or { }) hw path);
      list = path: let v = get path; in if builtins.isList v then v else [ ];
    in
      builtins.concatStringsSep \"\\n\" ($2)
  "
}

[ $# -eq 1 ] || usage

# ---- Checks before anything is changed ---------------------------------------
step "Checking that it is safe to start"

[ "$(id -u)" -eq 0 ] || die "Please run this with sudo:  sudo $0 $1"
if [ ! -e /etc/NIXOS ] || ! command -v nixos-install >/dev/null; then
  die "This must be run from the NixOS installer USB."
fi
[ -d /sys/firmware/efi ] ||
  die "The installer did not start in UEFI mode. Make sure the MrChromebox UEFI Full ROM firmware is installed (README section 5). Then restart, press Esc at the rabbit logo, choose Boot Menu, and pick the USB stick."
if [ ! -f "$REPO/flake.nix" ] || [ ! -f "$REPO/hosts/$HOST/configuration.nix" ]; then
  die "Cannot find flake.nix and hosts/$HOST/ in $REPO."
fi

USERNAME="$(config_value local.username)"
HOSTNAME_CFG="$(config_value networking.hostName)"
[ -n "$USERNAME" ] || die "Could not read local.username from hosts/$HOST/configuration.nix."
[ "$HOSTNAME_CFG" = "$HOST" ] ||
  die "hosts/$HOST/configuration.nix sets networking.hostName = \"$HOSTNAME_CFG\", expected \"$HOST\"."
info "Will install configuration '$HOST' for user '$USERNAME'."

info "Checking the internet connection..."
curl --silent --fail --head --max-time 20 https://cache.nixos.org/nix-cache-info >/dev/null ||
  die "Cannot reach cache.nixos.org. Connect to Wi-Fi first with: nmtui"

DISK="$(readlink -f -- "$1")" || die "$1 does not exist. Check the name with: lsblk -o NAME,SIZE,MODEL,TRAN,RM"
[ -b "$DISK" ] || die "$1 is not a disk. Check the name with: lsblk -o NAME,SIZE,MODEL,TRAN,RM"
[ "$(lsblk -dno TYPE "$DISK")" = "disk" ] ||
  die "$DISK is a partition, not a whole disk. Use the disk itself, for example /dev/mmcblk0 (not /dev/mmcblk0p1)."

step "Disks in this computer"
lsblk -o NAME,SIZE,MODEL,TRAN,RM
echo

TRAN="$(lsblk -dno TRAN "$DISK" | tr -d '[:space:]')"
REMOVABLE="$(lsblk -dno RM "$DISK" | tr -d '[:space:]')"
[ "$TRAN" != "usb" ] || die "$DISK is a USB drive (TRAN=usb). Refusing to erase it."
[ "$REMOVABLE" != "1" ] || die "$DISK is a removable drive (RM=1). Refusing to erase it."

DISK_NAME="$(basename "$DISK")"
if [ -r "/sys/block/$DISK_NAME/device/type" ] && [ "$(cat "/sys/block/$DISK_NAME/device/type")" = "SD" ]; then
  die "$DISK is an SD card, not the internal eMMC. Refusing to erase it."
fi

SIZE_BYTES="$(lsblk -bdno SIZE "$DISK" | tr -d '[:space:]')"
[ "$SIZE_BYTES" -ge $((10 * 1024 * 1024 * 1024)) ] ||
  die "$DISK is smaller than 10 GiB. That is too small for this system."

# A previous run of this script may have left things mounted at /mnt.
if mountpoint -q /mnt; then
  info "Unmounting /mnt left over from an earlier run..."
  umount -R /mnt
fi
if lsblk -nro MOUNTPOINTS "$DISK" | grep -q .; then
  die "Part of $DISK is in use (mounted or used as swap). Is this the installer USB? Check with lsblk."
fi

case "$DISK" in
  *[0-9]) PART1="${DISK}p1" PART2="${DISK}p2" ;; # mmcblk0 -> mmcblk0p1
  *) PART1="${DISK}1" PART2="${DISK}2" ;;        # sda -> sda1
esac

MODEL="$(lsblk -dno MODEL "$DISK" | sed 's/[[:space:]]*$//')"
SIZE_HUMAN="$(lsblk -dno SIZE "$DISK" | tr -d '[:space:]')"

printf '\n\033[1;31m'
cat <<EOF
  !!! WARNING !!!
  EVERYTHING on $DISK ($SIZE_HUMAN ${MODEL:-unknown model}) will be ERASED.
  ChromeOS and all files on this disk will be gone for good.
EOF
printf '\033[0m\n'
read -r -p "To continue, type the full device path ($DISK) and press Enter: " ANSWER
[ "$ANSWER" = "$DISK" ] || die "You typed '$ANSWER', not '$DISK'. Nothing was changed."

# ---- 1. Partition -------------------------------------------------------------
step "1/10  Partitioning $DISK: 1 GiB EFI partition, the rest for NixOS"
wipefs --all --quiet "$DISK"
sgdisk --zap-all "$DISK" >/dev/null
parted --script --align optimal "$DISK" -- \
  mklabel gpt \
  mkpart BOOT fat32 1MiB 1025MiB \
  set 1 esp on \
  mkpart nixos btrfs 1025MiB 100%
partprobe "$DISK" || true
udevadm settle
if [ ! -b "$PART1" ] || [ ! -b "$PART2" ]; then
  die "The new partitions $PART1 and $PART2 did not appear."
fi

# ---- 2. Format ----------------------------------------------------------------
step "2/10  Formatting: FAT32 labeled BOOT, btrfs labeled nixos"
wipefs --all --quiet "$PART1" "$PART2"
mkfs.fat -F 32 -n BOOT "$PART1" >/dev/null
mkfs.btrfs --force --label nixos "$PART2" >/dev/null
udevadm settle

# The system mounts by label, so each label must exist exactly once.
for label in BOOT nixos; do
  count="$(lsblk -rno LABEL | grep -cxF -- "$label" || true)"
  [ "$count" -eq 1 ] ||
    die "Found $count partitions labeled '$label' (expected 1). Unplug other drives (keep the installer USB) and run this script again."
done

# ---- 3. Subvolumes ------------------------------------------------------------
step "3/10  Creating btrfs subvolumes: @ (/), @home, @nix, @log (/var/log)"
mount "$PART2" /mnt
for subvol in @ @home @nix @log; do
  btrfs subvolume create "/mnt/$subvol" >/dev/null
done
umount /mnt

# ---- 4. Mount -----------------------------------------------------------------
step "4/10  Mounting everything under /mnt"
mount -o "subvol=@,$BTRFS_OPTS" /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/home /mnt/nix /mnt/var/log /mnt/boot
mount -o "subvol=@home,$BTRFS_OPTS" /dev/disk/by-label/nixos /mnt/home
mount -o "subvol=@nix,$BTRFS_OPTS" /dev/disk/by-label/nixos /mnt/nix
mount -o "subvol=@log,$BTRFS_OPTS" /dev/disk/by-label/nixos /mnt/var/log
mount -o umask=0077 /dev/disk/by-label/BOOT /mnt/boot
findmnt --real --submounts --target /mnt --output TARGET,SOURCE,FSTYPE,OPTIONS | sed 's/^/    /'

# ---- 5. Copy the repo ---------------------------------------------------------
TARGET_REPO="/mnt/home/$USERNAME/nixos-config"
step "5/10  Copying this repo to $TARGET_REPO"
mkdir -p "$TARGET_REPO"
cp -a "$REPO/." "$TARGET_REPO/"
# Owned by root until step 9, so git (used by nixos-install) trusts it.
chown -R 0:0 "$TARGET_REPO"

# ---- 6. Kernel module check ---------------------------------------------------
step "6/10  Checking the detected hardware against hosts/$HOST/hardware-configuration.nix"
nixos-generate-config --root /mnt --show-hardware-config >"$DETECTED"
REPO_HW="$TARGET_REPO/hosts/$HOST/hardware-configuration.nix"

INITRD='list [ "boot" "initrd" "availableKernelModules" ] ++ list [ "boot" "initrd" "kernelModules" ]'
KERNEL='list [ "boot" "kernelModules" ]'

# Read each list on its own first, so a failure stops the script instead of
# looking like "nothing is missing".
detected_initrd="$(module_list "$DETECTED" "$INITRD")" || die "Could not read the module lists from $DETECTED."
detected_kernel="$(module_list "$DETECTED" "$KERNEL")" || die "Could not read the module lists from $DETECTED."
repo_initrd="$(module_list "$REPO_HW" "$INITRD")" || die "Could not read the module lists from $REPO_HW."
repo_kernel="$(module_list "$REPO_HW" "$KERNEL")" || die "Could not read the module lists from $REPO_HW."
[ -n "$detected_initrd" ] || die "nixos-generate-config found no kernel modules at all, which should not happen. See $DETECTED."

missing_initrd="$(comm -23 <(printf '%s\n' "$detected_initrd" | sort -u) <(printf '%s\n' "$repo_initrd" | sort -u))"
missing_kernel="$(comm -23 <(printf '%s\n' "$detected_kernel" | sort -u) <(printf '%s\n' "$repo_kernel" | sort -u))"

if [ -n "$missing_initrd$missing_kernel" ]; then
  umount -R /mnt
  printf '\n\033[1;31mSTOPPED: the hardware needs kernel modules that the repo does not list.\033[0m\n\n'
  if [ -n "$missing_initrd" ]; then
    echo "Add these to boot.initrd.availableKernelModules:"
    # shellcheck disable=SC2086 # one module name per word
    printf '  "%s"\n' $missing_initrd
  fi
  if [ -n "$missing_kernel" ]; then
    echo "Add these to boot.kernelModules:"
    # shellcheck disable=SC2086 # one module name per word
    printf '  "%s"\n' $missing_kernel
  fi
  cat <<EOF

What to do:
  1. Open the file:  nano $REPO/hosts/$HOST/hardware-configuration.nix
  2. Add each name above, in quotes, inside the matching [ ... ] list.
  3. Save (Ctrl+O, Enter) and exit (Ctrl+X).
  4. Run this script again. It starts over; nothing has been installed yet.
  5. After the install, commit and push that change so GitHub has it too.

The full detected configuration is saved in $DETECTED.
Nothing was installed. (The disk was already erased and partitioned.)
EOF
  exit 1
fi
info "All detected kernel modules are in the repo."

# ---- 7. Install ---------------------------------------------------------------
step "7/10  Installing NixOS. This downloads about 2 GB and takes a while."
info "Everything comes ready-made from cache.nixos.org; only small config files are built here."
# --no-channel-copy: this system uses the flake, not the installer's channel.
nixos-install --root /mnt --flake "$TARGET_REPO#$HOST" --no-root-passwd --no-channel-copy

# ---- 8. Password --------------------------------------------------------------
step "8/10  Choose the password for '$USERNAME'"
info "You will use it for sudo and to unlock the screen. Nothing shows while you type."
until nixos-enter --root /mnt -c "passwd $USERNAME"; do
  warn "The password was not set. Please try again."
done

# ---- 9. Ownership -------------------------------------------------------------
step "9/10  Giving ~/nixos-config to '$USERNAME'"
nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME && chmod 700 /home/$USERNAME"

# ---- 10. Done -----------------------------------------------------------------
step "10/10  Final checks"
if [ -f /mnt/boot/EFI/BOOT/BOOTX64.EFI ]; then
  info "Fallback boot loader \\EFI\\BOOT\\BOOTX64.EFI is in place."
else
  warn "\\EFI\\BOOT\\BOOTX64.EFI is missing. The laptop should still boot; see docs/troubleshooting.md."
fi

cat <<EOF

  NixOS is installed.

  Next steps:
    1. Type:  reboot
    2. Remove the USB stick when the screen goes dark.
    3. The boot menu shows for 2 seconds, then the desktop starts by itself.
    4. Connect to Wi-Fi with the Wi-Fi icon at the bottom right.
    5. Open a terminal (Ctrl+Alt+T) and run:  sudo tailscale up
    6. Go through docs/post-install-checklist.md.

EOF
