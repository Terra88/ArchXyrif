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
echo "${GREEN}#===================================================================================================#${RESET}"
echo "| The Great Monolith of Installing Arch Linux!                                                      |"
echo "${GREEN}#===================================================================================================#${RESET}"
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
echo "${GREEN}#===================================================================================================#${RESET}"
echo "|-Table of Contents:                |-0) Disk Format INFO                                           |"
echo "${GREEN}#===================================================================================================#${RESET}"
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
echo "${GREEN}#===================================================================================================#${RESET}"
echo "-1) Disk Selection: Format (Enter device path: example /dev/sda or /dev/nvme0 etc.)                 |"
echo "${GREEN}#===================================================================================================#${RESET}"

}
#!/usr/bin/env bash
loadkeys fi
timedatectl set-ntp true
set -euo pipefail
#=========================================================================================================================================#
    # Helpers
    #--------------------------------------#
    # Helper: Confirm user action
    #--------------------------------------#
    confirm() {
    # ask Yes/No, return 0 if yes
    local msg="${1:-Continue?}"
    read -r -p "$msg [Y/n]: " ans
    case "$ans" in
        [Nn]|[Nn][Oo]) return 1 ;;
       *) return 0 ;;
    esac
    }

#=========================================================================================================================================#

    #die helper
    die() {
    echo "ERROR: $*" >&2
    exit 1
    }
    
#=========================================================================================================================================#

    part_suffix() {
    # given /dev/sdX or /dev/nvme0n1, print partition suffix ('' or 'p')
    local dev="$1"
    if [[ "$dev" =~ nvme|mmcblk ]]; then
        echo "p"
    else
        echo ""
    fi
    }
    
#=========================================================================================================================================#

    #CLEANUP HELPER 
    cleanup() {
    echo
    echo "🧹 Running cleanup before exit..."
    swapoff -a 2>/dev/null || true
    if mountpoint -q /mnt; then
        echo "🔽 Unmounting /mnt..."
        umount -R /mnt 2>/dev/null || true
    fi
    sync
    echo "✅ Cleanup complete. Safe to exit."
}

trap cleanup EXIT INT TERM

#=========================================================================#
# Robust cleanup: unmount all partitions/subvolumes and turn off swap
#=========================================================================#

