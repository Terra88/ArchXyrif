#!/usr/bin/env bash
#=========================================================================================================================================#
#===COLOR-MAPPER===#
# Color codes
GREEN="\e[32m" ; YELLOW="\e[33m" ; CYAN="\e[36m" ; RESET="\e[0m"
#===COLOR-MAPPER===#
#=========================================================================================================================================#
# GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88        
# Author  : Terra88 
# Purpose : Arch Linux custom installer
# GitHub  : http://github.com/Terra88
#=========================================================================================================================================#
#=========================================================================================================================================#
# Source variables
#=========================================================================================================================================#
#=========================================================================================================================================#
# Preparation
#=========================================================================================================================================#
# Arch logo: Edited manually by Terra88
#=========================================================================================================================================#
logo(){
echo "#===================================================================================================#"
echo "| The Great Monolith of Installing Arch Linux!                                                      |"
echo "#===================================================================================================#"
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
echo "|        GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88(Tero.H)                       |"
echo "#===================================================================================================#"
echo "|-Table of Contents:                |-0) Disk Format INFO                                           |"
echo "#===================================================================================================#"
echo "|-1)Disk Selection & Format         |- UEFI & BIOS(LEGACY) SUPPORT                                  |"
echo "|-2)Pacstrap:Installing Base system |- wipes old signatures                                         |"
echo "|-3)Generating fstab                |- Partitions: BOOT/EFI(1024MiB)(/ROOT)(/HOME)(SWAP)            |"
echo "|-4)Setting Basic variables         |- 1) Quick Partition: Root/Home & Swap on or off options       |"
echo "|-5)Installing GRUB for UEFI        |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |" 
echo "|-6)Setting configs/enabling.srv    |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |"
echo "|-7)Setting Pacman Mirror           |- 2) Custom Partition/Format Route for ext4,btrfs,xfs,f2fs     |"
echo "|-Optional:                         |- 3) LV & LUKS Custom partition format route                   |"
echo "|-8A)GPU-Guided install             |---------------------------------------------------------------|"
echo "|-8B)Guided Window Manager Install  |# Author  : Terra88(Tero.H)                                    |"
echo "|-8C)Guided Login Manager Install   |# Purpose : Arch Linux custom installer                        |"
echo "|-9)Extra Pacman & AUR PKG Install  |# GitHub  : http://github.com/Terra88                          |"
echo "|-If Hyprland Selected As WM        | ↜(╰ •ω•)╯ψ ↑_(ΦωΦ;)Ψ ୧( ಠ┏ل͜┓ಠ )୨ (ʘдʘ╬) ( •̀ᴗ•́ )و   (◣◢)ψ     |"
echo "|-10)Optional Theme install         | (づ｡◕‿‿◕｡)づ ◥(ฅº￦ºฅ)◤ (㇏(•̀ᵥᵥ•́)ノ) ＼(◑д◐)＞∠(◑д◐)          |"
echo "#===================================================================================================#"
}
#=========================================================================================================================================#
#!/usr/bin/env bash
loadkeys fi
timedatectl set-ntp true
set -euo pipefail
#=========================================================================================================================================#
# GLOBAL VARIABLES:
#=========================================================================================================================================#
#----------------------------------------------#
#-------------------MAPPER---------------------#
#----------------------------------------------#
DEV=""            # set later by main_menu
MODE=""
BOOT_MODE=""
BIOS_BOOT_PART_CREATED=false
SWAP_SIZE_MIB=0
SWAP_ON=""
EFI_FS=""
BOOT_FS=""
SWAP_FS="linux-swap"
ROOT_FS=""
HOME_FS=""
ROOT_SIZE_MIB=0
HOME_SIZE_MIB=0
BIOS_GRUB_SIZE_MIB=1     # tiny bios_grub (no FS), ~1 MiB
BOOT_SIZE_MIB=512        # ext4 /boot size for BIOS installs
EFI_SIZE_MIB=1024        # keep as-is for UEFI
BUFFER_MIB=8
FS_CHOICE=1
# Global partition variables (will be set in format_and_mount)
P_EFI=""
P_BOOT=""
P_SWAP=""
P_ROOT=""
P_HOME=""
#=========================================================================================================================================#
# Helpers
#=========================================================================================================================================#
confirm() {
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
    [[ "$dev" =~ nvme|mmcblk ]] && echo "p" || echo ""
}
#=========================================================================================================================================#
#-------HELPER FOR CHROOT--------------------------------#
#=========================================================================================================================================#
prepare_chroot() {
    echo -e "\n🔧 Preparing pseudo-filesystems for chroot..."
    mkdir -p /mnt
    for fs in proc sys dev run; do
        mount --bind "/$fs" "/mnt/$fs" 2>/dev/null || mount --rbind "/$fs" "/mnt/$fs"
        mount --make-rslave "/mnt/$fs" 2>/dev/null || true
    done
    echo "✅ Pseudo-filesystems mounted into /mnt."
}
#=========================================================================================================================================#
# Cleanup
#=========================================================================================================================================#
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
# SAFE DISK UNMOUNT & CLEANUP BEFORE PARTITIONING
#=========================================================================================================================================#
safe_disk_cleanup() {
    [[ -z "${DEV:-}" ]] && die "safe_disk_cleanup(): DEV not set"

    echo
    echo "#===================================================================================================#"
    echo "# 0) PRE-CLEANUP: Unmounting old partitions, subvolumes, LUKS and LVM from $DEV                    #"
    echo "#===================================================================================================#"

    # 1) Protect the live ISO device
    local iso_dev
    iso_dev=$(findmnt -no SOURCE / 2>/dev/null || true)
    if [[ "$iso_dev" == "$DEV"* ]]; then
        echo "❌ Refusing to touch the live ISO device ($iso_dev)"
        return 1
    fi

    # 2) Deactivate LVMs on this disk
    echo "→ Deactivating LVM volumes related to $DEV ..."
    vgchange -an || true
    for lv in $(lsblk -rno NAME "$DEV" | grep -E '^.*--.*$' || true); do
        dmsetup remove "/dev/mapper/$lv" 2>/dev/null || true
    done

    # 3) Close any LUKS mappings that belong to this disk
    echo "→ Closing any LUKS mappings..."
    for map in $(lsblk -rno NAME,TYPE | awk '$2=="crypt"{print $1}'); do
        local backing
        backing=$(cryptsetup status "$map" 2>/dev/null | awk -F': ' '/device:/{print $2}')
        [[ "$backing" == "$DEV"* ]] && cryptsetup close "$map" && echo "  Closed $map"
    done

    # 4) Unmount all partitions of $DEV (not anything else!)
    echo "→ Unmounting mounted partitions of $DEV..."
    for p in $(lsblk -ln -o NAME,MOUNTPOINT "$DEV" | awk '$2!=""{print $1}' | tac); do
        local part="/dev/$p"
        if mountpoint -q "/dev/$p" 2>/dev/null || grep -q "^$part" /proc/mounts; then
            umount -R "$part" 2>/dev/null && echo "  Unmounted $part"
        fi
    done
    swapoff "${DEV}"* 2>/dev/null || true

    # 5) Remove old BTRFS subvolume mounts (if any)
    echo "→ Cleaning BTRFS subvolumes..."
    for mnt in $(mount | grep "$DEV" | awk '{print $3}' | sort -r); do
        umount -R "$mnt" 2>/dev/null || true
    done

    # 6) Optional signature wipe
    echo "→ Wiping old filesystem / partition signatures..."
    for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
        wipefs -af "/dev/$part" 2>/dev/null || true
    done
    wipefs -af "$DEV" 2>/dev/null || true

    echo "✅ Disk cleanup complete for $DEV."
}
#=========================================================================================================================================#
# Encryption Helpers
#=========================================================================================================================================#
encrypt_root_custom() {
    read -rp "Encrypt which partition (e.g. /dev/sda2)? " ENC_PART
    cryptsetup luksFormat "$ENC_PART"
    cryptsetup open "$ENC_PART" cryptroot
    echo "→ Root device mapped as /dev/mapper/cryptroot"
    P_ROOT="/dev/mapper/cryptroot"
}

