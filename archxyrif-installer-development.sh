#!/usr/bin/env bash
#===COLOR-MAPPER===#
# Color codes
GREEN="\e[32m" ; YELLOW="\e[33m" ; CYAN="\e[36m" ; RESET="\e[0m"
#===COLOR-MAPPER===#
#===========================================================================#
# GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88        
# Author  : Terra88 
# Purpose : Arch Linux custom installer
# GitHub  : http://github.com/Terra88
#===========================================================================
#===========================================================================
# Source variables
#===========================================================================
#===========================================================================
# Preparation
#===========================================================================
# Arch logo: Edited manually by Terra88
#===========================================================================
clear
logo(){
echo "#===================================================================================================#"
echo "| The Great Monolith of Installing Arch Linux!                                                      |"
echo "#===================================================================================================#"
echo "|                                                                                                   |"
echo "|        d8888                 888      Y88b   d88P                  d8b  .d888                     |"
echo "|       d88888                 888       Y88b d88P                   Y8P d88P                       |"
echo "|      d88P888                 888        Y88o88P                        888                        |"
echo "|     d88P 888 888d888 .d8888b 88888b.     Y888P    888  888 888d888 888 888888                     |"
echo "|    d88P  888 888P.  d88P.    888 .88b    d888b    888  888 888P.   888 888                        |"
echo "|   d88P   888 888    888      888  888   d88888b   888  888 888     888 888                        |"
echo "|  d8888888888 888    Y88b.    888  888  d88P Y88b  Y88b 888 888     888 888                        |"
echo "| d88P     888 888     .Y8888P 888  888 d88P   Y88b  .Y88888 888     888 888                        |"
echo "|                                                        888                                        |"
echo "|                                                   Y8b d88P                                        |"
echo "|                                                     Y88P                                          |"
echo "|         Semi-Automated / Interactive - Arch Linux Installer                                       |"
echo "|                                                                                                   |"
echo "|        GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88                               |"
echo "#===================================================================================================#"
echo "|-Table of Contents:                |-0) Disk Format INFO                                           |"
echo "#===================================================================================================#"
echo "|-1)Disk Selection & Format         |- UEFI & BIOS(LEGACY) SUPPORT                                  |"
echo "|-2)Pacstrap:Installing Base system |- wipes old signatures                                         |"
echo "|-3)Generating fstab                |- Partitions: BOOT/EFI(1024MiB)(/ROOT)(/HOME)(SWAP)            |"
echo "|-4)Setting Basic variables         |- Manual Resize for Root/Home & Swap on or off options         |"
echo "|-5)Installing GRUB for UEFI        |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |" 
echo "|-6)Setting configs/enabling.srv    |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |"
echo "|-7)Setting Pacman Mirror           |---------------------------------------------------------------|"
echo "|-Optional:                         |  ↜(╰ •ω•)╯ψ ↑_(ΦωΦ;)Ψ ୧( ಠ┏ل͜┓ಠ )୨ (ʘдʘ╬) ( •̀ᴗ•́ )و   (◣◢)ψ    |"
echo "|-8A)GPU-Guided install             |---------------------------------------------------------------|"
echo "|-8B)Guided Window Manager Install  |# Author  : Terra88(Tero.H)                                    |"
echo "|-8C)Guided Login Manager Install   |# Purpose : Arch Linux custom installer                        |"
echo "|-9)Extra Pacman & AUR PKG Install  |# GitHub  : http://github.com/Terra88                          |"
echo "|-If Hyprland Selected As WM        | ฅ^•ﻌ•^ฅ 【≽ܫ≼】 ( ͡° ᴥ ͡°) ^ↀᴥↀ^ ~(^._.) ∪ ̿–⋏ ̿–∪☆         |"
echo "|-10)Optional Theme install         | (づ｡◕‿‿◕｡)づ ◥(ฅº￦ºฅ)◤ (㇏(•̀ᵥᵥ•́)ノ) ＼(◑д◐)＞∠(◑д◐)          |"
echo "#===================================================================================================#"
echo "-1) Disk Selection: Format (Enter device path: example /dev/sda or /dev/nvme0 etc.)                 |"
echo "#===================================================================================================#"

}
#!/usr/bin/env bash
loadkeys fi
timedatectl set-ntp true
set -euo pipefail
#=========================================================================================================================================#
    # Helpers
#---------------------------------------
# Helpers & safety
#---------------------------------------
confirm() {
    # ask Yes/No, default Y
    local msg="${1:-Continue?}"
    read -r -p "$msg [Y/n]: " ans
    case "$ans" in
        [Nn]|[Nn][Oo]) return 1 ;;
        *) return 0 ;;
    esac
}

die() {
    echo -e "${YELLOW}ERROR:${RESET} $*" >&2
    exit 1
}

part_suffix() {
    local dev="$1"
    if [[ "$dev" =~ nvme|mmcblk ]]; then
        echo "p"
    else
        echo ""
    fi
}