cleanup_device() {
    local dev="$1"
    echo -e "\n🧹 Cleaning device $dev ..."

    # 1️⃣ Turn off swap on this device
    mapfile -t SWAPS < <(swapon --show=NAME --noheadings || true)
    for s in "${SWAPS[@]}"; do
        if [[ "$s" == "$dev"* ]]; then
            echo "→ Turning off swap $s"
            swapoff "$s" || true
        fi
    done

    # 2️⃣ Unmount all mounts on this device (deepest first)
    mapfile -t MOUNTS < <(mount | awk -v d="$dev" '$1 ~ d { print $3 }' | sort -r)
    for m in "${MOUNTS[@]}"; do
        echo "→ Unmounting $m"
        umount -l "$m" 2>/dev/null || true
    done

    # 3️⃣ Handle BTRFS subvolumes specifically
    mapfile -t BTRFS_MOUNTS < <(mount | awk '/btrfs/ {print $3}' | sort -r)
    for bm in "${BTRFS_MOUNTS[@]}"; do
        src=$(findmnt -n -o SOURCE "$bm" 2>/dev/null || true)
        if [[ "$src" == "$dev"* ]]; then
            echo "→ Unmounting BTRFS subvolume $bm"
            umount -l "$bm" 2>/dev/null || true
        fi
    done

    # 4️⃣ Remove leftover contents in /mnt if mounted
    if mountpoint -q /mnt; then
        echo "→ Cleaning /mnt"
        umount -R /mnt 2>/dev/null || true
        rm -rf /mnt/* 2>/dev/null || true
    fi

    # 5️⃣ Notify kernel of changes
    echo "→ Informing kernel of partition table changes"
    partprobe "$dev"
    udevadm settle

    echo "✅ Device $dev cleanup complete."
}

#=========================================================================#
# Wrapper to unmount a device (simpler for quick unmount)
#=========================================================================#
unmount_device() {
    local dev="$1"
    echo -e "\n🔽 Unmounting any mounts on $dev ..."

    # Unmount all mounts on this device (deepest first)
    mapfile -t MOUNTS < <(mount | awk -v d="$dev" '$1 ~ d { print $3 }' | sort -r)
    for m in "${MOUNTS[@]}"; do
        echo "→ Unmounting $m"
        umount -l "$m" 2>/dev/null || true
    done

    # Ensure /mnt is clean
    if mountpoint -q /mnt; then
        umount -R /mnt 2>/dev/null || true
        rm -rf /mnt/* 2>/dev/null || true
    fi

    echo "✅ Device $dev unmounted."
}

#=========================================================================================================================================#  
    
#=========================================================================================================================================#
# 1.1) Clearing Partition Tables / Luks / LVM Signatures

clear_partition_table_luks_lvmsignatures()
{
        # Clear partition table / LUKS / LVM signatures
        echo "Wiping partition table and signatures (sgdisk --zap-all, wipefs -a, zeroing first sectors)..."
        which sgdisk >/dev/null 2>&1 || die "sgdisk (gdisk) required but not found. Install 'gdisk'."
        which wipefs >/dev/null 2>&1 || die "wipefs (util-linux) required but not found."

        # try to shut down any open LUKS mappings referring to this device (best-effort)
        echo "Attempting to close any open LUKS mappings referencing $DEV..."
        for map in /dev/mapper/*; do
        if [[ -L "$map" ]]; then
            target=$(readlink -f "$map" || true)
            if [[ "$target" == "$DEV"* ]]; then
            name=$(basename "$map")
            echo "  Closing mapper $name (points at $target)"
            cryptsetup luksClose "$name" || true
        fi
            
            if [[ "$BIOS_BOOT_PART_CREATED" == true ]]; then
                BIOS_BOOT_SIZE_MIB=2
            else
                BIOS_BOOT_SIZE_MIB=0
            fi
        
        fi
        done

        # Zap GPT, MBR, etc.
        sgdisk --zap-all "$DEV" || true

        # Wipe filesystem signatures on whole device
        wipefs -a "$DEV" || true

        # Overwrite first and last MiB to remove any leftover headers (LUKS/LVM/crypt)
        echo "Zeroing first 2MiB of $DEV to remove lingering headers..."
        dd if=/dev/zero of="$DEV" bs=1M count=2 oflag=direct status=none || true

        # If device supports it, also zero last MiB (LVM metadata sometimes at end)
        devsize_bytes=$(blockdev --getsize64 "$DEV")
        if [[ -n "$devsize_bytes" && "$devsize_bytes" -gt 1048576 ]]; then
        last_offset=$((devsize_bytes - 1*1024*1024))
        dd if=/dev/zero of="$DEV" bs=1M count=1 oflag=direct seek=$(( (devsize_bytes / (1024*1024)) - 1 )) status=none || true
        fi

            # Turn off swap if any
            swapoff -a 2>/dev/null || true

           # Unmount /mnt recursively but handle BTRFS subvolumes safely
        if mountpoint -q /mnt; then
            # Get all mounts under /mnt sorted by depth (deepest first)
            mapfile -t MOUNTS < <(mount | grep '/mnt' | awk '{print $3}' | sort -r)
            for mnt in "${MOUNTS[@]}"; do
            umount -l "$mnt" 2>/dev/null || true
            done
        fi

            # Clean up /mnt (optional)
            rm -rf /mnt/* 2>/dev/null || true
}
#=========================================================================================================================================#

#-------HELPER FOR CHROOT--------------------------------#

prepare_chroot() {
    echo "Mounting pseudo-filesystems for chroot..."

    # Ensure base mount exists
    mkdir -p /mnt

    # Ensure all required subdirectories exist
    for dir in proc sys dev run; do
        mkdir -p "/mnt/$dir"
    done

    # Mount pseudo-filesystems
    mount --types proc /proc /mnt/proc
    mount --rbind /sys /mnt/sys
    mount --make-rslave /mnt/sys
    mount --rbind /dev /mnt/dev
    mount --make-rslave /mnt/dev
    mount --rbind /run /mnt/run
    mount --make-rslave /mnt/run

    echo "✅ Pseudo-filesystems mounted successfully."
}

#=========================================================================================================================================#

#----------------------------------------------#
#-------------------MAPPER---------------------#
#----------------------------------------------#
DEV=""                          # Target device
# === Safe defaults (place near top, before any function that references these) ===
MODE=""                         # "UEFI" or "BIOS"
BIOS_BOOT_PART_CREATED=false    # whether BIOS boot partition was created/needed
SWAP_SIZE_MIB=0
ROOT_FS=""
HOME_FS=""
ROOT_SIZE_MIB=0
HOME_SIZE_MIB=0
EFI_SIZE_MIB=1024               # EFI partition size in MiB for UEFI
BIOS_BOOT_SIZE_MIB=512         # /boot ext4 size in MiB for BIOS mode (your chosen default)
BOOT_SIZE_MIB=0                # canonical boot-part size used by previews (always set)
BUFFER_MIB=8                   # safety buffer

#=========================================================================================================================================#
# -----------------------
# Detect boot mode
# -----------------------
detect_boot_mode() {
    if [[ -d /sys/firmware/efi ]]; then
        MODE="UEFI"
        BIOS_BOOT_PART_CREATED=false
        BOOT_SIZE_MIB=$EFI_SIZE_MIB
        echo -e "${CYAN}UEFI${RESET} system detected."
    else
        MODE="BIOS"
        BIOS_BOOT_PART_CREATED=true
        BOOT_SIZE_MIB=$BIOS_BOOT_SIZE_MIB
        echo -e "${CYAN}Legacy BIOS${RESET} system detected."
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
    echo "Detected RAM: ${ram_mib} MiB — swap = ${SWAP_SIZE_MIB} MiB"
}

#=========================================================================================================================================#

# -----------------------
# Ask partition sizes
# -----------------------
ask_partition_sizes() {
    # Ensure detect_boot_mode() already called
    if [[ -z "$MODE" ]]; then
        detect_boot_mode
    fi

    local disk_bytes disk_mib
    disk_bytes=$(lsblk -b -dn -o SIZE "$DEV") || die "Failed reading disk size"
    disk_mib=$(( disk_bytes / 1024 / 1024 ))
    local disk_gib_val
    disk_gib_val=$(awk -v m="$disk_mib" 'BEGIN { printf "%.2f", m/1024 }')
    local disk_gib_int=${disk_gib_val%.*}
    echo "Disk $DEV: ~${disk_gib_int} GiB"

    while true; do
        lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT "$DEV"
        local max_root_gib=$(( disk_gib_int - SWAP_SIZE_MIB/1024 - 5 ))
        read -rp "Enter ROOT size in GiB (max ${max_root_gib}): " ROOT_SIZE_GIB
        ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-$max_root_gib}"
        if ! [[ "$ROOT_SIZE_GIB" =~ ^[0-9]+$ ]]; then
            echo "Enter a number."
            continue
        fi
        if (( ROOT_SIZE_GIB <= 0 || ROOT_SIZE_GIB > max_root_gib )); then
            echo "Invalid root size. Max ${max_root_gib} GiB"
            continue
        fi

        ROOT_SIZE_MIB=$(( ROOT_SIZE_GIB * 1024 ))
        ROOT_SIZE_GIB="$ROOT_SIZE_GIB"

        # reserved space (in GiB) for boot depending on mode
        local reserved_gib
        if [[ "$MODE" == "UEFI" ]]; then
            reserved_gib=$(( EFI_SIZE_MIB / 1024 ))
        else
            reserved_gib=$(( BIOS_BOOT_SIZE_MIB / 1024 ))
        fi

        REMAINING_HOME_GIB=$(( disk_gib_int - ROOT_SIZE_GIB - SWAP_SIZE_MIB/1024 - reserved_gib - 1 ))
        if (( REMAINING_HOME_GIB < 1 )); then
            echo "Not enough room for home; pick smaller root."
            continue
        fi

        read -rp "Enter HOME size in GiB (ENTER for remaining ${REMAINING_HOME_GIB}): " HOME_SIZE_GIB
        HOME_SIZE_GIB="${HOME_SIZE_GIB:-$REMAINING_HOME_GIB}"
        if ! [[ "$HOME_SIZE_GIB" =~ ^[0-9]+$ ]]; then
            echo "Home must be numeric."
            continue
        fi
        HOME_SIZE_MIB=$(( HOME_SIZE_GIB * 1024 ))

        # OK
        echo "Root: ${ROOT_SIZE_GIB} GiB, Home: ${HOME_SIZE_GIB} GiB, Swap: $((SWAP_SIZE_MIB/1024)) GiB, Boot reserved: ${reserved_gib} GiB"
        break
    done
}

#=========================================================================================================================================#

# -----------------------
# Partition disk
# -----------------------
partition_disk() {
    local ps
    ps=$(part_suffix "$DEV")
    parted -s "$DEV" mklabel gpt

    if [[ "$MODE" == "BIOS" ]]; then
        parted -s "$DEV" mkpart primary ext4 1MiB "${BIOS_BOOT_SIZE_MIB}MiB"
        parted -s "$DEV" mkpart primary "$ROOT_FS" "$((BIOS_BOOT_SIZE_MIB + 1))MiB" "$((BIOS_BOOT_SIZE_MIB + ROOT_SIZE_MIB))MiB"
        parted -s "$DEV" mkpart primary linux-swap "$((BIOS_BOOT_SIZE_MIB + ROOT_SIZE_MIB + 1))MiB" "$((BIOS_BOOT_SIZE_MIB + ROOT_SIZE_MIB + SWAP_SIZE_MIB))MiB"
        parted -s "$DEV" mkpart primary "$HOME_FS" "$((BIOS_BOOT_SIZE_MIB + ROOT_SIZE_MIB + SWAP_SIZE_MIB + 1))MiB" 100%
    else
        parted -s "$DEV" mkpart primary fat32 1MiB "${EFI_SIZE_MIB}MiB"
        parted -s "$DEV" set 1 boot on
        parted -s "$DEV" mkpart primary "$ROOT_FS" "$((EFI_SIZE_MIB + 1))MiB" "$((EFI_SIZE_MIB + ROOT_SIZE_MIB))MiB"
        parted -s "$DEV" mkpart primary linux-swap "$((EFI_SIZE_MIB + ROOT_SIZE_MIB + 1))MiB" "$((EFI_SIZE_MIB + ROOT_SIZE_MIB + SWAP_SIZE_MIB))MiB"
        parted -s "$DEV" mkpart primary "$HOME_FS" "$((EFI_SIZE_MIB + ROOT_SIZE_MIB + SWAP_SIZE_MIB + 1))MiB" 100%
    fi

    partprobe "$DEV"
    udevadm settle
    echo "Partitions created."
}

#=========================================================================================================================================#

# -----------------------
# Format & mount
# -----------------------
format_and_mount() {
    local ps
    ps=$(part_suffix "$DEV")
    local P1="${DEV}${ps}1"   # Boot / EFI
    local P2="${DEV}${ps}2"   # Root
    local P3="${DEV}${ps}3"   # Swap
    local P4="${DEV}${ps}4"   # Home

    echo "Formatting partitions..."

    # Swap first
    mkswap "$P3"
    swapon "$P3"

    # Format root and home based on selected FS
    case "$FS_CHOICE" in
        1)  # EXT4 root + home
            mkfs.ext4 -F "$P2"
            mkfs.ext4 -F "$P4"
            ROOT_FS="ext4"
            HOME_FS="ext4"
            ;;
        2)  # BTRFS root + home
            mkfs.btrfs -f "$P2"
            mkfs.btrfs -f "$P4"
            ROOT_FS="btrfs"
            HOME_FS="btrfs"
            ;;
        3)  # BTRFS root + EXT4 home
            mkfs.btrfs -f "$P2"
            mkfs.ext4 -F "$P4"
            ROOT_FS="btrfs"
            HOME_FS="ext4"
            ;;
        *)
            die "Invalid filesystem choice"
            ;;
    esac

    # Ensure /mnt exists
    mkdir -p /mnt

    # Mount root and handle BTRFS subvolumes
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        mount "$P2" /mnt
        echo "Creating BTRFS subvolumes..."
        for sv in @ @home @snapshots @cache @log; do
            btrfs subvolume create "/mnt/$sv" || true
        done
        umount /mnt
        mount -o noatime,compress=zstd,subvol=@ "$P2" /mnt
        mkdir -p /mnt/home
        mount -o noatime,compress=zstd,subvol=@home "$P2" /mnt/home
    else
        mount "$P2" /mnt
        mkdir -p /mnt/home
        mount "$P4" /mnt/home
    fi

    # Boot/EFI partition mount
    mkdir -p /mnt/boot
    if [[ "$MODE" == "UEFI" ]]; then
        mkfs.fat -F32 "$P1"
        mount "$P1" /mnt/boot
    else
        mkfs.ext4 -F "$P1"
        mount "$P1" /mnt/boot
    fi

    # Optional directories
    mkdir -p /mnt/{var,cache,.snapshots,boot}

    echo "All partitions formatted and mounted to /mnt."
}
#=========================================================================================================================================#
# -----------------------
# GRUB installation
# -----------------------
install_grub() {
    if [[ "$MODE" == "BIOS" ]]; then
        echo "Installing GRUB for BIOS..."
        arch-chroot /mnt grub-install --target=i386-pc --boot-directory=/boot "$DEV"

    else
        echo "Detected UEFI environment — installing GRUB (UEFI)..."

        # Ensure EFI system partition is mounted
        if ! mountpoint -q /mnt/boot/efi; then
            echo "→ Mounting EFI system partition..."
            mkdir -p /mnt/boot/efi
            mount "$P1" /mnt/boot/efi
        fi

        GRUB_MODULES="part_gpt part_msdos fat ext2 normal boot efi_gop efi_uga gfxterm linux search search_fs_uuid"

        # Install GRUB for UEFI
        arch-chroot /mnt grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=GRUB \
            --modules="$GRUB_MODULES" \
            --recheck \
            --no-nvram

        # Fallback EFI binary
        arch-chroot /mnt bash -c 'mkdir -p /boot/efi/EFI/Boot && cp -f /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/Boot/BOOTX64.EFI || true'

        # Clean old EFI boot entries
        DISK="${DEV}"
        PARTNUM=1
        LABEL="Arch Linux"
        LOADER='\EFI\GRUB\grubx64.efi'

        for bootnum in $(efibootmgr -v | awk "/${LABEL}/ {print substr(\$1,5,4)}"); do
            efibootmgr -b "$bootnum" -B || true
        done

        efibootmgr -c -d "$DISK" -p "$PARTNUM" -L "$LABEL" -l "$LOADER"

        # Generate GRUB config
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

        # Secure Boot signing
        if command -v sbctl >/dev/null 2>&1; then
            echo "→ Signing EFI binaries for Secure Boot..."
            arch-chroot /mnt sbctl status || arch-chroot /mnt sbctl create-keys
            arch-chroot /mnt sbctl enroll-keys --microsoft
            arch-chroot /mnt sbctl sign --path /boot/efi/EFI/GRUB/grubx64.efi
            arch-chroot /mnt sbctl sign --path /boot/vmlinuz-linux
        fi

        echo "✅ GRUB installation complete (UEFI)."
        echo "Verifying EFI boot entries..."
        efibootmgr -v || true
    fi

    echo "✅ Generating final GRUB config..."
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || die "Failed to generate GRUB config"
    echo "✅ GRUB installed successfully."
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
    # ensure BOOT_SIZE_MIB is set
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
# -----------------------
# Main interactive flow
# -----------------------
main_menu() {

    echo "Available block devices:"
    lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
    read -rp $'\nEnter block device to use (example /dev/sda or /dev/nvme0n1): ' DEV
    DEV="${DEV:-}"
    if [[ -z "$DEV" || ! -b "$DEV" ]]; then
        die "No valid device supplied."
    fi

    echo "Cleaning any old mounts from $DEV ..."
    unmount_device "$DEV"
    unmount_btrfs_and_swap "$DEV"
    clear_partition_table_luks_lvmsignatures "$DEV"

    if ! confirm "Are you absolutely sure you want to wipe and repartition $DEV? (this will destroy data)"; then
        die "User aborted."
    fi

    # run flow
    detect_boot_mode
    calculate_swap
    select_filesystem
    ask_partition_sizes
    preview_partitions

    if ! confirm "Proceed to create partitions on $DEV?"; then
        die "Aborted by user."
    fi

    partition_disk
    format_and_mount
    prepare_chroot

    if confirm "Install GRUB now?"; then
        install_grub
    else
        echo "Skipped GRUB install."
    fi

    echo -e "${GREEN}Done. Remember to continue with pacstrap, fstab, and chroot steps.${RESET}"
}

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
                        main_menu  ;;
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
echo "# 2) Pacstrap: Installing Base system + recommended packages for basic use                          #"
echo "#===================================================================================================#"
echo

# You can modify the package list below as needed.
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

echo "Installing base system packages: ${PKGS[*]}"
pacstrap /mnt "${PKGS[@]}"

#=========================================================================================================================================#
clear
sleep 1
echo
echo "#===================================================================================================#"
echo "# 3) Generating fstab & Showing Partition Table / Mountpoints                                       #"
echo "#===================================================================================================#"
echo
sleep 1

echo "Generating /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Partition Table and Mountpoints:"
cat /mnt/etc/fstab

#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 4) Setting Basic variables for chroot (defaults provided)                                         #"
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




#=========================================================================================================================================#
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 6A) Running chroot and setting mkinitcpio - Setting Hostname, Username, enabling services etc.    #"
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
echo "# 6B) Inject variables into /mnt/root/postinstall.sh                                                #"
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