encrypt_with_lvm_custom() {
    read -rp "Encrypt base partition for LVM (e.g. /dev/sda2)? " ENC_PART
    cryptsetup luksFormat "$ENC_PART"
    cryptsetup open "$ENC_PART" cryptlvm

    pvcreate /dev/mapper/cryptlvm
    vgcreate vg0 /dev/mapper/cryptlvm

    echo "Creating LVM volumes..."
    read -rp "Root size (e.g. 40G): " LV_ROOT_SIZE
    read -rp "Swap size (e.g. 8G, or leave blank to skip): " LV_SWAP_SIZE

    lvcreate -L "$LV_ROOT_SIZE" vg0 -n root
    [[ -n "$LV_SWAP_SIZE" ]] && lvcreate -L "$LV_SWAP_SIZE" vg0 -n swap
    lvcreate -l 100%FREE vg0 -n home

    P_ROOT="/dev/vg0/root"
    P_HOME="/dev/vg0/home"
    [[ -n "$LV_SWAP_SIZE" ]] && P_SWAP="/dev/vg0/swap"
}
#=========================================================================================================================================#
# Helper Functions - For Pacman                                                                  
#=========================================================================================================================================#
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
# Helper Functions - For AUR (Paru)                                                              
#=========================================================================================================================================#
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
# Detect boot mode
#=========================================================================================================================================#
detect_boot_mode() {
    # Determine boot mode and set both BOOT_MODE and MODE for compatibility
    if [[ -d /sys/firmware/efi ]]; then
        BOOT_MODE="UEFI"
        MODE="UEFI"
        BIOS_BOOT_PART_CREATED=false
        BOOT_SIZE_MIB=${EFI_SIZE_MIB:-1024}
        echo -e "${CYAN}UEFI${RESET} detected."
    else
        BOOT_MODE="BIOS"
        MODE="BIOS"
        BIOS_BOOT_PART_CREATED=true
        BOOT_SIZE_MIB=${BOOT_SIZE_MIB:-512}
        echo -e "${CYAN}Legacy BIOS${RESET} detected."
    fi
}
#=========================================================================================================================================#
# Swap calculation
#=========================================================================================================================================#
calculate_swap_quick() {
    local ram_kb ram_mib
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    ram_mib=$(( (ram_kb + 1023) / 1024 ))
    SWAP_SIZE_MIB=$(( ram_mib <= 8192 ? ram_mib*2 : ram_mib ))
    echo "Detected RAM ${ram_mib} MiB -> swap ${SWAP_SIZE_MIB} MiB"
}
#=========================================================================================================================================#
# Select Filesystem
#=========================================================================================================================================#
select_filesystem() 
{
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
# Select Swap
#=========================================================================================================================================#
select_swap()
{

   clear
    echo "#===============================================================================#"
    echo "| Swap On / Off                                                                 |"
    echo "#===============================================================================#"
    echo "| 1) Swap On                                                                    |"
    echo "|-------------------------------------------------------------------------------|"
    echo "| 2) Swap Off                                                                   |"
    echo "|-------------------------------------------------------------------------------|"
    echo "| 3) exit                                                                       |"
    echo "#===============================================================================#"
     read -rp "Select option [default=1]: " SWAP_ON
    SWAP_ON="${SWAP_ON:-1}"
    case "$SWAP_ON" in
        1) SWAP_ON="1" ;;
        2) SWAP_ON="0" ;;
        3) echo "Exiting"; exit 1 ;;
        *) echo "Invalid choice, defaulting to Swap On"; SWAP_ON="1" ;;
    esac
    echo "→ Swap set to: $([[ "$SWAP_ON" == "1" ]] && echo 'ON' || echo 'OFF')"
}
#=========================================================================================================================================#
# Ask partition sizes
#=========================================================================================================================================#
ask_partition_sizes() {
    detect_boot_mode
    calculate_swap_quick

    local disk_bytes disk_mib disk_gib_val disk_gib_int
    disk_bytes=$(lsblk -b -dn -o SIZE "$DEV") || die "Cannot read disk size for $DEV"
    disk_mib=$(( disk_bytes / 1024 / 1024 ))
    disk_gib_val=$(awk -v m="$disk_mib" 'BEGIN{printf "%.2f", m/1024}')
    disk_gib_int=${disk_gib_val%.*}

    echo "Disk $DEV ≈ ${disk_gib_int} GiB"

    while true; do
        lsblk -p -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT "$DEV"

        # Maximum root size = total disk - swap - reserved (EFI/BIOS) - minimal home
        local reserved_gib
        if [[ "$MODE" == "UEFI" ]]; then
            reserved_gib=$(( EFI_SIZE_MIB / 1024 ))
        else
            reserved_gib=$(( BOOT_SIZE_MIB / 1024 ))
        fi

        local max_root_gib=$(( disk_gib_int - SWAP_SIZE_MIB / 1024 - reserved_gib - 1 ))
        read -rp "Enter ROOT size in GiB (max ${max_root_gib}): " ROOT_SIZE_GIB
        ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-$max_root_gib}"
        [[ "$ROOT_SIZE_GIB" =~ ^[0-9]+$ ]] || { echo "Must be numeric"; continue; }

        if (( ROOT_SIZE_GIB > max_root_gib )); then
            echo "⚠️ ROOT size too large. Limiting to maximum available ${max_root_gib} GiB."
            ROOT_SIZE_GIB=$max_root_gib
        fi

        ROOT_SIZE_MIB=$(( ROOT_SIZE_GIB * 1024 ))

        # Remaining space for home
        local remaining_home_gib=$(( disk_gib_int - ROOT_SIZE_GIB - SWAP_SIZE_MIB / 1024 - reserved_gib ))
        if (( remaining_home_gib < 1 )); then
            echo "Not enough space left for /home. Reduce ROOT or SWAP size."
            continue
        fi

        read -rp "Enter HOME size in GiB (ENTER for remaining ${remaining_home_gib}): " HOME_SIZE_GIB_INPUT

        if [[ -z "$HOME_SIZE_GIB_INPUT" ]]; then
            # Use all remaining space
            HOME_SIZE_GIB=$remaining_home_gib
            HOME_SIZE_MIB=0      # will handle as 100% in partitioning
            home_end="100%"
        else
            [[ "$HOME_SIZE_GIB_INPUT" =~ ^[0-9]+$ ]] || { echo "Must be numeric"; continue; }

            # Limit to remaining space
            if (( HOME_SIZE_GIB_INPUT > remaining_home_gib )); then
                echo "⚠️ Maximum available HOME size is ${remaining_home_gib} GiB. Setting HOME to maximum."
                HOME_SIZE_GIB=$remaining_home_gib
            else
                HOME_SIZE_GIB=$HOME_SIZE_GIB_INPUT
            fi

            HOME_SIZE_MIB=$(( HOME_SIZE_GIB * 1024 ))
            home_end=$(( root_end + HOME_SIZE_MIB ))
        fi

        echo "✅ Partition sizes set: ROOT=${ROOT_SIZE_GIB} GiB, HOME=${HOME_SIZE_GIB} GiB, SWAP=$((SWAP_SIZE_MIB/1024)) GiB"
        break
    done
}
#=========================================================================================================================================#
# Partition disk
#=========================================================================================================================================#
partition_disk() {
    [[ -z "$DEV" ]] && die "partition_disk(): missing device argument"
    parted -s "$DEV" mklabel gpt || die "Failed to create GPT"

    local root_start root_end swap_start swap_end boot_start boot_end home_start home_end

    if [[ "$MODE" == "BIOS" ]]; then
        # Create tiny bios_grub partition (no FS) + /boot ext4 + optional swap + root + home
        # Create tiny bios_grub partition (no FS)
        parted -s "$DEV" mkpart primary 1MiB $((1+BIOS_GRUB_SIZE_MIB))MiB
        parted -s "$DEV" set 1 bios_grub on
        
        # /boot ext4
        boot_start=$((1+BIOS_GRUB_SIZE_MIB))
        boot_end=$((boot_start + BOOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary ext4 ${boot_start}MiB ${boot_end}MiB

        if [[ "$SWAP_ON" == "1" ]]; then
            swap_start=$boot_end
            swap_end=$((swap_start + SWAP_SIZE_MIB))
            parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB

            root_start=$swap_end
        else
            root_start=$boot_end
        fi

        root_end=$((root_start + ROOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB

        home_start=$root_end
        if [[ "$HOME_SIZE_MIB" -eq 0 ]]; then
            parted -s "$DEV" mkpart primary "$HOME_FS" ${home_start}MiB 100%
        else
            home_end=$((home_start + HOME_SIZE_MIB))
            parted -s "$DEV" mkpart primary "$HOME_FS" ${home_start}MiB ${home_end}MiB
        fi
    else
        # UEFI — keep existing behavior (EFI FAT32 + root + optional swap + home)
        parted -s "$DEV" mkpart primary fat32 1MiB $((1+EFI_SIZE_MIB))MiB
        parted -s "$DEV" set 1 boot on

        root_start=$((1+EFI_SIZE_MIB))
        root_end=$((root_start + ROOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB

        if [[ "$SWAP_ON" == "1" ]]; then
            swap_start=$root_end
            swap_end=$((swap_start + SWAP_SIZE_MIB))
            parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB
            home_start=$swap_end
        else
            home_start=$root_end
        fi

        if [[ "$HOME_SIZE_MIB" -eq 0 ]]; then
            parted -s "$DEV" mkpart primary "$HOME_FS" ${home_start}MiB 100%
        else
            home_end=$((home_start + HOME_SIZE_MIB))
            parted -s "$DEV" mkpart primary "$HOME_FS" ${home_start}MiB ${home_end}MiB
        fi
    fi

    partprobe "$DEV" || true
    udevadm settle --timeout=5 || true
    sleep 1

    echo "✅ Partitioning completed. Verify with lsblk."
}
#=========================================================================================================================================#
# Format & mount
#=========================================================================================================================================#
format_and_mount() {
    detect_boot_mode
    local ps
    ps=$(part_suffix "$DEV")

    if [[ "$MODE" == "BIOS" ]]; then
        P_BIOS="${DEV}${ps}1"   # bios_grub (no fs)
        P_BOOT="${DEV}${ps}2"  # ext4 /boot
        if [[ "$SWAP_ON" == "1" ]]; then
            P_SWAP="${DEV}${ps}3"
            P_ROOT="${DEV}${ps}4"
            P_HOME="${DEV}${ps}5"
        else
            P_ROOT="${DEV}${ps}3"
            P_HOME="${DEV}${ps}4"
        fi

        # Format /boot as ext4
        mkfs.ext4 -L boot "$P_BOOT"
    else
        P_EFI="${DEV}${ps}1"
        P_ROOT="${DEV}${ps}2"
        if [[ "$SWAP_ON" == "1" ]]; then
            P_SWAP="${DEV}${ps}3"
            P_HOME="${DEV}${ps}4"
        else
            P_HOME="${DEV}${ps}3"
        fi

        mkfs.fat -F32 "$P_EFI"
    fi

    # Swap handling
    if [[ "$SWAP_ON" == "1" && -n "${P_SWAP:-}" ]]; then
        mkswap -L swap "$P_SWAP"
        swapon "$P_SWAP"
    else
        echo "→ Swap disabled"
    fi

    # Root & Home formatting & mounting
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        mkfs.btrfs -f -L root "$P_ROOT"
        # create subvolumes only for btrfs root; handle home separately if not btrfs
        mount "$P_ROOT" /mnt
        btrfs subvolume create /mnt/@
        # If home is also btrfs, create @home
        if [[ "$HOME_FS" == "btrfs" ]]; then
            btrfs subvolume create /mnt/@home
            umount /mnt
            mount -o subvol=@,noatime,compress=zstd "$P_ROOT" /mnt
            mkdir -p /mnt/home
            mount -o subvol=@home,defaults,noatime,compress=zstd "$P_ROOT" /mnt/home
        else
            # root btrfs + home ext4
            umount /mnt
            mount -o subvol=@,noatime,compress=zstd "$P_ROOT" /mnt
            mkfs.ext4 -L home "$P_HOME"
            mkdir -p /mnt/home
            mount "$P_HOME" /mnt/home
        fi
    else
        # root is ext4: format root and home as ext4
        mkfs.ext4 -L root "$P_ROOT"
        mkfs.ext4 -L home "$P_HOME"
        mount "$P_ROOT" /mnt
        mkdir -p /mnt/home
        mount "$P_HOME" /mnt/home
    fi

    # Mount boot partition(s)
    mkdir -p /mnt/boot
    if [[ "$MODE" == "BIOS" ]]; then
        mount "$P_BOOT" /mnt/boot
    else
        mkdir -p /mnt/boot/efi
        mount "$P_EFI" /mnt/boot/efi
    fi

    mountpoint -q /mnt/home || die "/mnt/home failed to mount!"
    echo "✅ Partitions formatted and mounted under /mnt."

    echo "Generating /etc/fstab..."
    
    mkdir -p /mnt/etc
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "Partition Table and Mountpoints:"
    cat /mnt/etc/fstab
}
#=========================================================================================================================================#
# Install base system
#=========================================================================================================================================#
install_base_system() {
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
}
#=========================================================================================================================================#
# GRUB installation
#=========================================================================================================================================#
install_grub() {
    detect_boot_mode
    local ps
    ps=$(part_suffix "$DEV")

    # Start with minimal essential modules
    local GRUB_MODULES="part_gpt part_msdos normal boot linux search search_fs_uuid"

    #--------------------------------------#
    # Add FS module (idempotent)
    #--------------------------------------#
    add_fs_module() {
        local fs="$1"
        case "$fs" in
            btrfs) [[ "$GRUB_MODULES" != *btrfs* ]] && GRUB_MODULES+=" btrfs" ;;
            xfs)   [[ "$GRUB_MODULES" != *xfs* ]] && GRUB_MODULES+=" xfs" ;;
            f2fs)  [[ "$GRUB_MODULES" != *f2fs* ]] && GRUB_MODULES+=" f2fs" ;;
            zfs)   [[ "$GRUB_MODULES" != *zfs* ]] && GRUB_MODULES+=" zfs" ;;
            ext2|ext3|ext4) [[ "$GRUB_MODULES" != *ext2* ]] && GRUB_MODULES+=" ext2" ;;
            vfat|fat16|fat32) [[ "$GRUB_MODULES" != *fat* ]] && GRUB_MODULES+=" fat" ;;
        esac
    }

    #--------------------------------------#
    # Detect RAID (mdadm)
    #--------------------------------------#
    echo "→ Detecting RAID arrays..."
    if lsblk -o TYPE -nr /mnt | grep -q "raid"; then
        echo "→ Found md RAID."
        GRUB_MODULES+=" mdraid1x"
    fi

    #--------------------------------------#
    # Detect LUKS (outermost layer)
    #--------------------------------------#
    echo "→ Detecting LUKS containers..."
    mapfile -t luks_lines < <(lsblk -o NAME,TYPE -nr | grep -E "crypt|luks")
    for line in "${luks_lines[@]}"; do
        echo "→ LUKS container: $line"
        [[ "$GRUB_MODULES" != *cryptodisk* ]] && GRUB_MODULES+=" cryptodisk luks"
    done

    #--------------------------------------#
    # Detect LVM (next layer)
    #--------------------------------------#
    echo "→ Detecting LVM volumes..."
    if lsblk -o TYPE -nr | grep -q "lvm"; then
        echo "→ Found LVM."
        [[ "$GRUB_MODULES" != *lvm* ]] && GRUB_MODULES+=" lvm"
    fi

    #--------------------------------------#
    # Detect filesystems under /mnt (final layer)
    #--------------------------------------#
    echo "→ Detecting filesystems..."
    mapfile -t fs_lines < <(lsblk -o MOUNTPOINT,FSTYPE -nr /mnt | grep -v '^$')
    for line in "${fs_lines[@]}"; do
        fs=$(awk '{print $2}' <<< "$line")
        [[ -n "$fs" ]] && add_fs_module "$fs"
    done

    echo "→ Final GRUB modules: $GRUB_MODULES"

    #--------------------------------------#
    # BIOS MODE
    #--------------------------------------#
    prepare_chroot
    if [[ "$MODE" == "BIOS" ]]; then
        echo "→ Installing GRUB for BIOS..."
        arch-chroot /mnt grub-install \
            --target=i386-pc \
            --modules="$GRUB_MODULES" \
            --recheck "$DEV" || die "grub-install BIOS failed"

    #--------------------------------------#
    # UEFI MODE
    #--------------------------------------#
    else
        echo "→ Installing GRUB for UEFI..."

        # Ensure EFI is mounted
        if ! mountpoint -q /mnt/boot/efi; then
            mkdir -p /mnt/boot/efi
            mount "${P_EFI:-${DEV}1}" /mnt/boot/efi || die "Failed to mount EFI"
        fi

        arch-chroot /mnt grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=GRUB \
            --modules="$GRUB_MODULES" \
            --recheck \
            --no-nvram || die "grub-install UEFI failed"

        # Fallback BOOTX64.EFI
        arch-chroot /mnt bash -c 'mkdir -p /boot/efi/EFI/Boot && cp -f /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/Boot/BOOTX64.EFI || true'

        # Reset stale entries
        LABEL="Arch Linux"
        for num in $(efibootmgr -v | awk "/${LABEL}/ {print substr(\$1,5,4)}"); do
            efibootmgr -b "$num" -B || true
        done

        # Create entry
        efibootmgr -c -d "$DEV" -p 1 -L "$LABEL" -l '\EFI\GRUB\grubx64.efi' || true
    fi

    #--------------------------------------#
    # Generate GRUB config
    #--------------------------------------#
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || die "grub-mkconfig failed"

    #--------------------------------------#
    # Optional Secure Boot
    #--------------------------------------#
    if arch-chroot /mnt command -v sbctl &>/dev/null; then
        echo "→ Secure Boot: signing binaries"
        arch-chroot /mnt sbctl status || arch-chroot /mnt sbctl create-keys
        arch-chroot /mnt sbctl enroll-keys --microsoft || true
        arch-chroot /mnt sbctl sign --path /boot/efi/EFI/GRUB/grubx64.efi || true
        arch-chroot /mnt sbctl sign --path /boot/vmlinuz-linux || true
    fi

    echo "✅ GRUB fully installed and configured."
}
#=========================================================================================================================================#
# Configure system
#=========================================================================================================================================#
configure_system() {
sleep 1
clear
echo "#===================================================================================================#"
echo "# 4) Setting Basic variables for chroot (defaults provided)                                         #"
echo "#===================================================================================================#"
echo
# -------------------------------
# Prompt for timezone, locale, hostname, and username
# -------------------------------
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
# -------------------------------
# Prepare chroot (mount pseudo-filesystems etc.)
# -------------------------------
prepare_chroot
# -------------------------------
# Create postinstall.sh inside chroot
# -------------------------------
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
export LANG="${LANG_LOCALE}"   # OK
# do NOT export LC_ALL
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
#========================================================#
# 6) Root + user passwords (interactive with retries)
#========================================================#
: "${NEWUSER:?NEWUSER is not set}"
# Helper for interactive retries (works inside chroot TTY)
set_password_interactive() {
    local target="$1"
    local max_tries=3
    local i=1
    while (( i <= max_tries )); do
        echo "--------------------------------------------------------"
        echo "Set password for $target (attempt $i/$max_tries)"
        echo "--------------------------------------------------------"
        if passwd "$target"; then
            echo "✅ Password set for $target"
            return 0
        fi
        echo "⚠️ Password setup failed — try again."
        ((i++))
    done
    echo "❌ Giving up after $max_tries failed attempts for $target"
    return 1
}

# Create user and set passwords
useradd -m -G wheel -s /bin/bash "${NEWUSER}" || true
set_password_interactive "${NEWUSER}"
set_password_interactive "root"
#========================================================#
# 7) Ensure user has sudo privileges
#========================================================#
echo "${NEWUSER} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${NEWUSER}
chmod 440 /etc/sudoers.d/${NEWUSER}
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
#========================================================#
# 8) Home directory setup
#========================================================#
HOME_DIR="/home/$NEWUSER"
CONFIG_DIR="$HOME_DIR/.config"
mkdir -p "$CONFIG_DIR"
chown -R "$NEWUSER:$NEWUSER" "$HOME_DIR"
#========================================================#
# 9) Enable basic services
#========================================================#
systemctl enable NetworkManager
systemctl enable sshd
echo "Postinstall inside chroot finished."
EOF
# -------------------------------
# Inject actual values into postinstall.sh
# -------------------------------
sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh
# -------------------------------
# Make executable and run inside chroot
# -------------------------------
chmod +x /mnt/root/postinstall.sh
arch-chroot /mnt /root/postinstall.sh
rm -f /mnt/root/postinstall.sh
echo "✅ System configured."
}
#=========================================================================================================================================#
# Network Mirror Selection
#=========================================================================================================================================#
network_mirror_selection()
{
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 7A) INTERACTIVE MIRROR SELECTION & OPTIMIZATION                                                   #"
echo "#===================================================================================================#"
echo
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
}