# safe cleanup at script exit
cleanup() {
    echo -e "\n🧹 Running cleanup..."
    swapoff -a 2>/dev/null || true
    if mountpoint -q /mnt; then
        umount -R /mnt 2>/dev/null || true
    fi
    sync
    echo "✅ Cleanup done."
}
trap cleanup EXIT INT TERM
#=========================================================================================================================================#
initialize_cleanup() {
    echo -e "\n🛠 Initializing system for disk cleanup..."

    # Ensure /etc/mtab exists
    if [[ ! -e /etc/mtab ]]; then
        ln -sf /proc/self/mounts /etc/mtab
        echo "✅ /etc/mtab linked to /proc/self/mounts"
    fi

    # Turn off all swap
    echo "→ Disabling all swap devices..."
    swapoff -a 2>/dev/null || true

    # Close all LUKS devices
    echo "→ Closing all LUKS mappings..."
    for dm in /dev/mapper/*; do
        if [[ -L "$dm" ]]; then
            target=$(readlink -f "$dm" || true)
            echo "→ Attempting to luksClose $(basename "$dm")"
            cryptsetup luksClose "$(basename "$dm")" 2>/dev/null || true
        fi
    done

    # Deactivate all LVM volume groups
    echo "→ Deactivating all LVM volume groups..."
    if command -v vgchange &>/dev/null; then
        vgchange -an 2>/dev/null || true
    fi

    # Unmount all mounts, deepest first
    echo "→ Unmounting all mounted filesystems..."
    mapfile -t MOUNTS < <(mount | awk '{print $3}' | sort -r)
    for m in "${MOUNTS[@]}"; do
        umount -l "$m" 2>/dev/null || true
    done

    # Unmount leftover BTRFS mounts/subvolumes
    echo "→ Cleaning BTRFS subvolume mounts..."
    mapfile -t BTRFS_MOUNTS < <(mount | awk '/btrfs/ {print $3}' | sort -r)
    for bm in "${BTRFS_MOUNTS[@]}"; do
        umount -l "$bm" 2>/dev/null || true
    done

    # Zero first and last MiB of all disks (excluding loop devices)
    echo "→ Zeroing first and last MiB of all block devices..."
    for disk in /dev/sd? /dev/nvme?n?; do
        if [[ -b "$disk" && ! "$disk" =~ loop ]]; then
            size_bytes=$(blockdev --getsize64 "$disk" 2>/dev/null || echo 0)
            if (( size_bytes > 2*1024*1024 )); then
                echo "→ Zeroing first MiB of $disk"
                dd if=/dev/zero of="$disk" bs=1M count=1 oflag=direct status=none || true
                echo "→ Zeroing last MiB of $disk"
                dd if=/dev/zero of="$disk" bs=1M count=1 seek=$((size_bytes/(1024*1024)-1)) oflag=direct status=none || true
            fi
        fi
    done

    # Inform kernel of changes
    echo "→ Informing kernel of device changes..."
    for dev in /sys/block/*; do
        if [[ -w "$dev/device/delete" ]]; then
            echo 1 > "$dev/device/delete" 2>/dev/null || true
        fi
    done
    udevadm settle --timeout=5 2>/dev/null || true

    echo "✅ Full system cleanup complete. Disks ready for partitioning."
}
#=========================================================================================================================================#

#---------------------------------------
# Robust device cleanup helpers
#---------------------------------------
cleanup_device() {
    local dev="$1"
    echo -e "\n🧹 Cleaning device $dev ..."

    # turn off swaps referring to device
    mapfile -t SWAPS < <(swapon --show=NAME --noheadings || true)
    for s in "${SWAPS[@]}"; do
        if [[ "$s" == "$dev"* ]]; then
            echo "→ swapoff $s"
            swapoff "$s" || true
        fi
    done

    # unmount mounts referencing device, deepest first
    mapfile -t MOUNTS < <(mount | awk -v d="$dev" '$1 ~ d { print $3 }' | sort -r)
    for m in "${MOUNTS[@]}"; do
        echo "→ umount -l $m"
        umount -l "$m" 2>/dev/null || true
    done

    # handle btrfs mounts specifically
    mapfile -t BTRFS_MOUNTS < <(mount | awk '/btrfs/ {print $3}' | sort -r)
    for bm in "${BTRFS_MOUNTS[@]}"; do
        src=$(findmnt -n -o SOURCE "$bm" 2>/dev/null || true)
        if [[ "$src" == "$dev"* ]]; then
            echo "→ umount -l $bm"
            umount -l "$bm" 2>/dev/null || true
        fi
    done

    # clear /mnt contents if mounted
    if mountpoint -q /mnt; then
        echo "→ Cleaning /mnt"
        umount -R /mnt 2>/dev/null || true
        rm -rf /mnt/* 2>/dev/null || true
    fi

    # inform kernel
    echo "→ partprobe $dev ; udevadm settle"
    partprobe "$dev" 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true

    echo "✅ Device $dev cleaned."
}

#=========================================================================#
# Wrapper to unmount a device (simpler for quick unmount)
#=========================================================================#
unmount_device() {
    local dev="$1"
    echo -e "\n🔽 Unmounting mounts on $dev ..."
    mapfile -t MOUNTS < <(mount | awk -v d="$dev" '$1 ~ d { print $3 }' | sort -r)
    for m in "${MOUNTS[@]}"; do
        echo "→ umount -l $m"
        umount -l "$m" 2>/dev/null || true
    done

    if mountpoint -q /mnt; then
        umount -R /mnt 2>/dev/null || true
        rm -rf /mnt/* 2>/dev/null || true
    fi
    echo "✅ Unmounted $dev."
}

#=========================================================================================================================================#  
#---------------------------------------
# Partition table wipe helper
#---------------------------------------
clear_partition_table_luks_lvmsignatures() {
    local dev="$1"
    echo -e "\n⚠️  Wiping partition table & signatures on $dev (sgdisk/wipefs/dd)..."
    which sgdisk >/dev/null 2>&1 || die "sgdisk required"
    which wipefs >/dev/null 2>&1 || die "wipefs required"

    # close any LUKS pointing to the device
    for map in /dev/mapper/*; do
        if [[ -L "$map" ]]; then
            target=$(readlink -f "$map" || true)
            if [[ "$target" == "$dev"* ]]; then
                name=$(basename "$map")
                echo "→ cryptsetup luksClose $name"
                cryptsetup luksClose "$name" || true
            fi
        fi
    done

    # Zap and wipe
    sgdisk --zap-all "$dev" 2>/dev/null || true
    wipefs -a "$dev" 2>/dev/null || true

    # zero first and last MiB
    dd if=/dev/zero of="$dev" bs=1M count=2 oflag=direct status=none || true
    devsize_bytes=$(blockdev --getsize64 "$dev" 2>/dev/null || true)
    if [[ -n "$devsize_bytes" && "$devsize_bytes" -gt 1048576 ]]; then
        dd if=/dev/zero of="$dev" bs=1M count=1 oflag=direct seek=$(( (devsize_bytes / (1024*1024)) - 1 )) status=none || true
    fi

    swapoff -a 2>/dev/null || true
    echo "→ Finished clearing signatures on $dev."
}
#=========================================================================================================================#
# PACSTRAP - PKG LIST
#=========================================================================================================================#
install_base_system() {
    sleep 1
    clear
    echo
    echo "#===================================================================================================#"
    echo "# 2) Pacstrap: Installing Base system + recommended packages for basic use                          #"
    echo "#===================================================================================================#"
    echo

    # Ensure /mnt is mounted
    if ! mountpoint -q /mnt; then
        die "/mnt is not mounted — cannot continue."
    fi

    # Ensure /mnt/boot exists and is mounted (for UEFI)
    if [[ "$MODE" == "UEFI" ]]; then
        if ! mountpoint -q /mnt/boot/efi; then
            echo "⚠️  /mnt/boot/efi not mounted — attempting to mount EFI partition..."
            EFI_PART=$(lsblk -ln -o NAME,PARTTYPE | grep "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" | awk '{print "/dev/"$1}' | head -n1)
            [[ -n "$EFI_PART" ]] && mount "$EFI_PART" /mnt/boot/efi || die "Cannot find or mount EFI partition."
        fi
    else
        if ! mountpoint -q /mnt/boot; then
            echo "⚠️  /mnt/boot not mounted — attempting to mount BIOS boot partition..."
            BOOT_PART=$(lsblk -ln -o NAME,SIZE,MOUNTPOINT | grep -E "512M|500M" | grep -v "/mnt" | awk '{print "/dev/"$1}' | head -n1)
            [[ -n "$BOOT_PART" ]] && mount "$BOOT_PART" /mnt/boot || die "Cannot find or mount BIOS boot partition."
        fi
    fi

    # Ensure network is available
    if ! ping -c 2 -q archlinux.org >/dev/null 2>&1; then
        die "No internet connection. Please connect before proceeding."
    fi

    # Refresh mirrorlist and keyring
    echo "🔄 Syncing package databases and refreshing keyring..."
    pacman -Sy --noconfirm archlinux-keyring || die "Failed to sync keyring or package database."

    # Define package list
    PKGS=(
        base
        base-devel
        bash
        go
        git
        grub
        linux
        linux-zen
        linux-headers
        linux-firmware
        vim
        sudo
        nano
        networkmanager
        efibootmgr
        openssh
        intel-ucode
        amd-ucode
        btrfs-progs
    )

    echo
    echo "📦 Installing base system packages:"
    printf '%s\n' "${PKGS[@]}"
    echo

    pacstrap -K /mnt "${PKGS[@]}" || die "Pacstrap failed to install base system."

    echo "✅ Base system successfully installed."

    echo "🧾 Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab || die "Failed to generate fstab."
    echo "✅ fstab generated and appended."
}

#=========================================================================================================================#


#=========================================================================================================================================#
# 1.1) Clearing Partition Tables / Luks / LVM Signatures
#=========================================================================================================================================#

#-------HELPER FOR CHROOT--------------------------------#
prepare_chroot() {
    echo -e "\n🔧 Preparing pseudo-filesystems for chroot..."
    mkdir -p /mnt /mnt/proc /mnt/sys /mnt/dev /mnt/run /mnt/boot /mnt/home
    mount --types proc /proc /mnt/proc
    mount --rbind /sys /mnt/sys
    mount --make-rslave /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --make-rslave /mnt/dev
    mount --rbind /run /mnt/run
    mount --make-rslave /mnt/run
    echo "✅ Pseudo-filesystems mounted into /mnt."
}


#=========================================================================================================================================#

#----------------------------------------------#
#-------------------MAPPER---------------------#
#----------------------------------------------#
DEV=""            # set later by main_menu
MODE=""
BIOS_BOOT_PART_CREATED=false
SWAP_SIZE_MIB=0
ROOT_FS=""
HOME_FS=""
ROOT_SIZE_MIB=0
HOME_SIZE_MIB=0
EFI_SIZE_MIB=1024
BIOS_BOOT_SIZE_MIB=512
BOOT_SIZE_MIB=0
BUFFER_MIB=8
FS_CHOICE=1

#=========================================================================================================================================#
# -----------------------
# Detect boot mode
# -----------------------
detect_boot_mode() {
    if [[ -d /sys/firmware/efi ]]; then
        MODE="UEFI"
        BIOS_BOOT_PART_CREATED=false
        BOOT_SIZE_MIB=$EFI_SIZE_MIB
        echo -e "${CYAN}UEFI${RESET} detected."
    else
        MODE="BIOS"
        BIOS_BOOT_PART_CREATED=true
        BOOT_SIZE_MIB=$BIOS_BOOT_SIZE_MIB
        echo -e "${CYAN}Legacy BIOS${RESET} detected."
    fi
}
#=========================================================================================================================================#
# -----------------------
# Swap calculation
# -----------------------
calculate_swap() {
    local ram_kb
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    local ram_mib=$(( (ram_kb + 1023) / 1024 ))
    if (( ram_mib <= 8192 )); then
        SWAP_SIZE_MIB=$(( ram_mib * 2 ))
    else
        SWAP_SIZE_MIB=$ram_mib
    fi
    echo "Detected RAM ${ram_mib} MiB -> swap ${SWAP_SIZE_MIB} MiB"
}

#=========================================================================================================================================#

# -----------------------
# Ask partition sizes
# -----------------------
ask_partition_sizes() {
    if [[ -z "$MODE" ]]; then detect_boot_mode; fi

    local disk_bytes disk_mib disk_gib_val disk_gib_int
    disk_bytes=$(lsblk -b -dn -o SIZE "$DEV") || die "Cannot read disk size for $DEV"
    disk_mib=$(( disk_bytes / 1024 / 1024 ))
    disk_gib_val=$(awk -v m="$disk_mib" 'BEGIN{printf "%.2f", m/1024}')
    disk_gib_int=${disk_gib_val%.*}

    echo "Disk $DEV ≈ ${disk_gib_int} GiB"

    while true; do
        lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT "$DEV"
        local max_root_gib=$(( disk_gib_int - SWAP_SIZE_MIB/1024 - 5 ))
        read -rp "Enter ROOT size in GiB (max ${max_root_gib}): " ROOT_SIZE_GIB
        ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-$max_root_gib}"
        if ! [[ "$ROOT_SIZE_GIB" =~ ^[0-9]+$ ]]; then echo "Must be numeric"; continue; fi
        if (( ROOT_SIZE_GIB <= 0 || ROOT_SIZE_GIB > max_root_gib )); then echo "Invalid size"; continue; fi
        ROOT_SIZE_MIB=$(( ROOT_SIZE_GIB * 1024 ))
        local reserved_gib
        if [[ "$MODE" == "UEFI" ]]; then reserved_gib=$((EFI_SIZE_MIB/1024)); else reserved_gib=$((BIOS_BOOT_SIZE_MIB/1024)); fi
        REMAINING_HOME_GIB=$(( disk_gib_int - ROOT_SIZE_GIB - SWAP_SIZE_MIB/1024 - reserved_gib - 1 ))
        if (( REMAINING_HOME_GIB < 1 )); then echo "Not enough space for home"; continue; fi
        read -rp "Enter HOME size in GiB (ENTER for remaining ${REMAINING_HOME_GIB}): " HOME_SIZE_GIB
        HOME_SIZE_GIB="${HOME_SIZE_GIB:-$REMAINING_HOME_GIB}"
        if ! [[ "$HOME_SIZE_GIB" =~ ^[0-9]+$ ]]; then echo "Must be numeric"; continue; fi
        HOME_SIZE_MIB=$(( HOME_SIZE_GIB * 1024 ))
        echo "Root ${ROOT_SIZE_GIB} GiB, Home ${HOME_SIZE_GIB} GiB, Swap $((SWAP_SIZE_MIB/1024)) GiB, Reserved ${reserved_gib} GiB"
        break
    done
}

#=========================================================================================================================================#

# -----------------------
# Partition disk
# -----------------------
partition_disk() {

    partprobe $DEV
    
    [[ -z "$DEV" ]] && die "partition_disk(): missing device argument"

    echo "→ Creating partition table on $DEV ..."
    parted -s "$DEV" mklabel gpt || die "Failed to create GPT"

    if [[ "$MODE" == "BIOS" ]]; then
        echo "→ BIOS mode detected, creating partitions..."

        # BIOS boot partition (1MiB)
        parted -s "$DEV" mkpart primary 1MiB $((1 + BIOS_BOOT_SIZE_MIB))MiB
        parted -s "$DEV" set 1 bios_grub on

        # Boot partition (ext4)
        local boot_start=$((1 + BIOS_BOOT_SIZE_MIB))
        local boot_end=$((boot_start + BOOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary ext4 ${boot_start}MiB ${boot_end}MiB

        # Swap partition
        local swap_start=$boot_end
        local swap_end=$((swap_start + SWAP_SIZE_MIB))
        parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB

        # Root partition (btrfs)
        local root_start=$swap_end
        local root_end=$((root_start + ROOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary btrfs ${root_start}MiB ${root_end}MiB

        # Home partition (ext4, rest of disk)
        parted -s "$DEV" mkpart primary ext4 ${root_end}MiB 100%

    else
        echo "→ UEFI mode detected, creating partitions..."

        # EFI partition
        parted -s "$DEV" mkpart primary fat32 1MiB $((1 + EFI_SIZE_MIB))MiB
        parted -s "$DEV" set 1 boot on

        # Root partition (btrfs)
        local root_start=$((1 + EFI_SIZE_MIB))
        local root_end=$((root_start + ROOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary btrfs ${root_start}MiB ${root_end}MiB

        # Swap partition
        local swap_start=$root_end
        local swap_end=$((swap_start + SWAP_SIZE_MIB))
        parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB

        # Home partition (ext4, rest of disk)
        parted -s "$DEV" mkpart primary ext4 ${swap_end}MiB 100%
    fi

    # Inform kernel
    partprobe "$DEV" || true
    udevadm settle --timeout=5 || true

    echo "✅ Partitioning completed. Verify with lsblk."
}

format_and_mount() {
    [[ -z "$DEV" ]] && die "format_and_mount(): missing device argument"

    echo "🧱 Formatting and mounting partitions on $DEV..."

    if [[ "$MODE" == "BIOS" ]]; then
        local P_BIOS="${DEV}1"
        local P_BOOT="${DEV}2"
        local P_SWAP="${DEV}3"
        local P_ROOT="${DEV}4"
        local P_HOME="${DEV}5"
    else
        local P_EFI="${DEV}1"
        local P_ROOT="${DEV}2"
        local P_SWAP="${DEV}3"
        local P_HOME="${DEV}4"
    fi

    # === Format partitions ===
    if [[ "$MODE" == "BIOS" ]]; then
        mkfs.ext4 -L boot "$P_BOOT"
    else
        mkfs.fat -F32 "$P_EFI"
    fi

    mkswap -L swap "$P_SWAP"
    swapon "$P_SWAP"

    mkfs.btrfs -f -L root "$P_ROOT"
    mkfs.ext4 -L home "$P_HOME"

    # === Mount root and subvolumes ===
    mount "$P_ROOT" /mnt
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        # create subvolumes
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        btrfs subvolume create /mnt/@snapshots
        btrfs subvolume create /mnt/@cache
        btrfs subvolume create /mnt/@log
        umount /mnt

        # remount subvolumes
        mount -o subvol=@,noatime,compress=zstd "$P_ROOT" /mnt
        mkdir -p /mnt/{home,.snapshots,cache,log}
        mount -o subvol=@home "$P_ROOT" /mnt/home
        mount -o subvol=@snapshots "$P_ROOT" /mnt/.snapshots
        mount -o subvol=@cache "$P_ROOT" /mnt/cache
        mount -o subvol=@log "$P_ROOT" /mnt/log
    else
        mount "$P_ROOT" /mnt
        mkdir -p /mnt/home
        mount "$P_HOME" /mnt/home
    fi

    # === Mount boot or EFI ===
    mkdir -p /mnt/boot
    if [[ "$MODE" == "BIOS" ]]; then
        mount "$P_BOOT" /mnt/boot
    else
        mkdir -p /mnt/boot/efi
        mount "$P_EFI" /mnt/boot/efi
    fi

    echo "✅ All partitions mounted under /mnt."
}
#=========================================================================================================================================#
# -----------------------
# GRUB installation
# -----------------------
install_grub() {
    local ps
    ps=$(part_suffix "$DEV")
    local P1="${DEV}${ps}1"
    if [[ "$MODE" == "BIOS" ]]; then
        echo "Installing GRUB for BIOS..."
        prepare_chroot
        arch-chroot /mnt grub-install --target=i386-pc --recheck --boot-directory=/boot "$DEV" || die "grub-install (BIOS) failed"
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || die "grub-mkconfig failed"
    else
        echo "Installing GRUB (UEFI)..."

        # Determine EFI partition mountpoint and ensure it’s /boot/efi
        if ! mountpoint -q /mnt/boot/efi; then
          echo "→ Ensuring EFI system partition is mounted at /boot/efi..."
          mkdir -p /mnt/boot/efi
          mount "$P1" /mnt/boot/efi
        fi
        
        # Basic, minimal GRUB modules needed for UEFI boot
        GRUB_MODULES="part_gpt part_msdos fat ext2 normal boot efi_gop efi_uga gfxterm linux search search_fs_uuid"
        
        # Run grub-install safely inside chroot
        arch-chroot /mnt grub-install \
          --target=x86_64-efi \
          --efi-directory=/boot/efi \
          --bootloader-id=GRUB \
          --modules="$GRUB_MODULES" \
          --recheck \
          --no-nvram
        
        # Manually create /EFI/Boot fallback copy (BOOTX64.EFI)
        echo "→ Copying fallback EFI binary..."
        arch-chroot /mnt bash -c 'mkdir -p /boot/efi/EFI/Boot && cp -f /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/Boot/BOOTX64.EFI || true'
        
        # Ensure a clean efibootmgr entry (use the parent disk of $P1)
        DISK="${DEV}"
        PARTNUM=1
        LABEL="Arch Linux"
        LOADER='\EFI\GRUB\grubx64.efi'
        
        # Delete stale entries with same label to avoid duplicates
        for bootnum in $(efibootmgr -v | awk "/${LABEL}/ {print substr(\$1,5,4)}"); do
          efibootmgr -b "$bootnum" -B || true
        done
        
        # Create new entry
        efibootmgr -c -d "$DISK" -p "$PARTNUM" -L "$LABEL" -l "$LOADER"
        
        # Generate GRUB config inside chroot
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
        
        # Secure Boot Integration
        if command -v sbctl >/dev/null 2>&1; then
          echo "→ Signing EFI binaries for Secure Boot..."
          arch-chroot /mnt sbctl status || arch-chroot /mnt sbctl create-keys
          arch-chroot /mnt sbctl enroll-keys --microsoft
          arch-chroot /mnt sbctl sign --path /boot/efi/EFI/GRUB/grubx64.efi
          arch-chroot /mnt sbctl sign --path /boot/vmlinuz-linux
        fi
        
        echo "GRUB installation complete."
        echo
        echo "Verifying EFI boot entries..."
        efibootmgr -v || true
    fi
    echo "✅ GRUB installed."
}

generate_fstab() {
    mkdir -p /mnt/etc

    if [[ "$ROOT_FS" == "btrfs" ]]; then
        root_uuid=$(blkid -s UUID -o value "$P_ROOT")
        swap_uuid=$(blkid -s UUID -o value "$P_SWAP")

        {
            echo "# BTRFS subvolumes"
            echo "UUID=$root_uuid /               btrfs   defaults,noatime,compress=zstd,subvol=@       0 1"
            echo "UUID=$root_uuid /home           btrfs   defaults,noatime,compress=zstd,subvol=@home  0 2"
            echo "UUID=$root_uuid /.snapshots     btrfs   defaults,noatime,compress=zstd,subvol=@snapshots 0 2"
            echo "UUID=$root_uuid /cache          btrfs   defaults,noatime,compress=zstd,subvol=@cache 0 2"
            echo "UUID=$root_uuid /log            btrfs   defaults,noatime,compress=zstd,subvol=@log   0 2"
            echo "UUID=$swap_uuid none            swap    sw                                           0 0"
        } > /mnt/etc/fstab || die "Failed to write /mnt/etc/fstab"

    else
        root_uuid=$(blkid -s UUID -o value "$P_ROOT")
        home_uuid=$(blkid -s UUID -o value "$P_HOME")
        swap_uuid=$(blkid -s UUID -o value "$P_SWAP")

        {
            echo "# EXT4 root + home"
            echo "UUID=$root_uuid /       ext4    defaults,noatime 0 1"
            echo "UUID=$home_uuid /home  ext4    defaults,noatime 0 2"
            echo "UUID=$swap_uuid none   swap    sw 0 0"
        } > /mnt/etc/fstab || die "Failed to write /mnt/etc/fstab"
    fi

    echo "✅ All partitions formatted, subvolumes mounted, and fstab generated."
}

#=========================================================================================================================================#

#--------------------------------------#
# Helper: Show filesystem menu
#--------------------------------------#
select_filesystem() {
    clear
    echo "#===============================================================================#"
    echo "| 1.2) Filesystem Selection Options                                             |"
    echo "#===============================================================================#"
    echo "| 1) EXT4 (root + home)                                                         |"
    echo "|-------------------------------------------------------------------------------|"
    echo "| 2) BTRFS (root + home)                                                        |"
    echo "|-------------------------------------------------------------------------------|"
    echo "| 3) BTRFS root + EXT4 home                                                     |"
    echo "#===============================================================================#"
    read -rp "Select filesystem [default=1]: " FS_CHOICE
    FS_CHOICE="${FS_CHOICE:-1}"
    case "$FS_CHOICE" in
        1) ROOT_FS="ext4"; HOME_FS="ext4" ;;
        2) ROOT_FS="btrfs"; HOME_FS="btrfs" ;;
        3) ROOT_FS="btrfs"; HOME_FS="ext4" ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac
}

#=========================================================================================================================================#

# -----------------------
# Preview partitions (color-coded)
# -----------------------
preview_partitions() {
    BOOT_SIZE_MIB="${BOOT_SIZE_MIB:-0}"
    local P1_START=1
    local P1_END=$BOOT_SIZE_MIB
    local ROOT_START=$(( P1_END + 1 ))
    local ROOT_END=$(( ROOT_START + ROOT_SIZE_MIB - BUFFER_MIB ))
    local SWAP_START=$ROOT_END
    local SWAP_END=$(( SWAP_START + SWAP_SIZE_MIB - BUFFER_MIB ))
    local HOME_START=$SWAP_END
    local HOME_END=$(( HOME_START + HOME_SIZE_MIB - BUFFER_MIB ))

    echo -e "\nBoot Mode: ${CYAN}${MODE}${RESET}"
    printf "%-6s %-10s %-10s %-8s %-8s %s\n" "Part" "StartMiB" "EndMiB" "SizeGiB" "FS" "Purpose"
    printf "%-6s %-10s %-10s %-8s %-8s %s\n" "1" "$P1_START" "$P1_END" "$(((P1_END-P1_START)/1024))" "$( [[ $MODE == UEFI ]] && echo FAT32 || echo ext4 )" "$( [[ $MODE == UEFI ]] && echo EFI || echo /boot )"
    printf "%-6s %-10s %-10s %-8s %-8s %s\n" "2" "$ROOT_START" "$ROOT_END" "$ROOT_SIZE_GIB" "$ROOT_FS" "Root"
    printf "%-6s %-10s %-10s %-8s %-8s %s\n" "3" "$SWAP_START" "$SWAP_END" "$((SWAP_SIZE_MIB/1024))" "swap" "Swap"
    printf "%-6s %-10s %-10s %-8s %-8s %s\n" "4" "$HOME_START" "$HOME_END" "$HOME_SIZE_GIB" "$HOME_FS" "Home"
    echo
}

#=========================================================================================================================================#
configure_system(){

clear
sleep 1
echo
echo "#===================================================================================================#"
echo "# Generating fstab & Showing Partition Table / Mountpoints                                       #"
echo "#===================================================================================================#"
echo
sleep 1

echo "Generating /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Partition Table and Mountpoints:"
cat /mnt/etc/fstab

sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# Setting Basic variables for chroot (defaults provided)                                         #"
echo "#===================================================================================================#"
echo

DEFAULT_TZ="Europe/Helsinki"
read -r -p "Enter timezone [${DEFAULT_TZ}]: " TZ
TZ="${TZ:-$DEFAULT_TZ}"

DEFAULT_LOCALE="fi_FI.UTF-8"
read -r -p "Enter locale (LANG) [${DEFAULT_LOCALE}]: " LANG_LOCALE
LANG_LOCALE="${LANG_LOCALE:-$DEFAULT_LOCALE}"

DEFAULT_HOSTNAME="archbox"
read -r -p "Enter hostname [${DEFAULT_HOSTNAME}]: " HOSTNAME
HOSTNAME="${HOSTNAME:-$DEFAULT_HOSTNAME}"

DEFAULT_USER="user"
read -r -p "Enter username to create [${DEFAULT_USER}]: " NEWUSER
NEWUSER="${NEWUSER:-$DEFAULT_USER}"

#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# Running chroot and setting mkinitcpio - Setting Hostname, Username, enabling services etc.    #"
echo "#===================================================================================================#"
echo
#========================================================#
# inline script for arch-chroot operations "postinstall.sh"
# Ask for passwords before chroot (silent input)
cat > /mnt/root/postinstall.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
#========================================================#
# Variables injected by main installer
#========================================================#
TZ="{{TIMEZONE}}"
LANG_LOCALE="{{LANG_LOCALE}}"
HOSTNAME="{{HOSTNAME}}"
NEWUSER="{{NEWUSER}}"

#========================================================#
# 1) Timezone & hardware clock
#========================================================#
ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
hwclock --systohc
#========================================================#
# 2) Locale
#========================================================#
if ! grep -q "^${LANG_LOCALE} UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "${LANG_LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LANG_LOCALE}" > /etc/locale.conf

#========================================================#
# 3) Hostname & /etc/hosts
#========================================================#
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

#========================================================#
# 4) Keyboard layout
#========================================================#
echo "KEYMAP=fi" > /etc/vconsole.conf
echo "FONT=lat9w-16" >> /etc/vconsole.conf
localectl set-keymap fi
localectl set-x11-keymap fi

#========================================================#
# 5) Initramfs
#========================================================#
mkinitcpio -P

#========================================================#
# 6) Root + user passwords (interactive)
#========================================================#
set +e  # allow retries
MAX_RETRIES=3

# Ensure user exists
if ! id "$NEWUSER" &>/dev/null; then
    echo "Creating user '$NEWUSER'..."
    useradd -m -G wheel -s /bin/bash "$NEWUSER"
fi
#========================================================#
clear
# Root password
echo
echo "#========================================================#"
echo " Set ROOT password                                       #"
echo "#========================================================#"
for i in $(seq 1 $MAX_RETRIES); do
    if passwd root; then
        break
    else
        echo "⚠️ Passwords did not match. Try again. ($i/$MAX_RETRIES)"
    fi
done
#========================================================#
# User password
echo "#=======================================================#"
echo " Set password for user '$NEWUSER'                       #"
echo "#=======================================================#"
for i in $(seq 1 $MAX_RETRIES); do
    if passwd "$NEWUSER"; then
        break
    else
        echo "⚠️ Passwords did not match. Try again. ($i/$MAX_RETRIES)"
    fi
done
#========================================================#
# Give sudo rights
echo "$NEWUSER ALL=(ALL:ALL) ALL" > /etc/sudoers.d/$NEWUSER
chmod 440 /etc/sudoers.d/$NEWUSER
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

set -e  # restore strict error handling

#========================================================#
# 7) Home directory setup
#========================================================#
HOME_DIR="/home/$NEWUSER"
CONFIG_DIR="$HOME_DIR/.config"
mkdir -p "$CONFIG_DIR"
chown -R "$NEWUSER:$NEWUSER" "$HOME_DIR"

#========================================================#
# 8) Enable basic services
#========================================================#
systemctl enable NetworkManager
systemctl enable sshd

echo "Postinstall inside chroot finished."
EOF
#=========================================================================================================================================#
echo "#===================================================================================================#"
echo "# Inject variables into /mnt/root/postinstall.sh                                                #"
echo "#===================================================================================================#"

# Replace placeholders with actual values (safe substitution)
sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh

chmod +x /mnt/root/postinstall.sh

# chroot and run postinstall.sh
echo "Entering chroot to run postinstall.sh..."
arch-chroot /mnt /root/postinstall.sh

# Remove postinstall.sh after execution
rm -f /mnt/root/postinstall.sh

echo "✅ Chroot configuration complete."

#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 7A) INTERACTIVE MIRROR SELECTION & OPTIMIZATION                                                   #"
echo "#===================================================================================================#"
echo

echo
echo "#========================================================#"
echo "📡 Arch Linux Mirror Selection & Optimization"
echo "#========================================================#"
echo "Choose your country or region for faster package downloads."

# Ensure reflector is installed in chroot
arch-chroot /mnt pacman -Sy --needed --noconfirm reflector || {
    echo "⚠️ Failed to install reflector inside chroot — continuing with defaults."
}
echo "#========================================================#"
echo "#                   MIRROR SELECTION                     #" 
echo "#========================================================#"
echo
echo "Available mirror regions:"
echo "1) United States"
echo "2) Canada"
echo "3) Germany"
echo "4) Finland"
echo "5) United Kingdom"
echo "6) Japan"
echo "7) Australia"
echo "8) Custom country code (2-letter ISO, e.g., FR)"
echo "9) Skip (use default mirrors)"
read -r -p "Select your region [1-9, default=1]: " MIRROR_CHOICE
MIRROR_CHOICE="${MIRROR_CHOICE:-1}"

case "$MIRROR_CHOICE" in
    1) SELECTED_COUNTRY="United States" ;;
    2) SELECTED_COUNTRY="Canada" ;;
    3) SELECTED_COUNTRY="Germany" ;;
    4) SELECTED_COUNTRY="Finland" ;;
    5) SELECTED_COUNTRY="United Kingdom" ;;
    6) SELECTED_COUNTRY="Japan" ;;
    7) SELECTED_COUNTRY="Australia" ;;
    8)
        read -r -p "Enter 2-letter country code (e.g., FR): " CUSTOM_CODE
        SELECTED_COUNTRY="$CUSTOM_CODE"
        ;;
    9|*) echo "Skipping mirror optimization, using default mirrors."; SELECTED_COUNTRY="" ;;
esac

if [[ -n "$SELECTED_COUNTRY" ]]; then
    echo "Optimizing mirrors for: $SELECTED_COUNTRY"
    arch-chroot /mnt reflector --country "$SELECTED_COUNTRY" --age 12 --protocol https --sort rate \
        --save /etc/pacman.d/mirrorlist || echo "⚠️ Mirror update failed, continuing."
    echo "✅ Mirrors updated."
fi
#=========================================================================================================================================#

}

#=========================================================================================================================================#
optional_install_setup(){

#===================================================================================================#
# 7B) Helper Functions - For Pacman                                                                  
#===================================================================================================#

# Resilient installation with retries, key refresh, and mirror recovery
install_with_retry() {
    local CHROOT_CMD=("${!1}")
    shift
    local CMD=("$@")
    local MAX_RETRIES=3
    local RETRY_DELAY=5
    local MIRROR_COUNTRY="${SELECTED_COUNTRY:-United States}"

    # sanity check
    if [[ ! -d "/mnt" ]]; then
        echo "❌ /mnt not found or not a directory — cannot chroot."
        return 1
    fi

    for ((i=1; i<=MAX_RETRIES; i++)); do
        echo
        echo "Attempt $i of $MAX_RETRIES: ${CMD[*]}"
        if "${CHROOT_CMD[@]}" "${CMD[@]}"; then
            echo "✅ Installation succeeded on attempt $i"
            return 0
        else
            echo "⚠️ Installation failed on attempt $i"
            if (( i < MAX_RETRIES )); then
                echo "🔄 Refreshing keys and mirrors, retrying in ${RETRY_DELAY}s..."
                "${CHROOT_CMD[@]}" bash -c '
                    pacman-key --init
                    pacman-key --populate archlinux
                    pacman -Sy --noconfirm archlinux-keyring
                ' || echo "⚠️ Keyring refresh failed."
                [[ -n "$MIRROR_COUNTRY" ]] && \
                "${CHROOT_CMD[@]}" reflector --country "$MIRROR_COUNTRY" --age 12 --protocol https --sort rate \
                    --save /etc/pacman.d/mirrorlist || echo "⚠️ Mirror refresh failed."
                sleep "$RETRY_DELAY"
            fi
        fi
    done

    echo "❌ Installation failed after ${MAX_RETRIES} attempts."
    return 1
}

safe_pacman_install() {
    local CHROOT_CMD=("${!1}")
    shift
    local PKGS=("$@")

    for PKG in "${PKGS[@]}"; do
        install_with_retry CHROOT_CMD[@] pacman -S --needed --noconfirm --overwrite="*" "$PKG" || \
            echo "⚠️ Skipping $PKG"
    done
}
#=========================================================================================================================================#
#===================================================================================================#
# 7C) Helper Functions - For AUR (Paru)                                                              
#===================================================================================================#

safe_aur_install() {
    local CHROOT_CMD=("${!1}")
    shift
    local AUR_PKGS=("$@")
    [[ ${#AUR_PKGS[@]} -eq 0 ]] && return 0

    local TMP_SCRIPT="/root/_aur_install.sh"
    cat > /mnt${TMP_SCRIPT} <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Arguments: NEWUSER + AUR packages
NEWUSER="$1"
shift
AUR_PKGS=("$@")
HOME_DIR="/home/${NEWUSER}"

mkdir -p "$HOME_DIR"
chown "$NEWUSER:$NEWUSER" "$HOME_DIR"
chmod 755 "$HOME_DIR"

pacman -Sy --noconfirm --needed git base-devel sudo

# Ensure sudo rights
if ! sudo -lU "$NEWUSER" &>/dev/null; then
    echo "$NEWUSER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"$NEWUSER"
    chmod 440 /etc/sudoers.d/"$NEWUSER"
fi

# Install paru if missing
if ! command -v paru &>/dev/null; then
    sudo -u "$NEWUSER" HOME="$HOME_DIR" bash -c "
        cd \"$HOME_DIR\" || exit
        rm -rf paru
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd ..
        rm -rf paru
    "
fi

# Install AUR packages
for pkg in "${AUR_PKGS[@]}"; do
    sudo -u "$NEWUSER" HOME="$HOME_DIR" bash -c "
        paru -S --noconfirm --skipreview --removemake --needed --overwrite=\"*\" \"$pkg\" || \
        echo \"⚠️ Failed to install $pkg\"
    "
done
EOF

    # Pass NEWUSER as first argument + package list
    "${CHROOT_CMD[@]}" bash "${TMP_SCRIPT}" "$NEWUSER" "${AUR_PKGS[@]}"
    "${CHROOT_CMD[@]}" rm -f "${TMP_SCRIPT}"
}
# define once to keep consistent call structure
CHROOT_CMD=(arch-chroot /mnt)

#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 8A) GPU DRIVER INSTALLATION & MULTILIB                                                            #"
echo "#===================================================================================================#"
echo

echo
echo "#========================================================#"
echo "🎮 GPU DRIVER INSTALLATION"
echo "#========================================================#"
echo "1) Intel"
echo "2) NVIDIA"
echo "3) AMD"
echo "4) All compatible drivers (default)"
echo "5) Skip"
read -r -p "Select GPU driver set [1-5, default=4]: " GPU_CHOICE
GPU_CHOICE="${GPU_CHOICE:-4}"

GPU_PKGS=()

case "$GPU_CHOICE" in
    1) GPU_PKGS=(mesa vulkan-intel lib32-mesa lib32-vulkan-intel) ;;
    2) GPU_PKGS=(nvidia nvidia-utils lib32-nvidia-utils nvidia-prime) ;;
    3) GPU_PKGS=(mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon xf86-video-amdgpu) ;;
    4)
        GPU_PKGS=(mesa vulkan-intel lib32-mesa lib32-vulkan-intel nvidia nvidia-utils lib32-nvidia-utils nvidia-prime)
        echo "→ AMD skipped to prevent hybrid driver conflicts."
        ;;
    5|*) echo "Skipping GPU driver installation."; GPU_PKGS=() ;;
esac

if [[ ${#GPU_PKGS[@]} -gt 0 ]]; then
    echo "🔧 Ensuring multilib repository is enabled..."
    "${CHROOT_CMD[@]}" bash -c '
        if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
            echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
        fi
        pacman -Sy --noconfirm
    '
    safe_pacman_install CHROOT_CMD[@] "${GPU_PKGS[@]}"
fi
#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 8B) WINDOW MANAGER / DESKTOP ENVIRONMENT SELECTION                                                #"
echo "#===================================================================================================#"
echo

echo
echo "#========================================================#"
echo "Windof Manager / Desktop Selection"
echo "#========================================================#"
    echo "1) Hyprland (Wayland)"
    echo "2) Sway (Wayland)"
    echo "3) XFCE (X11)"
    echo "4) KDE Plasma (X11/Wayland)"
    echo "5) GNOME (X11/Wayland)"
    echo "6) Skip WM/DE installation"
    read -r -p "Select your preferred WM/DE [1-6, default=6]: " WM_CHOICE
    WM_CHOICE="${WM_CHOICE:-6}"
    
    WM_PKGS=()
    WM_AUR_PKGS=()
    
    case "$WM_CHOICE" in
        1)
            echo "→ Selected: Hyprland (Wayland)"
            WM_PKGS=(hyprland hyprpaper hyprshot hyprlock waybar )
            WM_AUR_PKGS=() #Extra AUR PKG CAN BE SET HERE IF WANTED, OR UNDER THE EXTRA_AUR_PKG 
            ;;
        2)
            echo "→ Selected: Sway (Wayland)"
            WM_PKGS=(sway swaybg swaylock waybar wofi)
            WM_AUR_PKGS=() #Extra AUR PKG CAN BE SET HERE IF WANTED, OR UNDER THE EXTRA_AUR_PKG 
            ;;
        3)
            echo "→ Selected: XFCE"
            WM_PKGS=(xfce4 xfce4-goodies lightdm-gtk-greeter)
            WM_AUR_PKGS=() #Extra AUR PKG CAN BE SET HERE IF WANTED, OR UNDER THE EXTRA_AUR_PKG 
            ;;
        4)
            echo "→ Selected: KDE Plasma"
            WM_PKGS=(plasma-desktop kde-applications sddm)
            WM_AUR_PKGS=() #Extra AUR PKG CAN BE SET HERE IF WANTED, OR UNDER THE EXTRA_AUR_PKG 
            ;;
        5)
            echo "→ Selected: GNOME"
            WM_PKGS=(gnome gdm)
            WM_AUR_PKGS=() #Extra AUR PKG CAN BE SET HERE IF WANTED, OR UNDER THE EXTRA_AUR_PKG 
            ;;
        6|*)
            echo "Skipping window manager installation."
            WM_PKGS=()
            WM_AUR_PKGS=() #Extra AUR PKG CAN BE SET HERE IF WANTED, OR UNDER THE EXTRA_AUR_PKG 
            ;;
    esac
    
    # Install WM packages
    if [[ ${#WM_PKGS[@]} -gt 0 ]]; then
        safe_pacman_install CHROOT_CMD[@] "${WM_PKGS[@]}"
    fi
    # Install AUR packages (safe, conflict-handling)
    safe_aur_install CHROOT_CMD[@] "${WM_AUR_PKGS[@]}"

#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 8C) LM/DM                                                                                         #"
echo "#===================================================================================================#"
echo

echo
echo "#========================================================#"
echo " Login Manager / Display Manager Selection"
echo "#========================================================#"
        echo "1) GDM - If you installed: Gnome, Hyprland, Sway, XFCE"
        echo "2) SDDM - If you installed: KDE, XFCE" 
        echo "3) LightDM - XFCE"
        echo "4) Ly (AUR) - Sway, Hyprland"
        echo "5) LXDM - XFCE"
        echo "6) Skip Display Manager"
        read -r -p "Select your display manager [1-6, default=6]: " DM_CHOICE
        DM_CHOICE="${DM_CHOICE:-6}"
        
        DM_PKGS=()
        DM_AUR_PKGS=()
        DM_SERVICE=""
        
        case "$DM_CHOICE" in
            1)
                DM_PKGS=(gdm)
                DM_SERVICE="gdm.service"
                ;;
            2)
                DM_PKGS=(sddm)
                DM_SERVICE="sddm.service"
                ;;
            3)
                DM_PKGS=(lightdm lightdm-gtk-greeter)
                DM_SERVICE="lightdm.service"
                ;;
            4)
                DM_PKGS=(ly)
                DM_AUR_PKGS=(ly-themes-git)
                DM_SERVICE="ly.service"
                ;;
            5)
                DM_PKGS=(lxdm)
                DM_SERVICE="lxdm.service"
                ;;
            6|*)
                echo "Skipping display manager installation."
                DM_PKGS=()
                ;;
        esac
        
        # Install display manager packages
        if [[ ${#DM_PKGS[@]} -gt 0 ]]; then
            safe_pacman_install CHROOT_CMD[@] "${DM_PKGS[@]}"
        fi
        
        # Install AUR display manager packages (safe)
        safe_aur_install CHROOT_CMD[@] "${DM_AUR_PKGS[@]}"
        
        # Enable chosen service
        if [[ -n "$DM_SERVICE" ]]; then
            "${CHROOT_CMD[@]}" systemctl enable "$DM_SERVICE"
            echo "✅ Display manager service enabled: $DM_SERVICE"
        fi
        
#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 9A) EXTRA PACMAN PACKAGE INSTALLATION (Resilient + Safe)                                          #"
echo "#===================================================================================================#"
echo

            read -r -p "Do you want to install EXTRA pacman packages? [y/N]: " INSTALL_EXTRA
            if [[ "$INSTALL_EXTRA" =~ ^[Yy]$ ]]; then
                read -r -p "Enter any Pacman packages (space-separated), or leave empty: " EXTRA_PKG_INPUT
                # Clean list: neofetch removed (deprecated)
                EXTRA_PKGS=( zram-generator kitty kvantum breeze breeze-icons qt5ct qt6ct rofi nwg-look otf-font-awesome )
            
                # Filter out non-existent packages before installing
                VALID_PKGS=()
                for pkg in "${EXTRA_PKGS[@]}"; do
                    if "${CHROOT_CMD[@]}" pacman -Si "$pkg" &>/dev/null; then
                        VALID_PKGS+=("$pkg")
                    else
                        echo "⚠️  Skipping invalid or missing package: $pkg"
                    fi
                done
            
                # Merge validated list with user input
                EXTRA_PKG=("${VALID_PKGS[@]}")
                if [[ -n "$EXTRA_PKG_INPUT" ]]; then
                    read -r -a EXTRA_PKG_INPUT_ARR <<< "$EXTRA_PKG_INPUT"
                    EXTRA_PKG+=("${EXTRA_PKG_INPUT_ARR[@]}")
                fi
            
                if [[ ${#EXTRA_PKG[@]} -gt 0 ]]; then
                    safe_pacman_install CHROOT_CMD[@] "${EXTRA_PKG[@]}"
                else
                    echo "⚠️  No valid packages to install."
                fi
            else
                echo "Skipping extra pacman packages."
            fi

#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 9B) OPTIONAL AUR PACKAGE INSTALLATION (with Conflict Handling)                                    #"
echo "#===================================================================================================#"
echo

                read -r -p "Install additional AUR packages using paru? [y/N]: " install_aur
                install_aur="${install_aur:-N}"
                
                if [[ "$install_aur" =~ ^[Yy]$ ]]; then
                    read -r -p "Enter any AUR packages (space-separated), or leave empty: " EXTRA_AUR_INPUT
                
                    # Predefined extra AUR packages
                    EXTRA_AUR_PKGS=(kvantum-theme-catppuccin-git qt6ct-kde wlogout wlrobs-hg)
                
                    # Merge WM + DM AUR packages with user input
                    AUR_PKGS=("${WM_AUR_PKGS[@]}" "${DM_AUR_PKGS[@]}" "${EXTRA_AUR_PKGS[@]}")
                
                    if [[ -n "$EXTRA_AUR_INPUT" ]]; then
                        read -r -a EXTRA_AUR_INPUT_ARR <<< "$EXTRA_AUR_INPUT"
                        AUR_PKGS+=("${EXTRA_AUR_INPUT_ARR[@]}")
                    fi
                
                    echo "🔧 Installing AUR packages inside chroot..."
                    safe_aur_install CHROOT_CMD[@] "${AUR_PKGS[@]}"
                else
                    echo "Skipping AUR installation."
                fi
#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 10) Hyprland Theme Setup (Optional) with .Config Backup                                           #"
echo "#===================================================================================================#"
echo
sleep 1

                    # Only proceed if Hyprland was selected (WM_CHOICE == 1)
                    if [[ " ${WM_CHOICE:-} " =~ "1" ]]; then
                        echo "🔧 Installing unzip and git inside chroot to ensure theme download works..."
                        arch-chroot /mnt pacman -S --needed --noconfirm unzip git
                    
                        read -r -p "Do you want to install the Hyprland theme from GitHub? [y/N]: " INSTALL_HYPR_THEME
                        if [[ "$INSTALL_HYPR_THEME" =~ ^[Yy]$ ]]; then
                            echo "→ Running Hyprland theme setup inside chroot..."
                    
                            arch-chroot /mnt /bin/bash -c "
                    NEWUSER=\"$NEWUSER\"
                    HOME_DIR=\"/home/\$NEWUSER\"
                    CONFIG_DIR=\"\$HOME_DIR/.config\"
                    REPO_DIR=\"\$HOME_DIR/hyprland-setup\"
                    
                    # Ensure home exists
                    mkdir -p \"\$HOME_DIR\"
                    chown \$NEWUSER:\$NEWUSER \"\$HOME_DIR\"
                    chmod 755 \"\$HOME_DIR\"
                    
                    # Clone theme repo
                    if [[ -d \"\$REPO_DIR\" ]]; then
                        rm -rf \"\$REPO_DIR\"
                    fi
                    sudo -u \$NEWUSER git clone https://github.com/terra88/hyprland-setup.git \"\$REPO_DIR\"
                    
                    # Copy files to home directory
                    sudo -u \$NEWUSER cp -f \"\$REPO_DIR/config.zip\" \"\$HOME_DIR/\" 2>/dev/null || echo '⚠️ config.zip missing'
                    sudo -u \$NEWUSER cp -f \"\$REPO_DIR/wallpaper.zip\" \"\$HOME_DIR/\" 2>/dev/null || echo '⚠️ wallpaper.zip missing'
                    sudo -u \$NEWUSER cp -f \"\$REPO_DIR/wallpaper.sh\" \"\$HOME_DIR/\" 2>/dev/null || echo '⚠️ wallpaper.sh missing'
                    
                    # Backup existing .config if not empty
                    if [[ -d \"\$CONFIG_DIR\" && \$(ls -A \"\$CONFIG_DIR\") ]]; then
                        mv \"\$CONFIG_DIR\" \"\$CONFIG_DIR.backup.\$(date +%s)\"
                        echo '==> Existing .config backed up.'
                    fi
                    mkdir -p \"\$CONFIG_DIR\"
                    
                    # Extract config.zip into .config
                    if [[ -f \"\$HOME_DIR/config.zip\" ]]; then
                        unzip -o \"\$HOME_DIR/config.zip\" -d \"\$HOME_DIR/temp_unzip\"
                        if [[ -d \"\$HOME_DIR/temp_unzip/config\" ]]; then
                            cp -r \"\$HOME_DIR/temp_unzip/config/\"* \"\$CONFIG_DIR/\"
                            rm -rf \"\$HOME_DIR/temp_unzip\"
                            echo '==> config.zip contents copied to .config'
                        else
                            echo '⚠️ config/ folder not found inside zip, skipping.'
                        fi
                    else
                        echo '⚠️ config.zip not found, skipping.'
                    fi
                    
                    # Extract wallpaper.zip to HOME_DIR
                    [[ -f \"\$HOME_DIR/wallpaper.zip\" ]] && unzip -o \"\$HOME_DIR/wallpaper.zip\" -d \"\$HOME_DIR\" && echo '==> wallpaper.zip extracted'
                    
                    # Copy wallpaper.sh and make executable
                    [[ -f \"\$HOME_DIR/wallpaper.sh\" ]] && chmod +x \"\$HOME_DIR/wallpaper.sh\" && echo '==> wallpaper.sh copied and made executable'
                    
                    # Fix ownership
                    chown -R \$NEWUSER:\$NEWUSER \"\$HOME_DIR\"
                    
                    # Cleanup cloned repo
                    rm -rf \"\$REPO_DIR\"
                    "
                    
                            echo "Hyprland theme setup completed."
                        else
                            echo "Skipping Hyprland theme setup."
                        fi
                    fi
}
#=========================================================================================================================================#

#=========================================================================================================================================#
#---------------------------------------
# Robust main menu (simple + careful)
#---------------------------------------
    main() {
    clear
    echo "======================================"
    echo "      ⚙️  Automated Arch Installer      "
    echo "======================================"
    echo
    echo
    
    detect_boot_mode || die "Failed to detect boot mode (UEFI/BIOS)"
    echo "Detected boot mode: $MODE"

    #==START====#
    initialize_cleanup
    #==START====#
    
    # Ask which disk to use
    echo
    lsblk -d -o NAME,SIZE,MODEL
    read -rp "Enter target disk (e.g. /dev/sda): " DEV
    [[ -b "$DEV" ]] || die "Invalid device: $DEV"

    echo
    read -rp "This will ERASE all data on $DEV. Continue? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || die "Aborted by user."

    echo "🧭 Partitioning $DEV ..."
    partition_disk "$DEV" || die "Partitioning failed."

    echo
    echo "💾 Asking for partition sizes..."
    ask_partition_sizes "$DEV"

    echo
    echo "🧱 Formatting and mounting partitions..."
    format_and_mount "$DEV" || die "Formatting/mounting failed."

    echo
    echo "generate fstab"
    generate_fstab
    
    echo
    echo "📦 Installing base system..."
    install_base_system || die "Base install failed."

    echo
    echo "⚙️  Configuring system..."
    configure_system || die "Configuration failed."

    echo
    echo "🧩 Installing GRUB bootloader..."
    install_grub "$DEV" || die "GRUB installation failed."

    echo
    echo " Installing Optional Packages & Drivers "
    optional_install_setup || die "Optional installation failed."

    echo
    echo "✅ Installation complete! You can now chroot into /mnt and finalize setup."
}

# Run the main function
#main "$@"
#=========================================================================================================================================#

custom_partition()
{

sleep 1
clear
echo "#===================================================================================================#"
echo "# 1.3) Custom Partition Mode: Selected Drive $DEV                                                   #"
echo "#===================================================================================================#"
echo

      echo "Under Construction - Feature coming soon, restarting. . . "
      sleep 3
      exec "$0"
}

#=========================================================================================================================================#
logo
echo "#===================================================================================================#"
echo "# 1 Choose Partitioning Mode                                                                        #"
echo "#===================================================================================================#"
            echo "#==================================================#"
            echo "#     Select partitioning method for $DEV:         #"
            echo "#==================================================#"
            echo "|-1) Quick Partitioning  (automated, recommended)  |"
            echo "|--------------------------------------------------|"
            echo "|-2) Custom Partitioning (manual, using cfdisk)    |"
            echo "|--------------------------------------------------|"
            echo "|-3) Return back to start                          |"
            echo "#==================================================#"
            read -rp "Enter choice [1-2, default=1]: " PART_CHOICE
            PART_CHOICE="${PART_CHOICE:-1}"

                case "$PART_CHOICE" in
                    1)
                        main  ;;
                    2)
                        custom_partition  ;;
                    3)
                        echo "Restarting..."
                        exec "$0"
                        ;;
                    *)
                        echo "Invalid choice."
                        exec "$0"
                        ;;
                esac
                  
#=========================================================================================================================================#

sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 11 Cleanup postinstall script & Final Messages & Instructions                                     #"
echo "#===================================================================================================#"
echo
echo 
echo "Custom package installation phase complete."
echo "You can later add more software manually or extend these lists:"
echo "  - EXTRA_PKGS[] for pacman packages"
echo "  - AUR_PKGS[] for AUR software"
echo " ----------------------------------------------------------------------------------------------------"
echo "You can now unmount and reboot:"
echo "  umount -R /mnt"
echo "  swapoff ${P3} || true"
echo "  reboot"
#Cleanup postinstall script
rm -f /mnt/root/postinstall.sh
#Final messages & instructions
echo
echo "Installation base and basic configuration finished."
echo "To reboot into your new system:"
echo "  umount -R /mnt"
echo "  swapoff ${P3} || true"
echo "  reboot"
echo
echo "Done."
echo "#===========================================================================#"
echo "# -GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88             #"
echo "# -Author  : Terra88                                                        #"
echo "# -GitHub  : http://github.com/Terra88                                      #"
echo "#===========================================================================#"