#=========================================================================================================================================#
# Graphics Driver Selection Menu
#=========================================================================================================================================#
gpu_driver()
{
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
}
#=========================================================================================================================================#
# Window Manager Selection Menu
#=========================================================================================================================================#
window_manager()
{
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
                WM_PKGS=(hyprland hyprpaper hyprshot hypridle hyprlock waybar kitty )
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
}
#=========================================================================================================================================#
# Login Manager & Display Manager Menu
#=========================================================================================================================================#
lm_dm()
{
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
}        
#=========================================================================================================================================#
# Extra Pacman Package Installer
#=========================================================================================================================================#
extra_pacman_pkg()
{    
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
                    EXTRA_PKGS=(  ) #===========================================================================================================================EXTRA PACMAN PACKAGES GOES HERE!!!!!!!!!!!!!!
                
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
}
#=========================================================================================================================================#
# Aur Package Installer
#=========================================================================================================================================#
optional_aur()
{    
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

                    #EXTRA_PKGS=( firefox htop vlc vlc-plugin-ffmpeg vlc-plugins-all network-manager-applet networkmanager discover nvtop zram-generator ttf-hack kitty kvantum breeze breeze-icons qt5ct qt6ct rofi nwg-look otf-font-awesome cpupower brightnessctl waybar dolphin dolphin-plugins steam discover bluez bluez-tools nwg-displays btop ark flatpak pavucontrol )
                
}
#=========================================================================================================================================#
# Hyprland optional Configuration Installer - from http://github.com/terra88/hyprland-setup
#=========================================================================================================================================#
hyprland_optional()
{     
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
#====================================== Custom Partition // Choose Filesystem Custom #====================================================#
#=========================================================================================================================================#
#=========================================================================================================================================#
# Convert user-entered size to MiB
# Convert human-readable size (10G, 512M) to MiB
convert_to_mib() {
    local SIZE="${1^^}" SIZE="${SIZE// /}"
    [[ "$SIZE" == "100%" || "$SIZE" == "100%FREE" ]] && echo "100%" && return
    if [[ "$SIZE" =~ ^([0-9]+)(G|GB|GI|GIB)$ ]]; then echo $(( ${BASH_REMATCH[1]} * 1024 ))
    elif [[ "$SIZE" =~ ^([0-9]+)(M|MB|MI|MIB)$ ]]; then echo "${BASH_REMATCH[1]}"
    else die "Invalid size format: $1 (use M/MiB, G/GiB, or 100%)"; fi
}

#===========================
# LVM + LUKS Setup
#===========================
lvm_luks_setup() {
    detect_boot_mode
    echo "=== Logical Volume + Optional LUKS Setup ==="

    lsblk -d -o NAME,SIZE,MODEL,TYPE
    read -rp "Target disk (e.g. /dev/sda): " DEV
    DEV="/dev/${DEV##*/}"
    [[ -b "$DEV" ]] || die "$DEV not found"

    BOOT_SIZE=$([[ "$BOOT_MODE" == "UEFI" ]] && echo 1024 || echo 512)
    echo "→ Boot mode: $BOOT_MODE, Boot partition size: ${BOOT_SIZE}MiB"

    wipefs -af "$DEV"
    parted -s "$DEV" mklabel gpt
    PARTITIONS=()
    declare -A used_mounts
    START_MB=$BOOT_SIZE

    # Raw Partitions
    read -rp "How many raw partitions before LVM? " RAW_COUNT
    [[ "$RAW_COUNT" =~ ^[0-9]+$ ]] || die "Invalid number"

    for ((i=1;i<=RAW_COUNT;i++)); do
        echo "--- Raw Partition $i ---"
        while true; do
            read -rp "Size (e.g. 20G, 512M, 100% for last): " SIZE
            SIZE_MI=$(convert_to_mib "$SIZE") || continue
            END=$(( SIZE_MI == "100%" ? $(lsblk -b -dn -o SIZE "$DEV")/1024/1024 : START_MB+SIZE_MI ))
            (( END <= $(lsblk -b -dn -o SIZE "$DEV")/1024/1024 )) || { echo "Too large"; continue; }
            break
        done

        while true; do
            read -rp "Mountpoint (/ /boot /home /data1 /data2 swap none): " MNT
            [[ -z "${used_mounts[$MNT]:-}" ]] || { echo "Mount used"; continue; }
            used_mounts[$MNT]=1; break
        done

        while true; do
            read -rp "Filesystem (ext4, btrfs, xfs, f2fs, fat32, swap): " FS
            case "$FS" in ext4|btrfs|xfs|f2fs|fat32|swap) break ;; *) echo "Invalid FS" ;; esac
        done

        read -rp "Label (optional): " LABEL
        parted -a optimal -s "$DEV" mkpart primary "${START_MB}MiB" "${END}MiB"
        PART="${DEV}$( [[ "$DEV" =~ nvme ]] && echo "p")$i"
        PARTITIONS+=("$PART:$MNT:$FS:$LABEL")
        echo "Created $PART -> mount=$MNT fs=$FS label=${LABEL:-<none>}"
        START_MB=$END
    done

    # LVM PV + VG
    echo "→ Creating LVM partition on remaining space"
    parted -a optimal -s "$DEV" mkpart primary ${START_MB}MiB 100%
    LVM_PART="${DEV}$(($(parted -s "$DEV" print | grep -c 'primary')))"
    parted -s "$DEV" set $(($(parted -s "$DEV" print | grep -c 'primary'))) lvm on
    partprobe "$DEV"

    read -rp "Create new VG on $LVM_PART? (yes/no): " do_pv
    if [[ "$do_pv" =~ ^[Yy] ]]; then
        read -rp "VG name: " VG
        pvcreate "$LVM_PART"; vgcreate "$VG" "$LVM_PART"
    else
        read -rp "Existing VG name: " VG
        vgs "$VG" &>/dev/null || die "VG not found"
    fi

    # LVs
    read -rp "Create LVs? (yes/no): " CREATE_LV
    [[ "$CREATE_LV" =~ ^[Yy] ]] || return
    read -rp "Number of LVs: " LV_COUNT
    [[ "$LV_COUNT" =~ ^[0-9]+$ ]] || die "Invalid number"

    for ((i=1;i<=LV_COUNT;i++)); do
        echo "--- LV $i ---"
        read -rp "LV name: " LV_NAME

        while true; do
            read -rp "Mountpoint (/ /home /data1 /data2 swap none): " MNT
            [[ -z "${used_mounts[$MNT]:-}" ]] || { echo "Mount used"; continue; }
            used_mounts[$MNT]=1; break
        done

        while true; do
            read -rp "Filesystem (ext4, btrfs, xfs, f2fs, swap): " FS
            case "$FS" in ext4|btrfs|xfs|f2fs|swap) break ;; *) echo "Invalid FS" ;; esac
        done

        ENC=0
        [[ "$MNT" != "swap" && "$MNT" != "none" ]] && read -rp "Encrypt this LV? (yes/no): " enc && [[ "$enc" =~ ^[Yy] ]] && ENC=1

        VG_FREE=$(vgdisplay "$VG" | awk '/Free  PE/ {print $5}')
        PE_SIZE=$(vgdisplay "$VG" | awk '/PE Size/ {print $3}')
        VG_FREE_GB=$(awk -v f="$VG_FREE" -v pe="$PE_SIZE" 'BEGIN{printf "%.2f", f*pe/1024}')

        while true; do
            read -rp "LV size (10G, 100%FREE) [max ${VG_FREE_GB}G]: " LV_SIZE
            LV_SIZE=${LV_SIZE^^}
            if [[ "$LV_SIZE" == "100%FREE" ]]; then LV_CREATE_ARG="-l 100%FREE"; break
            elif [[ "$LV_SIZE" =~ ^([0-9]+)(G|M)$ ]]; then
                VAL=${BASH_REMATCH[1]}; UNIT=${BASH_REMATCH[2]}
                SIZE_GB=$(( UNIT=="M"?VAL/1024:VAL ))
                (( $(echo "$SIZE_GB <= $VG_FREE_GB" | bc -l) )) && LV_CREATE_ARG="-L ${SIZE_GB}G" && break
                echo "Too big"
            else echo "Invalid"; fi
        done

        lvcreate $LV_CREATE_ARG -n "$LV_NAME" "$VG"
        if (( ENC )); then
            cryptsetup luksFormat /dev/"$VG"/"$LV_NAME"
            cryptsetup open /dev/"$VG"/"$LV_NAME" "$LV_NAME"
            LV_PATH="/dev/mapper/$LV_NAME"
        else
            LV_PATH="/dev/$VG/$LV_NAME"
        fi
        PARTITIONS+=("$LV_PATH:$MNT:$FS:$LV_NAME")
        echo "→ LV created: $LV_PATH mounted at $MNT fs=$FS label=$LV_NAME"
    done

    echo "✅ Raw + LVM + LUKS setup complete."
    printf '%s\n' "${PARTITIONS[@]}"
}


#=========================================================================================================================================#
# Custom Partition Wizard (Unlimited partitions, any FS)
#=========================================================================================================================================#
custom_partition_wizard() {
    clear
    detect_boot_mode

    echo "=== Custom Partitioning ==="
    lsblk -d -o NAME,SIZE,MODEL,TYPE

    read -rp "Enter target disk (e.g. /dev/sda or /dev/nvme0n1): " DEV
    DEV="/dev/${DEV##*/}"
    [[ -b "$DEV" ]] || die "Device $DEV not found."

    echo "WARNING: This will erase everything on $DEV"
    read -rp "Type YES to continue: " CONFIRM
    [[ "$CONFIRM" == "YES" ]] || die "Aborted."

    safe_disk_cleanup
    parted -s "$DEV" mklabel gpt

    # Disk size
    disk_bytes=$(lsblk -b -dn -o SIZE "$DEV") || die "Cannot read disk size."
    disk_mib=$(( disk_bytes / 1024 / 1024 ))
    disk_gib_float=$(awk -v m="$disk_mib" 'BEGIN{printf "%.2f", m/1024}')
    echo "Disk size: ${disk_gib_float} GiB"

    read -rp "How many partitions would you like to create? " COUNT
    [[ "$COUNT" =~ ^[0-9]+$ && "$COUNT" -ge 1 ]] || die "Invalid partition count."

    PARTITIONS=()
    local START=1
    local ps=""
    [[ "$DEV" =~ nvme ]] && ps="p"

    for ((i=1; i<=COUNT; i++)); do
        echo ""
        echo "--- Partition $i ---"
        parted -s "$DEV" unit MiB print

        REMAINING=$(( disk_mib - START ))
        REMAINING_GB=$(awk -v m="$REMAINING" 'BEGIN{printf "%.2f", m/1024}')
        echo "→ Remaining disk: ${REMAINING}MiB (${REMAINING_GB} GiB)"

        while true; do
            read -rp "Size (ex: 20G, 512M, 100% for last): " SIZE
            SIZE_MI=$(convert_to_mib "$SIZE") || continue

            if [[ "$SIZE_MI" == "100%" ]]; then
                END=$disk_mib
            else
                END=$(( START + SIZE_MI ))
            fi

            if (( END > disk_mib )); then
                echo "⚠️  Partition too large! Max allowed: ${REMAINING} MiB (${REMAINING_GB} GiB)"
                continue
            fi

            PART_SIZE="${START}MiB ${END}MiB"
            break
        done

        # Mountpoint
        while true; do
            read -rp "Mountpoint (/, /boot, /boot/efi, /home, /data1, /data2, swap, none): " MNT
            case "$MNT" in
                /|/boot|/boot/efi|/home|/data1|/data2|swap|none) break ;;
                *) echo "Invalid mountpoint." ;;
            esac
        done

        # FS type
        while true; do
            read -rp "Filesystem (ext4, btrfs, xfs, f2fs, fat32, swap): " FS
            case "$FS" in ext4|btrfs|xfs|f2fs|fat32|swap) break ;; *) echo "Unsupported FS." ;; esac
        done

        read -rp "Label (optional): " LABEL

        parted -s "$DEV" mkpart primary $PART_SIZE || die "parted failed"
        PART="${DEV}${ps}${i}"
        PARTITIONS+=("$PART:$MNT:$FS:$LABEL")
        echo "Created $PART -> mount=$MNT fs=$FS label=${LABEL:-<none>}"

        [[ "$END" != "$disk_mib" ]] && START=$END
    done

    echo "=== Partition layout created ==="
    printf "%s\n" "${PARTITIONS[@]}"
    parted -s "$DEV" unit MiB print
}

#===========================
# Format & mount partitions
#===========================
format_and_mount_all() {
    echo "→ Formatting and mounting partitions..."
    mkdir -p /mnt
    declare -A used_mounts

    for entry in "${PARTITIONS[@]}"; do
        IFS=':' read -r PART MOUNT FS LABEL <<< "$entry"
        MOUNT="${MOUNT:-}"; LABEL="${LABEL:-}"

        [[ -n "${used_mounts[$MOUNT]:-}" && "$MOUNT" != "swap" && "$MOUNT" != "none" ]] && continue
        [[ "$MOUNT" != "swap" && "$MOUNT" != "none" ]] && used_mounts[$MOUNT]=1

        partprobe "$PART"
        [[ -b "$PART" ]] || die "$PART missing"

        case "$FS" in
            ext4) mkfs.ext4 -F "$PART" ;;
            btrfs) mkfs.btrfs -f "$PART" ;;
            xfs) mkfs.xfs -f "$PART" ;;
            f2fs) mkfs.f2fs -f "$PART" ;;
            swap) mkswap "$PART"; swapon "$PART"; continue ;;
            none) continue ;;
        esac

        [[ -n "$LABEL" ]] && case "$FS" in
            ext4) e2label "$PART" "$LABEL" ;;
            btrfs) btrfs filesystem label "$PART" "$LABEL" ;;
            xfs) xfs_admin -L "$LABEL" "$PART" ;;
            f2fs) f2fslabel "$PART" "$LABEL" ;;
        esac

        case "$MOUNT" in
            /) mount "$PART" /mnt ;;
            /home) mkdir -p /mnt/home; mount "$PART" /mnt/home ;;
            /boot) mkdir -p /mnt/boot; mount "$PART" /mnt/boot ;;
            /boot/efi|/efi) mkdir -p /mnt/boot/efi; mount "$PART" /mnt/boot/efi ;;
            /data1) mkdir -p /mnt/data1; mount "$PART" /mnt/data1 ;;
            /data2) mkdir -p /mnt/data2; mount "$PART" /mnt/data2 ;;
            *) mkdir -p "/mnt$MOUNT"; mount "$PART" "/mnt$MOUNT" ;;
        esac
    done

    mkdir -p /mnt/etc
    genfstab -U /mnt > /mnt/etc/fstab
}

#============================================================================================================================#
#ENSURE FS SUPPORT FOR CUSTOM PARTITIO SCHEME
#============================================================================================================================#
ensure_fs_support_for_custom() {
    echo "→ Running ensure_fs_support_for_custom()"

    # Detect requested FS types (prefer PARTITIONS array)
    local want_xfs=0 want_f2fs=0 want_btrfs=0 want_ext4=0
    if [[ ${#PARTITIONS[@]} -gt 0 ]]; then
        for e in "${PARTITIONS[@]}"; do
            IFS=':' read -r p m f l <<< "$e"
            case "$f" in
                xfs)   want_xfs=1 ;;
                f2fs)  want_f2fs=1 ;;
                btrfs) want_btrfs=1 ;;
                ext4)  want_ext4=1 ;;
            esac
        done
    else
        # Fallback: inspect /mnt/etc/fstab if present
        if [[ -f /mnt/etc/fstab ]]; then
            while read -r _ _ fs _ _ _; do
                case "$fs" in
                    xfs)  want_xfs=1 ;;
                    f2fs) want_f2fs=1 ;;
                    btrfs)want_btrfs=1 ;;
                    ext4) want_ext4=1 ;;
                    *) ;; # ignore other lines
                esac
            done < /mnt/etc/fstab
        fi
    fi

    # Build package list to install inside the target
    local pkgs=()
    (( want_xfs ))  && pkgs+=(xfsprogs)
    (( want_f2fs )) && pkgs+=(f2fs-tools)
    (( want_btrfs ))&& pkgs+=(btrfs-progs)
    (( want_ext4 )) && pkgs+=(e2fsprogs)

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        echo "→ No special filesystem tools required for custom install."
        return 0
    fi

    echo "→ Installing filesystem tools into target: ${pkgs[*]}"
    arch-chroot /mnt pacman -Sy --noconfirm "${pkgs[@]}" || {
        echo "⚠️ pacman install inside chroot failed once; retrying..."
        sleep 1
        arch-chroot /mnt pacman -Sy --noconfirm "${pkgs[@]}" || die "Failed to install filesystem tools in target"
    }

    # Patch mkinitcpio.conf inside target to ensure proper HOOKS and MODULES
    arch-chroot /mnt /bin/bash <<'CHROOT_EOF'
set -e
MKCONF="/etc/mkinitcpio.conf"

echo "→ (chroot) Patching ${MKCONF}..."

# Ensure HOOKS contains 'block' before 'filesystems'. If HOOKS exists, try to ensure order.
if grep -q '^HOOKS=' "$MKCONF"; then
    # Extract current hooks (naive)
    current_hooks=$(sed -n 's/^HOOKS=(\(.*\))/\1/p' "$MKCONF" || echo "")
    # Build a desired base sequence and then append any existing hooks not duplicate
    base="base udev autodetect modconf block filesystems"
    # Append any tokens from current_hooks that aren't already in base
    for tok in $current_hooks; do
        if ! echo " $base " | grep -q " $tok "; then
            base="$base $tok"
        fi
    done
    # Replace HOOKS line
    sed -i "s|^HOOKS=(.*)|HOOKS=($base)|" "$MKCONF" 2>/dev/null || sed -i "s|^HOOKS=.*|HOOKS=($base)|" "$MKCONF" || true
else
    echo 'HOOKS=(base udev autodetect modconf block filesystems)' >> "$MKCONF"
fi

# Build desired module list depending on available mkfs utilities
desired_modules=()
command -v mkfs.xfs >/dev/null 2>&1 && desired_modules+=(xfs)
command -v mkfs.f2fs >/dev/null 2>&1 && desired_modules+=(f2fs)
command -v mkfs.btrfs >/dev/null 2>&1 && desired_modules+=(btrfs)
command -v mkfs.ext4 >/dev/null 2>&1 && desired_modules+=(ext4)

# If MODULES exists, append missing modules; otherwise create it.
if grep -q '^MODULES=' "$MKCONF"; then
    existing=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "$MKCONF" || echo "")
    for m in "${desired_modules[@]}"; do
        if ! echo " $existing " | grep -q " $m "; then
            # append module
            sed -i -E "s/^MODULES=\((.*)\)/MODULES=(\1 $m)/" "$MKCONF" || true
        fi
    done
else
    if (( ${#desired_modules[@]} > 0 )); then
        echo "MODULES=(${desired_modules[*]})" >> "$MKCONF"
    fi
fi

# If no fsck helpers found for the installed filesystems, remove fsck hook to avoid mkinitcpio warning
has_fsck=0
command -v fsck.ext4 >/dev/null 2>&1 && has_fsck=1
command -v fsck.f2fs >/dev/null 2>&1 && has_fsck=1
command -v xfs_repair >/dev/null 2>&1 && has_fsck=1

if [[ $has_fsck -eq 0 ]]; then
    sed -i '/fsck/d' "$MKCONF" || true
fi

echo "→ (chroot) mkinitcpio.conf patch complete."
CHROOT_EOF

    echo "→ ensure_fs_support_for_custom() finished."
}
#=========================================================================================================================================#
# Quick Partition Main
#=========================================================================================================================================#
quick_partition() {
    detect_boot_mode
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    while true; do
        read -rp "Enter target disk (e.g. /dev/sda): " DEV
        DEV="/dev/${DEV##*/}"
        [[ -b "$DEV" ]] && break || echo "Invalid device, try again."
    done

    read -rp "This will ERASE all data on $DEV. Continue? [Y/n]: " yn
    [[ "$yn" =~ ^[Nn]$ ]] && die "Aborted by user."

    safe_disk_cleanup
    ask_partition_sizes
    select_filesystem
    select_swap
    partition_disk
    format_and_mount
    install_base_system
    configure_system
    install_grub
    network_mirror_selection
    gpu_driver
    window_manager
    lm_dm
    extra_pacman_pkg
    optional_aur
    hyprland_optional
}
#==============================================================
# Custom Partition Route
#==============================================================
custom_partition() {
    detect_boot_mode
    custom_partition_wizard      # user-defined partitions
    format_and_mount_all      # auto mount based on $BOOT_MODE
    install_base_system
    ensure_fs_support_for_custom
    configure_system
    install_grub
    network_mirror_selection
    gpu_driver
    window_manager
    lm_dm
    extra_pacman_pkg
    optional_aur
    hyprland_optional
}

#==============================================================
# LVM + LUKS Partition Route
#==============================================================
custom_lvm_luks() {
    detect_boot_mode
    lvm_luks_setup
    preview_partition_tree
    format_and_mount_all
    install_base_system
    ensure_fs_support_for_custom
    install_base_system
    configure_system
    install_grub
    network_mirror_selection
    gpu_driver
    window_manager
    lm_dm
    extra_pacman_pkg
    optional_aur
    hyprland_optional
}
#=========================================================================================================================================#
# Main menu
#=========================================================================================================================================#
menu() {
clear
logo
            echo "#==================================================#"
            echo "#          Select partitioning method              #"
            echo "#==================================================#"
            echo "|-1) Quick Partitioning  (automated, ext4, btrfs)  |"
            echo "|--------------------------------------------------|"
            echo "|-2) Custom Partitioning (FS:ext4,btrfs,f2fs,xfs)  |"
            echo "|--------------------------------------------------|"
            echo "|-3) Logical Volume - Custom Partition Route       |"
            echo "|--------------------------------------------------|"
            echo "|-4) Return back to start                          |"
            echo "#==================================================#"
            read -rp "Enter choice [1-2]: " INSTALL_MODE
            case "$INSTALL_MODE" in
                1) quick_partition ;;
                2) custom_partition ;;
                3) custom_lvm_luks ;;
                4) echo "Exiting..."; exit 0 ;;
                *) echo "Invalid choice"; menu ;;
            esac
}
#=========================================================================================================================================#
# Menu - This is where the first call to Menu Happens.
#=========================================================================================================================================#
menu # PROGRAM START !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#=========================================================================================================================================#                  
sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# Cleanup postinstall script & Final Messages & Instructions                                        #"
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
echo "  swapoff ${P_SWAP} || true" # Changed from P3 to P_SWAP for consistency
echo "  reboot"
#Cleanup postinstall script
rm -f /mnt/root/postinstall.sh
#Final messages & instructions
echo
echo "Installation base and basic configuration finished."
echo "To reboot into your new system:"
echo "  umount -R /mnt"
echo "  swapoff ${P_SWAP} || true" # Changed from P3 to P_SWAP for consistency
echo "  reboot"
echo
echo "Done."
echo "#===========================================================================#"
echo "# -GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88             #"
echo "# -Author  : Terra88                                                        #"
echo "# -GitHub  : http://github.com/Terra88                                      #"
echo "#===========================================================================#"
