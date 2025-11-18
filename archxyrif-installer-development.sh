#=========================================================================================================================================#
# GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88        
# Author  : Terra88 
# Purpose : Arch Linux custom installer
# GitHub  : http://github.com/Terra88
#=========================================================================================================================================#
color_cmd() {
    local color="$1"
    shift
    if [ $# -eq 1 ]; then
        # Single string, just print it
        echo -e "${color}$1${RESET}"
    else
        # Treat as command
        "$@" | while IFS= read -r line; do
            echo -e "${color}${line}${RESET}"
        done
    fi
}
# Helper to color messages safely
color_echo() {
    local color="$1"
    shift
    echo -e "${color}$*${RESET}"
}
#=========================================================================================================================================#
# Source variables
#=========================================================================================================================================#
#===COLOR-MAPPER===#
CYAN="\e[36m"
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"
#===COLOR-MAPPER===#
#=========================================================================================================================================#
# Preparation
#=========================================================================================================================================#
# Arch logo: Edited manually by Terra88
#=========================================================================================================================================#
logo(){
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo -e "${CYAN}| The Great Monolith of Installing Arch Linux!                                                      |${RESET}"
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo -e "${CYAN}|                                                                                                   |${RESET}"
echo -e "${CYAN}|        d8888                 888      Y88b   d88P                  d8b  .d888                     |${RESET}"
echo -e "${CYAN}|       d88888                 888       Y88b d88P                   Y8P d88P                       |${RESET}"
echo -e "${CYAN}|      d88P888                 888        Y88o88P                        888                        |${RESET}"
echo -e "${CYAN}|     d88P 888 888d888 .d8888b 88888b.     Y888P    888  888 888d888 888 888888                     |${RESET}"
echo -e "${CYAN}|    d88P  888 888P.  d88P.    888 .88b    d888b    888  888 888P.   888 888                        |${RESET}"
echo -e "${CYAN}|   d88P   888 888    888      888  888   d88888b   888  888 888     888 888                        |${RESET}"
echo -e "${CYAN}|  d8888888888 888    Y88b.    888  888  d88P Y88b  Y88b 888 888     888 888                        |${RESET}"
echo -e "${CYAN}| d88P     888 888     .Y8888P 888  888 d88P   Y88b  .Y88888 888     888 888                        |${RESET}"
echo -e "${CYAN}|                                                        888                                        |${RESET}"
echo -e "${CYAN}|                                                  Y8b d88P                                         |${RESET}"
echo -e "${CYAN}|                                                     Y88P                                          |${RESET}"
echo -e "${CYAN}|         Semi-Automated / Interactive - Arch Linux Installer                                       |${RESET}"
echo -e "${CYAN}|                                                                                                   |${RESET}"
echo -e "${CYAN}|        GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88(Tero.H)                       |${RESET}"
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo -e "${CYAN}|-Table of Contents:                |-0) Disk Format INFO                                           |${RESET}"
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo -e "${CYAN}|-1)Disk Selection & Format         |- UEFI & BIOS(LEGACY) SUPPORT                                  |${RESET}"
echo -e "${CYAN}|-2)Pacstrap:Installing Base system |- wipes old signatures                                         |${RESET}"
echo -e "${CYAN}|-3)Generating fstab                |- Partitions: BOOT/EFI(1024MiB)(/ROOT)(/HOME)(SWAP)            |${RESET}"
echo -e "${CYAN}|-4)Setting Basic variables         |- 1) Quick Partition: Root/Home & Swap on or off options       |${RESET}"
echo -e "${CYAN}|-5)Installing GRUB for UEFI        |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |${RESET}" 
echo -e "${CYAN}|-6)Setting configs/enabling.srv    |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |${RESET}"
echo -e "${CYAN}|-7)Setting Pacman Mirror           |- 2) Custom Partition/Format Route for ext4,btrfs,xfs,f2fs     |${RESET}"
echo -e "${CYAN}|-Optional:                         |- 3) LV & LUKS Coming soon.                                    |${RESET}"
echo -e "${CYAN}|-8A)GPU-Guided install             |---------------------------------------------------------------|${RESET}"
echo -e "${CYAN}|-8B)Guided Window Manager Install  |# Author  : Terra88(Tero.H)                                    |${RESET}"
echo -e "${CYAN}|-8C)Guided Login Manager Install   |# Purpose : Arch Linux custom installer                        |${RESET}"
echo -e "${CYAN}|-9)Extra Pacman & AUR PKG Install  |# GitHub  : http://github.com/Terra88                          |${RESET}"
echo -e "${CYAN}|-If Hyprland Selected As WM        | ↜(╰ •ω•)╯ψ ↑_(ΦωΦ;)Ψ ୧( ಠ┏ل͜┓ಠ )୨ (ʘдʘ╬) ( •̀ᴗ•́ )و   (◣◢)ψ     |${RESET}"
echo -e "${CYAN}|-10)Optional Theme install         | (づ｡◕‿‿◕｡)づ ◥(ฅº￦ºฅ)◤ (㇏(•̀ᵥᵥ•́)ノ) ＼(◑д◐)＞∠(◑д◐)          |${RESET}"
echo -e "${CYAN}#===================================================================================================#${RESET}"
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
MNT=""
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
#-------------------LV-LUKS-----------------------------------#
ENCRYPTION_ENABLED=0 # 0=false, 1=true
LUKS_PART_UUID=""
LUKS_MAPPER_NAME=""
LVM_VG_NAME=""
LVM_ROOT_LV_NAME=""
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
    echo -e "${YELLOW}ERROR: $*" >&2
    exit 1
}

part_suffix() {
    local dev="$1"
    [[ "$dev" =~ nvme|mmcblk ]] && echo "p" || echo ""
}
#=========================================================================#
# Helper: Prepare pseudo-filesystems for chroot
#=========================================================================#
prepare_chroot() {
    echo -e "\n${CYAN}🔧 Preparing pseudo-filesystems for chroot...${RESET}"
    mkdir -p /mnt
    for fs in proc sys dev run; do
        mount --bind "/$fs" "/mnt/$fs" 2>/dev/null || mount --rbind "/$fs" "/mnt/$fs"
        mount --make-rslave "/mnt/$fs" 2>/dev/null || true
    done
    echo -e "${GREEN}✅ Pseudo-filesystems mounted into /mnt.${RESET}"
}

#=========================================================================#
# Helper: Cleanup mounts and swap
#=========================================================================#
cleanup() {
    echo -e "\n${CYAN}🧹 Running cleanup...${RESET}"
    swapoff -a 2>/dev/null || true

    if mountpoint -q /mnt; then
        umount -R /mnt 2>/dev/null || true
    fi

    sync
    echo -e "${GREEN}✅ Cleanup done.${RESET}"
}

#=========================================================================#
# Ensure cleanup runs on EXIT, INT, TERM
#=========================================================================#
trap cleanup EXIT INT TERM
#=========================================================================================================================================#
# SAFE DISK UNMOUNT & CLEANUP BEFORE PARTITIONING
#=========================================================================================================================================#
safe_disk_cleanup() {
    [[ -z "${DEV:-}" ]] && die "safe_disk_cleanup(): DEV not set"
    echo
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo -e "${CYAN}# - PRE-CLEANUP: Unmounting old partitions, subvolumes, LUKS and LVM from $DEV                      #${RESET}"
    echo -e "${CYAN}#===================================================================================================#${RESET}"

    # 1) Protect the live ISO device
    local iso_dev
    iso_dev=$(findmnt -no SOURCE / 2>/dev/null || true)
    if [[ "$iso_dev" == "$DEV"* ]]; then
        echo -e "${RED}❌ This disk is being used as the live ISO source. Aborting.${RESET}"
        return 1
    fi

    # 2) Unmount all partitions of $DEV (not anything else!)
    echo -e "${CYAN}→ Unmounting mounted partitions of $DEV...${RESET}"
    for p in $(lsblk -ln -o NAME,MOUNTPOINT "$DEV" | awk '$2!=""{print $1}' | tac); do
        local part="/dev/$p"
        if mountpoint -q "$part" 2>/dev/null || grep -q "^$part" /proc/mounts; then
            umount -R "$part" 2>/dev/null && echo -e "  ${GREEN}Unmounted $part${RESET}"
        fi
    done
    swapoff "${DEV}"* 2>/dev/null || true

    # 3) Deactivate LVMs on this disk
    echo -e "${CYAN}→ Deactivating LVM volumes related to $DEV ...${RESET}"
    vgchange -an || true
    for lv in $(lsblk -rno NAME "$DEV" | grep -E '^.*--.*$' || true); do
        dmsetup remove "/dev/mapper/$lv" 2>/dev/null && echo -e "  ${GREEN}Removed $lv${RESET}" || true
    done

    # 4) Close any LUKS mappings that belong to this disk
    echo -e "${CYAN}→ Closing any LUKS mappings...${RESET}"
    for map in $(lsblk -rno NAME,TYPE | awk '$2=="crypt"{print $1}'); do
        local backing
        backing=$(cryptsetup status "$map" 2>/dev/null | awk -F': ' '/device:/{print $2}')
        [[ "$backing" == "$DEV"* ]] && cryptsetup close "$map" && echo -e "  ${GREEN}Closed $map${RESET}"
    done

    echo -e "${CYAN}→ Removing stray device-mapper entries ...${RESET}"
    dmsetup remove_all 2>/dev/null || true
    
    # 5) Remove old BTRFS subvolume mounts (if any)
    echo -e "${CYAN}→ Cleaning BTRFS subvolumes...${RESET}"
    for mnt in $(mount | grep "$DEV" | awk '{print $3}' | sort -r); do
        umount -R "$mnt" 2>/dev/null || true
    done

    # 6) Optional signature wipe
    echo -e "${CYAN}→ Wiping old filesystem / partition signatures...${RESET}"
    for part in $(lsblk -ln -o NAME "$DEV" | tail -n +2); do
        wipefs -af "/dev/$part" 2>/dev/null || true
    done
    wipefs -af "$DEV" 2>/dev/null || true

    echo -e "${GREEN}✅ Disk cleanup complete for $DEV.${RESET}"
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
        echo -e "${RED}❌ /mnt not found or not a directory — cannot chroot.${RESET}"
        return 1
    fi

    for ((i=1; i<=MAX_RETRIES; i++)); do
        echo
        echo -e "${CYAN}Attempt $i of $MAX_RETRIES: ${CMD[*]}${RESET}"
        if "${CHROOT_CMD[@]}" "${CMD[@]}"; then
            echo -e "${GREEN}✅ Installation succeeded on attempt $i${RESET}"
            return 0
        else
            echo -e "${YELLOW}⚠️ Installation failed on attempt $i${RESET}"
            if (( i < MAX_RETRIES )); then
                echo -e "${MAGENTA}🔄 Refreshing keys and mirrors, retrying in ${RETRY_DELAY}s...${RESET}"
                "${CHROOT_CMD[@]}" bash -c '
                    pacman-key --init
                    pacman-key --populate archlinux
                    pacman -Sy --noconfirm archlinux-keyring
                ' || echo -e "${YELLOW}⚠️ Keyring refresh failed.${RESET}"
                
                if [[ -n "$MIRROR_COUNTRY" ]]; then
                    "${CHROOT_CMD[@]}" reflector --country "$MIRROR_COUNTRY" --age 12 --protocol https --sort rate \
                        --save /etc/pacman.d/mirrorlist || echo -e "${YELLOW}⚠️ Mirror refresh failed.${RESET}"
                fi
                sleep "$RETRY_DELAY"
            fi
        fi
    done

    echo -e "${RED}❌ Installation failed after ${MAX_RETRIES} attempts.${RESET}"
    return 1
}

safe_pacman_install() {
    local CHROOT_CMD=("${!1}")
    shift
    local PKGS=("$@")

    for PKG in "${PKGS[@]}"; do
        install_with_retry CHROOT_CMD[@] pacman -S --needed --noconfirm --overwrite="*" "$PKG" || \
            echo -e "${YELLOW}⚠️ Skipping $PKG${RESET}"
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
    if [[ -d /sys/firmware/efi ]]; then
        MODE="UEFI"
        BIOS_BOOT_PART_CREATED=false
        BOOT_SIZE_MIB=$EFI_SIZE_MIB
        echo -e "${CYAN}UEFI detected.${RESET}"
    else
        MODE="BIOS"
        BIOS_BOOT_PART_CREATED=true
        BOOT_SIZE_MIB=$BOOT_SIZE_MIB
        echo -e "${CYAN}Legacy BIOS detected.${RESET}"
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
select_filesystem() {
    clear
    echo -e "${CYAN}#===============================================================================#${RESET}"
    echo -e "${CYAN}|  Filesystem Selection Options                                                 |${RESET}"
    echo -e "${CYAN}#===============================================================================#${RESET}"
    echo -e "${CYAN}| 1) EXT4 (root + home)                                                         |${RESET}"
    echo -e "${CYAN}|-------------------------------------------------------------------------------|${RESET}"
    echo -e "${CYAN}| 2) BTRFS (root + home)                                                        |${RESET}"
    echo -e "${CYAN}|-------------------------------------------------------------------------------|${RESET}"
    echo -e "${CYAN}| 3) BTRFS root + EXT4 home                                                     |${RESET}"
    echo -e "${CYAN}#===============================================================================#${RESET}"
    read -rp "$(echo -e "${CYAN}Select filesystem [default=1]: ${RESET}")" FS_CHOICE
    FS_CHOICE="${FS_CHOICE:-1}"
    case "$FS_CHOICE" in
        1) ROOT_FS="ext4"; HOME_FS="ext4"; echo -e "${GREEN}→ Selected EXT4 for root + home${RESET}" ;;
        2) ROOT_FS="btrfs"; HOME_FS="btrfs"; echo -e "${GREEN}→ Selected BTRFS for root + home${RESET}" ;;
        3) ROOT_FS="btrfs"; HOME_FS="ext4"; echo -e "${GREEN}→ Selected BTRFS root + EXT4 home${RESET}" ;;
        *) echo -e "${YELLOW}⚠️ Invalid choice, defaulting to EXT4${RESET}"; ROOT_FS="ext4"; HOME_FS="ext4" ;;
    esac    
}

#=========================================================================================================================================#
# Select Swap
#=========================================================================================================================================#
select_swap() {
    clear
    echo -e "${CYAN}#===============================================================================#${RESET}"
    echo -e "${CYAN}| Swap On / Off                                                                 |${RESET}"
    echo -e "${CYAN}#===============================================================================#${RESET}"
    echo -e "${CYAN}| 1) Swap On                                                                    |${RESET}"
    echo -e "${CYAN}|-------------------------------------------------------------------------------|${RESET}"
    echo -e "${CYAN}| 2) Swap Off                                                                   |${RESET}"
    echo -e "${CYAN}|-------------------------------------------------------------------------------|${RESET}"
    echo -e "${CYAN}| 3) Exit                                                                       |${RESET}"
    echo -e "${CYAN}#===============================================================================#${RESET}"
    read -rp "$(echo -e "${CYAN}Select option [default=1]: ${RESET}")" SWAP_ON
    SWAP_ON="${SWAP_ON:-1}"
    case "$SWAP_ON" in
        1) SWAP_ON="1"; echo -e "${GREEN}→ Swap enabled${RESET}" ;;
        2) SWAP_ON="0"; echo -e "${GREEN}→ Swap disabled${RESET}" ;;
        3) echo -e "${YELLOW}Exiting installer${RESET}"; exit 1 ;;
        *) echo -e "${YELLOW}⚠️ Invalid choice, defaulting to Swap On${RESET}"; SWAP_ON="1"; ;;
    esac
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

    color_echo "$CYAN" "Disk $DEV ≈ ${disk_gib_int} GiB"

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
        color_echo "$CYAN" "Enter ROOT size in GiB (max ${max_root_gib}): "
        read -rp "> " ROOT_SIZE_GIB
        ROOT_SIZE_GIB="${ROOT_SIZE_GIB:-$max_root_gib}"
        [[ "$ROOT_SIZE_GIB" =~ ^[0-9]+$ ]] || { color_echo "$YELLOW" "⚠️ Must be numeric"; continue; }

        if (( ROOT_SIZE_GIB > max_root_gib )); then
            color_echo "$YELLOW" "⚠️ ROOT size too large. Limiting to maximum available ${max_root_gib} GiB."
            ROOT_SIZE_GIB=$max_root_gib
        fi

        ROOT_SIZE_MIB=$(( ROOT_SIZE_GIB * 1024 ))

        # Remaining space for home
        local remaining_home_gib=$(( disk_gib_int - ROOT_SIZE_GIB - SWAP_SIZE_MIB / 1024 - reserved_gib ))
        if (( remaining_home_gib < 1 )); then
            color_echo "$YELLOW" "⚠️ Not enough space left for /home. Reduce ROOT or SWAP size."
            continue
        fi

        color_echo "$CYAN" "Enter HOME size in GiB (ENTER for remaining ${remaining_home_gib}): "
        read -rp "> " HOME_SIZE_GIB_INPUT

        if [[ -z "$HOME_SIZE_GIB_INPUT" ]]; then
            # Use all remaining space
            HOME_SIZE_GIB=$remaining_home_gib
            HOME_SIZE_MIB=0      # will handle as 100% in partitioning
            home_end="100%"
        else
            [[ "$HOME_SIZE_GIB_INPUT" =~ ^[0-9]+$ ]] || { color_echo "$YELLOW" "⚠️ Must be numeric"; continue; }

            # Limit to remaining space
            if (( HOME_SIZE_GIB_INPUT > remaining_home_gib )); then
                color_echo "$YELLOW" "⚠️ Maximum available HOME size is ${remaining_home_gib} GiB. Setting HOME to maximum."
                HOME_SIZE_GIB=$remaining_home_gib
            else
                HOME_SIZE_GIB=$HOME_SIZE_GIB_INPUT
            fi

            HOME_SIZE_MIB=$(( HOME_SIZE_GIB * 1024 ))
            home_end=$(( root_end + HOME_SIZE_MIB ))
        fi

        color_echo "$GREEN" "✅ Partition sizes set: ROOT=${ROOT_SIZE_GIB} GiB, HOME=${HOME_SIZE_GIB} GiB, SWAP=$((SWAP_SIZE_MIB/1024)) GiB"
        break
    done
}
#=========================================================================================================================================#
# Partition disk
#=========================================================================================================================================#
partition_disk() {
    [[ -z "$DEV" ]] && die "partition_disk(): missing device argument"

    color_echo "$CYAN" "→ Creating GPT partition table on $DEV..."
    parted -s "$DEV" mklabel gpt || die "Failed to create GPT"

    local root_start root_end swap_start swap_end boot_start boot_end home_start home_end

    if [[ "$MODE" == "BIOS" ]]; then
        color_echo "$CYAN" "→ Creating BIOS/MBR partitions..."

        # bios_grub partition (tiny, no FS)
        parted -s "$DEV" mkpart primary 1MiB $((1+BIOS_GRUB_SIZE_MIB))MiB
        parted -s "$DEV" set 1 bios_grub on
        color_echo "$GREEN" "→ bios_grub partition created"

        # /boot ext4
        boot_start=$((1+BIOS_GRUB_SIZE_MIB))
        boot_end=$((boot_start + BOOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary ext4 ${boot_start}MiB ${boot_end}MiB
        color_echo "$GREEN" "→ /boot partition created (${boot_start}MiB-${boot_end}MiB)"

        if [[ "$SWAP_ON" == "1" ]]; then
            swap_start=$boot_end
            swap_end=$((swap_start + SWAP_SIZE_MIB))
            parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB
            color_echo "$GREEN" "→ Swap partition created (${swap_start}MiB-${swap_end}MiB)"
            root_start=$swap_end
        else
            root_start=$boot_end
        fi

        root_end=$((root_start + ROOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB
        color_echo "$GREEN" "→ Root partition created (${root_start}MiB-${root_end}MiB)"

        home_start=$root_end
        if [[ "$HOME_SIZE_MIB" -eq 0 ]]; then
            parted -s "$DEV" mkpart primary "$HOME_FS" ${home_start}MiB 100%
        else
            home_end=$((home_start + HOME_SIZE_MIB))
            parted -s "$DEV" mkpart primary "$HOME_FS" ${home_start}MiB ${home_end}MiB
        fi
        color_echo "$GREEN" "→ Home partition created"

    else
        color_echo "$CYAN" "→ Creating UEFI partitions..."

        # EFI FAT32
        parted -s "$DEV" mkpart primary fat32 1MiB $((1+EFI_SIZE_MIB))MiB
        parted -s "$DEV" set 1 boot on
        color_echo "$GREEN" "→ EFI partition created"

        root_start=$((1+EFI_SIZE_MIB))
        root_end=$((root_start + ROOT_SIZE_MIB))
        parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB
        color_echo "$GREEN" "→ Root partition created (${root_start}MiB-${root_end}MiB)"

        if [[ "$SWAP_ON" == "1" ]]; then
            swap_start=$root_end
            swap_end=$((swap_start + SWAP_SIZE_MIB))
            parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB
            color_echo "$GREEN" "→ Swap partition created (${swap_start}MiB-${swap_end}MiB)"
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
        color_echo "$GREEN" "→ Home partition created"
    fi

    partprobe "$DEV" || true
    udevadm settle --timeout=5 || true
    sleep 1

    color_echo "$GREEN" "✅ Partitioning completed. Verify with lsblk."
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

        color_echo "$CYAN" "→ Formatting /boot as ext4..."
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

        color_echo "$CYAN" "→ Formatting EFI as FAT32..."
        mkfs.fat -F32 "$P_EFI"
    fi

    # Swap handling
    if [[ "$SWAP_ON" == "1" && -n "${P_SWAP:-}" ]]; then
        color_echo "$CYAN" "→ Setting up swap..."
        mkswap -L swap "$P_SWAP"
        swapon "$P_SWAP"
    else
        color_echo "$YELLOW" "→ Swap disabled"
    fi

    # Root & Home formatting & mounting
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        color_echo "$CYAN" "→ Formatting root as Btrfs..."
        mkfs.btrfs -f -L root "$P_ROOT"
        mount "$P_ROOT" /mnt
        btrfs subvolume create /mnt/@
        if [[ "$HOME_FS" == "btrfs" ]]; then
            btrfs subvolume create /mnt/@home
            umount /mnt
            mount -o subvol=@,noatime,compress=zstd "$P_ROOT" /mnt
            mkdir -p /mnt/home
            mount -o subvol=@home,defaults,noatime,compress=zstd "$P_ROOT" /mnt/home
        else
            umount /mnt
            mount -o subvol=@,noatime,compress=zstd "$P_ROOT" /mnt
            color_echo "$CYAN" "→ Formatting home as ext4..."
            mkfs.ext4 -L home "$P_HOME"
            mkdir -p /mnt/home
            mount "$P_HOME" /mnt/home
        fi
    else
        color_echo "$CYAN" "→ Formatting root and home as ext4..."
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
    color_echo "$GREEN" "✅ Partitions formatted and mounted under /mnt."

    color_echo "$CYAN" "→ Generating /etc/fstab..."
    mkdir -p /mnt/etc
    genfstab -U /mnt >> /mnt/etc/fstab
    color_echo "$CYAN" "→ Partition Table and Mountpoints:"
    cat /mnt/etc/fstab
}
#=========================================================================================================================================#
# Install base system
#=========================================================================================================================================#
install_base_system() {

sleep 1
clear
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo -e "${CYAN}# - Installing base system - Pacstrap!                                                              #${RESET}"
echo -e "${CYAN}#===================================================================================================#${RESET}"
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
  linux-firmware-whence
  vim
  sudo
  nano
  networkmanager
  efibootmgr
  openssh
  intel-ucode
  amd-ucode
  btrfs-progs
  f2fs-tools
  xfsprogs
  lvm2
  cryptsetup
)
echo "Installing base system packages: ${PKGS[*]}"
color_cmd "$GREEN" pacstrap /mnt "${PKGS[@]}"
}

#=========================================================================================================================================#
# Configure system
#=========================================================================================================================================#
configure_system() {

    sleep 1
    clear
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo -e "${CYAN}# -  Setting Basic variables for chroot (defaults provided)                                         #${RESET}"
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo

    # -------------------------------
    # Prompt for timezone, locale, hostname, and username
    # -------------------------------
    DEFAULT_TZ="Europe/Helsinki"
    read -rp "$(echo -e "${CYAN}Enter timezone [${DEFAULT_TZ}]: ${RESET}")" TZ
    TZ="${TZ:-$DEFAULT_TZ}"

    DEFAULT_LOCALE="fi_FI.UTF-8"
    read -rp "$(echo -e "${CYAN}Enter locale (LANG) [${DEFAULT_LOCALE}]: ${RESET}")" LANG_LOCALE
    LANG_LOCALE="${LANG_LOCALE:-$DEFAULT_LOCALE}"

    DEFAULT_KEYMAP="fi"
    read -rp "$(echo -e "${CYAN}Enter keyboard layout [${DEFAULT_KEYMAP}]: ${RESET}")" KEYMAP
    KEYMAP="${KEYMAP:-$DEFAULT_KEYMAP}"

    DEFAULT_HOSTNAME="archbox"
    read -rp "$(echo -e "${CYAN}Enter hostname [${DEFAULT_HOSTNAME}]: ${RESET}")" HOSTNAME
    HOSTNAME="${HOSTNAME:-$DEFAULT_HOSTNAME}"

    DEFAULT_USER="user"
    read -rp "$(echo -e "${CYAN}Enter username to create [${DEFAULT_USER}]: ${RESET}")" NEWUSER
    NEWUSER="${NEWUSER:-$DEFAULT_USER}"

    echo -e "${GREEN}→ Preparing chroot environment...${RESET}"
    prepare_chroot

    # -------------------------------
    # Create postinstall.sh inside chroot
    # -------------------------------
    echo -e "${GREEN}→ Creating postinstall.sh inside chroot...${RESET}"
    cat > /mnt/root/postinstall.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

TZ="{{TIMEZONE}}"
LANG_LOCALE="{{LANG_LOCALE}}"
KEYMAP="{{KEYMAP}}"
HOSTNAME="{{HOSTNAME}}"
NEWUSER="{{NEWUSER}}"

#---------------- Timezone & Clock ----------------#
ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
hwclock --systohc
echo -e "\e[32m✅ Timezone set to ${TZ}\e[0m"

#---------------- Locale ----------------#
if ! grep -q "^${LANG_LOCALE} UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "${LANG_LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LANG_LOCALE}" > /etc/locale.conf
export LANG="${LANG_LOCALE}"
export LC_ALL="${LANG_LOCALE}"
echo -e "\e[32m✅ Locale set to ${LANG_LOCALE}\e[0m"

#---------------- Hostname & /etc/hosts ----------------#
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS
echo -e "\e[32m✅ Hostname set to ${HOSTNAME}\e[0m"

#---------------- Keyboard layout ----------------#
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "FONT=lat9w-16" >> /etc/vconsole.conf
localectl set-keymap "${KEYMAP}"
localectl set-x11-keymap "${KEYMAP}"
echo -e "\e[32m✅ Keyboard layout set to ${KEYMAP}\e[0m"

#---------------- Initramfs ----------------#
mkinitcpio -P
echo -e "\e[32m✅ Initramfs regenerated\e[0m"

#---------------- Users & Passwords ----------------#
useradd -m -G wheel -s /bin/bash "${NEWUSER}" || true

set_password_interactive() {
    local target="$1"
    local max_tries=3
    local i=1
    while (( i <= max_tries )); do
        echo -e "\e[33m--------------------------------------------------------\e[0m"
        echo -e "\e[33mSet password for $target (attempt $i/$max_tries)\e[0m"
        echo -e "\e[33m--------------------------------------------------------\e[0m"
        if passwd "$target"; then
            echo -e "\e[32m✅ Password set for $target\e[0m"
            return 0
        fi
        echo -e "\e[31m⚠️ Password setup failed — try again.\e[0m"
        ((i++))
    done
    echo -e "\e[31m❌ Giving up after $max_tries failed attempts for $target\e[0m"
    return 1
}

set_password_interactive "${NEWUSER}"
set_password_interactive "root"

#---------------- Sudo privileges ----------------#
echo "${NEWUSER} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${NEWUSER}
chmod 440 /etc/sudoers.d/${NEWUSER}
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo -e "\e[32m✅ Sudo privileges configured\e[0m"

#---------------- Home directory ----------------#
HOME_DIR="/home/$NEWUSER"
CONFIG_DIR="$HOME_DIR/.config"
mkdir -p "$CONFIG_DIR"
chown -R "$NEWUSER:$NEWUSER" "$HOME_DIR"
echo -e "\e[32m✅ Home directory prepared for ${NEWUSER}\e[0m"

#---------------- Enable services ----------------#
systemctl enable NetworkManager
systemctl enable sshd
echo -e "\e[32m✅ Basic services enabled\e[0m"

EOF

    echo -e "${GREEN}→ Injecting variables into postinstall.sh...${RESET}"
    sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
    sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
    sed -i "s|{{KEYMAP}}|${KEYMAP}|g" /mnt/root/postinstall.sh
    sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
    sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh

    echo -e "${GREEN}→ Running postinstall.sh inside chroot...${RESET}"
    arch-chroot /mnt /root/postinstall.sh

    rm -f /mnt/root/postinstall.sh
    echo -e "${GREEN}✅ System configured successfully.${RESET}"
}
#=========================================================================================================================================#
# GRUB installation
#=========================================================================================================================================#
install_grub() {
    detect_boot_mode
    local ps
    local TARGET_DISKS=()
    local MOUNTED_PARTS=$(mount | grep /mnt | awk '{print $1}')
    ps=$(part_suffix "$DEV")
    local GRUB_MODULES="part_gpt part_msdos normal boot linux search search_fs_uuid f2fs cryptodisk luks lvm ext2"

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
    echo -e "${CYAN}→ Detecting RAID arrays...${RESET}"
    if lsblk -l -o TYPE -nr /mnt | grep -q "raid"; then
        echo -e "${GREEN}→ Found md RAID.${RESET}"
        GRUB_MODULES+=" mdraid1x"
    fi

    echo -e "${CYAN}→ Detecting LUKS containers...${RESET}"
    mapfile -t luks_lines < <(lsblk -o NAME,TYPE -nr | grep -E "crypt|luks")
    for line in "${luks_lines[@]}"; do
        echo -e "${GREEN}→ LUKS container: $line${RESET}"
        [[ "$GRUB_MODULES" != *cryptodisk* ]] && GRUB_MODULES+=" cryptodisk luks"
    done

    echo -e "${CYAN}→ Detecting LVM volumes...${RESET}"
    if lsblk -o TYPE -nr | grep -q "lvm"; then
        echo -e "${GREEN}→ Found LVM.${RESET}"
        [[ "$GRUB_MODULES" != *lvm* ]] && GRUB_MODULES+=" lvm"
    fi

    echo -e "${CYAN}→ Detecting filesystems...${RESET}"
    mapfile -t fs_lines < <(lsblk -o MOUNTPOINT,FSTYPE -nr /mnt | grep -v '^$')
    for line in "${fs_lines[@]}"; do
        fs=$(awk '{print $2}' <<< "$line")
        [[ -n "$fs" ]] && add_fs_module "$fs"
    done

    echo -e "${CYAN}→ Final GRUB modules: ${GRUB_MODULES}${RESET}"

    for PART in $MOUNTED_PARTS; do
        local PARENT_DISK=$(lsblk -dn -o PKNAME "$PART" | head -n 1)
        if [[ -n "$PARENT_DISK" ]]; then
            local FULL_DISK="/dev/$PARENT_DISK"
            if ! printf '%s\n' "${TARGET_DISKS[@]}" | grep -q -P "^$FULL_DISK$"; then
                TARGET_DISKS+=("$FULL_DISK")
            fi
        fi
    done

    if [[ ${#TARGET_DISKS[@]} -eq 0 ]]; then
        echo -e "${RED}ERROR: Could not find any physical disk devices mounted under /mnt.${RESET}"
        return 1
    fi

    echo -e "${CYAN}→ Found critical disks for GRUB installation: ${TARGET_DISKS[*]}${RESET}"

    # --------------------------------------#
    # BIOS MODE
    # --------------------------------------#
    if [[ "$MODE" == "BIOS" ]]; then
        echo -e "${CYAN}→ Found target disk(s) for GRUB installation: ${TARGET_DISKS[*]}${RESET}"
        for DISK in "${TARGET_DISKS[@]}"; do
            echo -e "${CYAN}→ Installing GRUB (BIOS/MBR mode) on $DISK...${RESET}"
            arch-chroot /mnt grub-install \
                --target=i386-pc \
                --modules="$GRUB_MODULES" \
                --recheck "$DISK" || {
                    echo -e "${RED}ERROR: grub-install failed on $DISK. Did you ensure the 1MiB bios_grub partition is present and flagged on this physical disk?${RESET}"
                    return 1
                }
        done

    elif [[ "$MODE" == "UEFI" ]]; then
        echo -e "${CYAN}→ Installing GRUB for UEFI...${RESET}"

        if ! mountpoint -q /mnt/boot/efi; then
            mkdir -p /mnt/boot/efi
            mount "${P_EFI:-${DEV}1}" /mnt/boot/efi || die "Failed to mount EFI partition"
        fi

        if [[ "$ENCRYPTION_ENABLED" -eq 1 ]]; then
            arch-chroot /mnt bash -c "grep -q '^GRUB_ENABLE_CRYPTODISK=y' /etc/default/grub || echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub"
            echo -e "${GREEN}→ GRUB_ENABLE_CRYPTODISK=y added to /etc/default/grub${RESET}"

            GRUB_CMD="cryptdevice=UUID=${LUKS_PART_UUID}:${LUKS_MAPPER_NAME} root=/dev/${LVM_VG_NAME}/${LVM_ROOT_LV_NAME}"
            arch-chroot /mnt sed -i \
                "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${GRUB_CMD}\"|" \
                /etc/default/grub
            echo -e "${GREEN}→ Added cryptdevice=UUID to GRUB_CMDLINE_LINUX_DEFAULT${RESET}"
        fi

        arch-chroot /mnt grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=GRUB \
            --modules="$GRUB_MODULES" \
            --recheck \
            --no-nvram || die "grub-install UEFI failed"

        arch-chroot /mnt bash -c 'mkdir -p /boot/efi/EFI/Boot && cp -f /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/Boot/BOOTX64.EFI || true'

        LABEL="Arch Linux"
        for num in $(efibootmgr -v | awk "/${LABEL}/ {print substr(\$1,5,4)}"); do
            efibootmgr -b "$num" -B || true
        done

        efibootmgr -c -d "${TARGET_DISKS[0]}" -p 1 -L "$LABEL" -l '\EFI\GRUB\grubx64.efi' || true

        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg || die "grub-mkconfig failed"

        if arch-chroot /mnt command -v sbctl &>/dev/null; then
            echo -e "${CYAN}→ Secure Boot detected, signing GRUB and kernel${RESET}"
            arch-chroot /mnt sbctl status || arch-chroot /mnt sbctl create-keys
            arch-chroot /mnt sbctl enroll-keys --microsoft || true
            arch-chroot /mnt sbctl sign --path /boot/efi/EFI/GRUB/grubx64.efi || true
            arch-chroot /mnt sbctl sign --path /boot/vmlinuz-linux || true
        fi

        echo -e "${GREEN}✅ UEFI GRUB installed with LUKS+LVM support${RESET}"
    fi
}
#=========================================================================================================================================#
# Network Mirror Selection
#=========================================================================================================================================#
network_mirror_selection() {
    sleep 1
    clear
    echo
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo -e "${CYAN}# 7A) INTERACTIVE MIRROR SELECTION & OPTIMIZATION                                                   #${RESET}"
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo

    # Ensure reflector is installed in chroot
    arch-chroot /mnt pacman -Sy --needed --noconfirm reflector || {
        echo -e "${YELLOW}⚠️ Failed to install reflector inside chroot — continuing with defaults.${RESET}"
    }

    echo -e "${CYAN}#========================================================#${RESET}"
    echo -e "${CYAN}#                   MIRROR SELECTION                     #${RESET}" 
    echo -e "${CYAN}#========================================================#${RESET}"
    echo

    echo -e "${CYAN}Available mirror regions:${RESET}"
    echo -e "${CYAN}1) United States${RESET}"
    echo -e "${CYAN}2) Canada${RESET}"
    echo -e "${CYAN}3) Germany${RESET}"
    echo -e "${CYAN}4) Finland${RESET}"
    echo -e "${CYAN}5) United Kingdom${RESET}"
    echo -e "${CYAN}6) Japan${RESET}"
    echo -e "${CYAN}7) Australia${RESET}"
    echo -e "${CYAN}8) Custom country code (2-letter ISO, e.g., FR)${RESET}"
    echo -e "${CYAN}9) Skip (use default mirrors)${RESET}"

    read -rp "$(echo -e "${CYAN}Select your region [1-9, default=1]: ${RESET}")" MIRROR_CHOICE
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
            read -rp "$(echo -e "${CYAN}Enter 2-letter country code (e.g., FR): ${RESET}")" CUSTOM_CODE
            SELECTED_COUNTRY="$CUSTOM_CODE"
            ;;
        9|*)
            echo -e "${YELLOW}Skipping mirror optimization, using default mirrors.${RESET}"
            SELECTED_COUNTRY=""
            ;;
    esac

    if [[ -n "$SELECTED_COUNTRY" ]]; then
        echo -e "${GREEN}Optimizing mirrors for: $SELECTED_COUNTRY${RESET}"
        arch-chroot /mnt reflector --country "$SELECTED_COUNTRY" --age 12 --protocol https --sort rate \
            --save /etc/pacman.d/mirrorlist || echo -e "${YELLOW}⚠️ Mirror update failed, continuing.${RESET}"
        echo -e "${GREEN}✅ Mirrors updated.${RESET}"
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
     echo -e "${CYAN}#===================================================================================================#${RESET}"
     echo -e "${CYAN}# 8A) GPU DRIVER INSTALLATION                                                                       #${RESET}"
     echo -e "${CYAN}#===================================================================================================#${RESET}"
     echo
    
        echo -e "${CYAN}1) Intel${RESET}"
        echo -e "${CYAN}2) NVIDIA${RESET}"
        echo -e "${CYAN}3) AMD${RESET}"
        echo -e "${CYAN}4) All compatible drivers (default)${RESET}"
        echo -e "${CYAN}5) Skip${RESET}"
    
        read -rp "$(echo -e "${CYAN}Select GPU driver set [1-5, default=4]: ${RESET}")" GPU_CHOICE
        GPU_CHOICE="${GPU_CHOICE:-4}"
    
        GPU_PKGS=()
    
        case "$GPU_CHOICE" in
            1)
                GPU_PKGS=(mesa vulkan-intel lib32-mesa lib32-vulkan-intel)
                echo -e "${GREEN}→ Intel GPU drivers selected${RESET}"
                ;;
            2)
                GPU_PKGS=(nvidia nvidia-utils lib32-nvidia-utils nvidia-prime)
                echo -e "${GREEN}→ NVIDIA GPU drivers selected${RESET}"
                ;;
            3)
                GPU_PKGS=(mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon xf86-video-amdgpu)
                echo -e "${GREEN}→ AMD GPU drivers selected${RESET}"
                ;;
            4)
                GPU_PKGS=(mesa vulkan-intel lib32-mesa lib32-vulkan-intel nvidia nvidia-utils lib32-nvidia-utils nvidia-prime)
                echo -e "${GREEN}→ All compatible drivers selected (AMD skipped to prevent hybrid conflicts)${RESET}"
                ;;
            5|*)
                echo -e "${YELLOW}→ Skipping GPU driver installation.${RESET}"
                GPU_PKGS=()
                ;;
        esac

        if [[ ${#GPU_PKGS[@]} -gt 0 ]]; then
            echo -e "${CYAN}🔧 Ensuring multilib repository is enabled...${RESET}"
            "${CHROOT_CMD[@]}" bash -c '
                if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
                    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
                fi
                pacman -Sy --noconfirm
            '
            echo -e "${GREEN}🔧 Installing GPU driver packages: ${GPU_PKGS[*]}${RESET}"
            safe_pacman_install CHROOT_CMD[@] "${GPU_PKGS[@]}"
        fi
}
#=========================================================================================================================================#
# Window Manager Selection Menu
#=========================================================================================================================================#
# ---------- WM/DE Selection ----------
window_manager() {
   
    sleep 1
    clear
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo -e "${CYAN}#  WINDOW MANAGER / DESKTOP ENVIRONMENT SELECTION                                                   #${RESET}"
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo
  
    echo -e "${CYAN}1) Hyprland (Wayland)${RESET}"
    echo -e "${CYAN}2) KDE Plasma (X11/Wayland)${RESET}"
    echo -e "${CYAN}3) GNOME (X11/Wayland)${RESET}"
    echo -e "${CYAN}4) XFCE (X11)${RESET}"
    echo -e "${CYAN}5) Niri${RESET}"
    echo -e "${CYAN}6) Cinnamon${RESET}"
    echo -e "${CYAN}7) Mate${RESET}"
    echo -e "${CYAN}8) Sway (Wayland)${RESET}"
    echo -e "${CYAN}9) Skip selection${RESET}"

    read -rp "$(echo -e "${CYAN}Select your preferred WM/DE [1-9, default=6]: ${RESET}")" WM_CHOICE
    WM_CHOICE="${WM_CHOICE:-6}"

    WM_PKGS=()
    WM_AUR_PKGS=()
    EXTRA_PKGS=()
    EXTRA_AUR_PKGS=()

       # ---------- Set WM packages ----------
    case "$WM_CHOICE" in
        1)
            SELECTED_WM="hyprland"
            echo -e "${GREEN}→ Selected: Hyprland${RESET}"
            WM_PKGS=(hyprland hyprpaper hyprshot xdg-desktop-portal-hyprland hypridle hyprlock waybar kitty slurp kvantum dolphin dolphin-plugins rofi wofi discover nwg-displays nwg-look breeze breeze-icons bluez qt5ct qt6ct polkit-kde-agent blueman pavucontrol brightnessctl networkmanager network-manager-applet cpupower thermald nvtop btop pipewire otf-font-awesome ark grim dunst qview)
            WM_AUR_PKGS=(kvantum-theme-catppuccin-git qt6ct-kde wlogout wlrobs-hg)
            ;;
        2)
            SELECTED_WM="kde"
            echo -e "${GREEN}→ Selected: KDE Plasma${RESET}"
            WM_PKGS=(plasma-desktop kde-applications konsole kate dolphin ark sddm)
            ;;
        3)
            SELECTED_WM="gnome"
            echo -e "${GREEN}→ Selected: GNOME${RESET}"
            WM_PKGS=(gnome gdm gnome-tweaks)
            ;;
        4)
            SELECTED_WM="xfce"
            echo -e "${GREEN}→ Selected: XFCE${RESET}"
            WM_PKGS=(xfce4 xfce4-goodies xarchiver gvfs pavucontrol lightdm-gtk-greeter)
            ;;
        5)
            SELECTED_WM="niri"
            echo -e "${GREEN}→ Selected: Niri${RESET}"
            WM_PKGS=(niri alacritty fuzzel mako swaybg swayidle swaylock waybar xdg-desktop-portal-gnome xorg-xwayland)
            ;;
        6)
            SELECTED_WM="cinnamon"
            echo -e "${GREEN}→ Selected: Cinnamon${RESET}"
            WM_PKGS=(cinnamon engrampa gnome-keyring gnome-screenshot gnome-terminal gvfs-smb system-config-printer xdg-user-dirs-gtk xed)
            ;;
        7)
            SELECTED_WM="mate"
            echo -e "${GREEN}→ Selected: Mate${RESET}"
            WM_PKGS=(mate mate-extra)
            ;;
        8)
            SELECTED_WM="sway"
            echo -e "${GREEN}→ Selected: Sway${RESET}"
            WM_PKGS=(sway swaybg swaylock swayidle waybar wofi xorg-xwayland wmenu slurp pavucontrol grim foot brightnessctl)
            ;;
        9|*)
            SELECTED_WM="none"
            echo -e "${YELLOW}Skipping window manager installation.${RESET}"
            ;;
    esac

    # ---------- Auto-add mandatory dependencies ----------
    case "$SELECTED_WM" in
        hyprland)
            WM_PKGS+=(xorg-xwayland qt6-wayland xdg-desktop-portal-hyprland swayidle swaylock hyprpaper hyprshot waybar)
            ;;
        niri)
            WM_PKGS+=(xorg-xwayland qt6-wayland xdg-desktop-portal-gnome mako swaybg swayidle swaylock waybar)
            ;;
        sway)
            WM_PKGS+=(xorg-xwayland qt6-wayland xdg-desktop-portal wofi slurp foot)
            ;;
        kde)
            WM_PKGS+=(qt6-wayland)
            ;;
    esac

# ---------- Optional extra packages ----------
if [[ "$SELECTED_WM" != "none" ]]; then
    echo
    color_cmd "$CYAN" "Do you want to install extra packages for ${SELECTED_WM}? [y/N]: "
    read -r -p "" EXTRA_CHOICE
    EXTRA_CHOICE="${EXTRA_CHOICE,,}"
    if [[ "$EXTRA_CHOICE" == "y" ]]; then
        color_cmd "$CYAN" "Enter extra pacman packages (space-separated): "
        read -r -p "" EXTRA_PKGS_INPUT
        color_cmd "$CYAN" "Enter extra AUR packages (space-separated, leave empty if none): "
        read -r -p "" EXTRA_AUR_PKGS_INPUT

        IFS=' ' read -r -a EXTRA_PKGS <<< "$EXTRA_PKGS_INPUT"
        IFS=' ' read -r -a EXTRA_AUR_PKGS <<< "$EXTRA_AUR_PKGS_INPUT"
    fi
fi

# ---------- Install WM/DE packages ----------
if [[ ${#WM_PKGS[@]} -gt 0 ]]; then
    color_cmd "$GREEN" "Installing WM/DE packages..."
    safe_pacman_install CHROOT_CMD[@] "${WM_PKGS[@]}"
fi
if [[ ${#WM_AUR_PKGS[@]} -gt 0 ]]; then
    color_cmd "$GREEN" "Installing WM/DE AUR packages..."
    safe_aur_install CHROOT_CMD[@] "${WM_AUR_PKGS[@]}"
fi

# ---------- Install extra packages ----------
if [[ ${#EXTRA_PKGS[@]} -gt 0 ]]; then
    color_cmd "$YELLOW" "Installing extra pacman packages..."
    safe_pacman_install CHROOT_CMD[@] "${EXTRA_PKGS[@]}"
fi
if [[ ${#EXTRA_AUR_PKGS[@]} -gt 0 ]]; then
    color_cmd "$YELLOW" "Installing extra AUR packages..."
    safe_aur_install CHROOT_CMD[@] "${EXTRA_AUR_PKGS[@]}"
fi

lm_dm() {
    sleep 1
    clear
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo -e "${CYAN}#  Display Manager Selection                                                                        #${RESET}"
    echo -e "${CYAN}#===================================================================================================#${RESET}"

    DM_MENU=()
    DM_DEFAULT="6"

    # ---------- Filtered DM options ----------
    case "$SELECTED_WM" in
        gnome)
            DM_MENU=("1) GDM (required for GNOME Wayland)")
            DM_DEFAULT="1"
            ;;
        kde)
            DM_MENU=("2) SDDM (recommended for KDE)" "1) GDM (works but not ideal)")
            DM_DEFAULT="2"
            ;;
        niri)
            DM_MENU=("1) GDM (recommended)" "2) SDDM (works but sometimes session missing)" "4) Ly (TUI, always works)")
            DM_DEFAULT="1"
            ;;
        hyprland|sway)
            DM_MENU=("2) SDDM" "1) GDM" "4) Ly (TUI)")
            DM_DEFAULT="2"
            ;;
        xfce)
            DM_MENU=("3) LightDM (recommended)" "1) GDM" "2) SDDM" "5) LXDM")
            DM_DEFAULT="3"
            ;;
        cinnamon|mate)
            DM_MENU=("3) LightDM (recommended)" "1) GDM" "5) LXDM")
            DM_DEFAULT="3"
            ;;
        none)
            DM_MENU=("6) Skip Display Manager")
            DM_DEFAULT="6"
            ;;
        *)
            DM_MENU=("1) GDM" "2) SDDM" "3) LightDM" "4) Ly" "5) LXDM")
            DM_DEFAULT="6"
            ;;
    esac

    # ---------- Show menu ----------
    for entry in "${DM_MENU[@]}"; do
        echo -e "${CYAN}${entry}${RESET}"
    done
    echo -e "${CYAN}6) Skip Display Manager${RESET}"

    read -rp "$(echo -e "${CYAN}Select DM [default=${DM_DEFAULT}]: ${RESET}")" DM_CHOICE
    DM_CHOICE="${DM_CHOICE:-$DM_DEFAULT}"

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
            echo -e "${YELLOW}Skipping display manager installation.${RESET}"
            return
            ;;
            
    esac

    # ---------- Install DM packages ----------
    if [[ ${#DM_PKGS[@]} -gt 0 ]]; then
        echo -e "${GREEN}→ Installing display manager packages...${RESET}"
        safe_pacman_install CHROOT_CMD[@] "${DM_PKGS[@]}"
    fi
    if [[ ${#DM_AUR_PKGS[@]} -gt 0 ]]; then
        echo -e "${GREEN}→ Installing display manager AUR packages...${RESET}"
        safe_aur_install CHROOT_CMD[@] "${DM_AUR_PKGS[@]}"
    fi

    # ---------- Enable DM service ----------
    if [[ -n "$DM_SERVICE" ]]; then
        "${CHROOT_CMD[@]}" systemctl enable "$DM_SERVICE"
        echo -e "${CYAN}✅ Display manager service enabled: $DM_SERVICE${RESET}"
    fi

    # ---------- Ly autologin ----------
    if [[ "$DM_SERVICE" == "ly.service" && -n "$USER_NAME" ]]; then
        echo -e "${CYAN}→ Setting up Ly autologin for $USER_NAME...${RESET}"
        sudo mkdir -p /etc/systemd/system/ly.service.d
        cat <<'EOF' | sudo tee /etc/systemd/system/ly.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/ly -a $USER_NAME
EOF
        sudo systemctl daemon-reload
        echo -e "${GREEN}✅ Ly autologin configuration applied successfully.${RESET}"
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
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo -e "${CYAN}# 9A) EXTRA PACMAN PACKAGE INSTALLATION (Resilient + Safe)                                          #${RESET}"
    echo -e "${CYAN}#===================================================================================================#${RESET}"
    echo
    
            read -r -p "$(color_cmd "$CYAN" "Do you want to install EXTRA pacman packages? [y/N]: ")" INSTALL_EXTRA
            if [[ "$INSTALL_EXTRA" =~ ^[Yy]$ ]]; then
                read -r -p "$(color_cmd "$CYAN" "Enter any Pacman packages (space-separated), or leave empty: ")" EXTRA_PKG_INPUT
            
                # Clean list: neofetch removed (deprecated)
                EXTRA_PKGS=() #===========================================================================================================================EXTRA PACMAN PACKAGES GOES HERE!!!!!!!!!!!!!!
            
                # Filter out non-existent packages before installing
                VALID_PKGS=()
                for pkg in "${EXTRA_PKGS[@]}"; do
                    if "${CHROOT_CMD[@]}" pacman -Si "$pkg" &>/dev/null; then
                        VALID_PKGS+=("$pkg")
                    else
                        color_cmd "$YELLOW" "⚠️  Skipping invalid or missing package: $pkg"
                    fi
                done
            
                # Merge validated list with user input
                EXTRA_PKG=("${VALID_PKGS[@]}")
                if [[ -n "$EXTRA_PKG_INPUT" ]]; then
                    read -r -a EXTRA_PKG_INPUT_ARR <<< "$EXTRA_PKG_INPUT"
                    EXTRA_PKG+=("${EXTRA_PKG_INPUT_ARR[@]}")
                fi
            
                if [[ ${#EXTRA_PKG[@]} -gt 0 ]]; then
                    color_cmd "$GREEN" "Installing extra pacman packages..."
                    safe_pacman_install CHROOT_CMD[@] "${EXTRA_PKG[@]}"
                else
                    color_cmd "$YELLOW" "⚠️  No valid packages to install."
                fi
            else
                color_cmd "$CYAN" "Skipping extra pacman packages."
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
     echo -e "${CYAN}#===================================================================================================#${RESET}"
     echo -e "${CYAN}# 9B) OPTIONAL AUR PACKAGE INSTALLATION (with Conflict Handling)                                    #${RESET}"
     echo -e "${CYAN}#===================================================================================================#${RESET}"
     echo
     
                        read -r -p "$(color_cmd "$CYAN" "Install additional AUR packages using paru? [y/N]: ")" install_aur
            install_aur="${install_aur:-N}"
            
            if [[ "$install_aur" =~ ^[Yy]$ ]]; then
                read -r -p "$(color_cmd "$CYAN" "Enter any AUR packages (space-separated), or leave empty: ")" EXTRA_AUR_INPUT
            
                # Predefined extra AUR packages
                EXTRA_AUR_PKGS=()
            
                # Merge WM + DM AUR packages with user input
                AUR_PKGS=("${WM_AUR_PKGS[@]}" "${DM_AUR_PKGS[@]}" "${EXTRA_AUR_PKGS[@]}")
            
                if [[ -n "$EXTRA_AUR_INPUT" ]]; then
                    read -r -a EXTRA_AUR_INPUT_ARR <<< "$EXTRA_AUR_INPUT"
                    AUR_PKGS+=("${EXTRA_AUR_INPUT_ARR[@]}")
                fi
            
                color_cmd "$GREEN" "🔧 Installing AUR packages inside chroot..."
                safe_aur_install CHROOT_CMD[@] "${AUR_PKGS[@]}"
            else
                color_cmd "$CYAN" "Skipping AUR installation."
            fi


                
}
#=========================================================================================================================================#
# Hyprland optional Configuration Installer - from http://github.com/terra88/hyprland-setup
#=========================================================================================================================================#
hyprland_optional()
{     
  
      sleep 1
      clear
      echo
      echo -e "${CYAN}#===================================================================================================#${RESET}"
      echo -e "${CYAN}# 10) Hyprland Theme Setup (Optional) with .Config Backup                                           #${RESET}"
      echo -e "${CYAN}#===================================================================================================#${RESET}"
      echo
      sleep 1
     
                    if [[ " ${WM_CHOICE:-} " =~ "1" ]]; then
                
                    color_cmd "$GREEN" "🔧 Installing unzip and git inside chroot to ensure theme download works..."
                    arch-chroot /mnt pacman -S --needed --noconfirm unzip git 
                
                    read -r -p "$(color_cmd "$CYAN" "Do you want to install the Hyprland theme from GitHub? [y/N]: ")" INSTALL_HYPR_THEME
                    if [[ "$INSTALL_HYPR_THEME" =~ ^[Yy]$ ]]; then
                        color_cmd "$GREEN" "→ Running Hyprland theme setup inside chroot..."
                          
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
                          
                            color_cmd "$GREEN" "✅ Hyprland theme setup completed."
                            else
                                color_cmd "$CYAN" "Skipping Hyprland theme setup."
                            fi
                        fi
}                          
#=========================================================================================================================================#
# Quick Partition Main
#=========================================================================================================================================#
quick_partition() {
# Detect boot mode
detect_boot_mode

# Show available disks
color_cmd "$CYAN" "Available disks:"
lsblk -d -o NAME,SIZE,MODEL,TYPE

# Select target disk
while true; do
    read -rp "$(color_cmd "$CYAN" "Enter target disk (e.g. /dev/sda): ")" DEV
    DEV="/dev/${DEV##*/}"
    [[ -b "$DEV" ]] && break || color_cmd "$YELLOW" "Invalid device, try again."
done

# Confirm destructive operation
read -rp "$(color_cmd "$RED" "This will ERASE all data on $DEV. Continue? [Y/n]: ")" yn
[[ "$yn" =~ ^[Nn]$ ]] && die "$(color_cmd "$RED" "Aborted by user.")"

# Disk preparation
color_cmd "$GREEN" "Cleaning up disk..."
safe_disk_cleanup

# Partitioning and filesystem
ask_partition_sizes
select_filesystem
select_swap
partition_disk
format_and_mount

# Base system installation
install_base_system

# System configuration
configure_system
install_grub
network_mirror_selection

# Drivers and display/window managers
gpu_driver
window_manager
lm_dm

# Extra packages
extra_pacman_pkg
optional_aur
hyprland_optional

# Completion message
color_cmd "$GREEN" "✅ Arch Linux installation complete."
}
#=========================================================================================================================================#
#=========================================================================================================================================#
#====================================== Custom Partition // Choose Filesystem Custom #====================================================#
#=========================================================================================================================================#
#=========================================================================================================================================#
#HELPERS - FOR CUSTOM PARTITION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ---------------------------
# Convert size to MiB helper
# ---------------------------
convert_to_mib() {
    local SIZE="$1"
    SIZE="${SIZE,,}"       # lowercase
    SIZE="${SIZE// /}"     # remove spaces

    if [[ "$SIZE" == "100%" ]]; then
        echo "100%"
        return
    fi

    if [[ "$SIZE" =~ ^([0-9]+)(g|gi|gib)$ ]]; then
        echo $(( ${BASH_REMATCH[1]} * 1024 ))
    elif [[ "$SIZE" =~ ^([0-9]+)(m|mi|mib)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        color_cmd "$RED" "Invalid size format: $1. Use M, MiB, G, GiB, or 100%"
        return 1
    fi
}

#=========================================================================================================================================#
# Custom Partition Wizard (Unlimited partitions, any FS) - FIXED VERSION
#=========================================================================================================================================#
custom_partition_wizard() {
    clear
    detect_boot_mode

    color_cmd "$CYAN" "=== Custom Partitioning ==="
    lsblk -d -o NAME,SIZE,MODEL,TYPE

    read -rp "$(color_cmd "$CYAN" "Enter target disk (e.g. /dev/sda or /dev/nvme0n1): ")" DEV
    DEV="/dev/${DEV##*/}"
    [[ -b "$DEV" ]] || die "$(color_cmd "$RED" "Device $DEV not found.")"

    color_cmd "$RED" "WARNING: This will erase everything on $DEV"
    read -rp "$(color_cmd "$RED" "Type y/n to continue (Enter for yes): ")" CONFIRM
    if [[ -n "$CONFIRM" && ! "$CONFIRM" =~ ^(YES|yes|Y|y)$ ]]; then
        die "$(color_cmd "$RED" "Aborted.")"
    fi

    safe_disk_cleanup
    parted -s "$DEV" mklabel gpt

    local ps=""
    [[ "$DEV" =~ nvme ]] && ps="p"

    local NEW_PARTS=()
    local START=1
    local RESERVED_PARTS=0

    # ---------------- BIOS / UEFI reserved partitions ----------------
    if [[ "$MODE" == "BIOS" ]]; then
        read -rp "$(color_cmd "$CYAN" "Create BIOS Boot Partition automatically? (y/n): ")" bios_auto
        bios_auto="${bios_auto:-n}"
        if [[ "$bios_auto" =~ ^[Yy]$ ]]; then
            parted -s "$DEV" unit MiB mkpart primary 1MiB 2MiB || die "$(color_cmd "$RED" "Failed to create BIOS partition")"
            parted -s "$DEV" set 1 bios_grub on || die "$(color_cmd "$RED" "Failed to set bios_grub flag")"
            NEW_PARTS+=("${DEV}${ps}1:none:none:bios_grub")
            RESERVED_PARTS=$((RESERVED_PARTS+1))
            START=2
        fi
    fi

    if [[ "$MODE" == "UEFI" ]]; then
        read -rp "$(color_cmd "$CYAN" "Automatically create 1024MiB EFI System Partition? (y/n): ")" esp_auto
        esp_auto="${esp_auto:-n}"
        if [[ "$esp_auto" =~ ^[Yy]$ ]]; then
            parted -s "$DEV" unit MiB mkpart primary fat32 1MiB 1025MiB || die "$(color_cmd "$RED" "Failed to create ESP")"
            parted -s "$DEV" set 1 esp on
            parted -s "$DEV" set 1 boot on || true
            NEW_PARTS+=("${DEV}${ps}1:/boot/efi:fat32:EFI")
            RESERVED_PARTS=$((RESERVED_PARTS+1))
            START=1025
        fi
    fi

    # ---------------- Disk info ----------------
    local disk_bytes disk_mib
    disk_bytes=$(lsblk -b -dn -o SIZE "$DEV") || die "$(color_cmd "$RED" "Cannot read disk size.")"
    disk_mib=$(( disk_bytes / 1024 / 1024 ))
    color_cmd "$CYAN" "Disk size: $(( disk_mib / 1024 )) GiB"

    # ---------------- User-defined partitions ----------------
    read -rp "$(color_cmd "$CYAN" "How many partitions would you like to create on $DEV? ")" COUNT
    [[ "$COUNT" =~ ^[0-9]+$ && "$COUNT" -ge 1 ]] || die "$(color_cmd "$RED" "Invalid partition count.")"

    for ((j=1; j<=COUNT; j++)); do
        i=$((j + RESERVED_PARTS))
        parted -s "$DEV" unit MiB print

        local AVAILABLE=$((disk_mib - START))
        color_cmd "$CYAN" "Available space on disk: $AVAILABLE MiB"

        # Size
        while true; do
            read -rp "$(color_cmd "$CYAN" "Size (ex: 20G, 512M, 100% for last, default 100%): ")" SIZE
            SIZE="${SIZE:-100%}"
            SIZE_MI=$(convert_to_mib "$SIZE") || continue

            if [[ "$SIZE_MI" != "100%" && $SIZE_MI -gt $AVAILABLE ]]; then
                color_cmd "$YELLOW" "⚠ Requested size too large. Max available: $AVAILABLE MiB"
                continue
            fi
            break
        done

        if [[ "$SIZE_MI" != "100%" ]]; then
            END=$((START + SIZE_MI))
            PART_SIZE="${START}MiB ${END}MiB"
        else
            PART_SIZE="${START}MiB 100%"
            END="100%"
        fi

        # Mountpoint
        read -rp "$(color_cmd "$CYAN" "Mountpoint (/, /home, /boot, swap, none, leave blank for auto /dataX): ")" MNT
        if [[ -z "$MNT" ]]; then
            local next_data=1
            while grep -q "/data$next_data" <<<"${PARTITIONS[*]}"; do
                ((next_data++))
            done
            MNT="/data$next_data"
            color_cmd "$CYAN" "→ Auto-assigned mountpoint: $MNT"
        fi

        # Filesystem
        while true; do
            read -rp "$(color_cmd "$CYAN" "Filesystem (ext4, btrfs, xfs, f2fs, fat32, swap): ")" FS
            case "$FS" in
                ext4|btrfs|xfs|f2fs|fat32|swap) break ;;
                *) color_cmd "$YELLOW" "Unsupported FS." ;;
            esac
        done

        # Label
        read -rp "$(color_cmd "$CYAN" "Label (optional): ")" LABEL

        # Create partition
        parted -s "$DEV" unit MiB mkpart primary $PART_SIZE || die "$(color_cmd "$RED" "Failed to create partition $i")"
        PART="${DEV}${ps}${i}"
        NEW_PARTS+=("$PART:$MNT:$FS:$LABEL")
        [[ "$END" != "100%" ]] && START=$END
    done

    PARTITIONS+=("${NEW_PARTS[@]}")
    color_cmd "$CYAN" "=== Partitions for $DEV ==="
    printf "%s\n" "${NEW_PARTS[@]}"
}

#======================================CUSTOMDISKS=======================================================#
create_more_disks() {
    local disk_counter=1  # start numbering for /dataX

    # Initialize disk_counter based on existing PARTITIONS
    for entry in "${PARTITIONS[@]}"; do
        IFS=':' read -r _ MOUNT _ _ <<< "$entry"
        if [[ "$MOUNT" =~ ^/data([0-9]+)$ ]]; then
            ((disk_counter = disk_counter > ${BASH_REMATCH[1]} ? disk_counter : ${BASH_REMATCH[1]}))
        fi
    done
    ((disk_counter++))

    while true; do
        read -rp "$(color_cmd "$CYAN" "Do you want to edit another disk? (Yy/Nn, default no): ")" answer
        case "$answer" in
            [Yy])
                color_cmd "$GREEN" "→ Editing another disk..."
                custom_partition_wizard

                # Auto-assign /dataX for new partitions with 'none' mount
                for i in "${!PARTITIONS[@]}"; do
                    IFS=':' read -r PART MOUNT FS LABEL <<< "${PARTITIONS[$i]}"

                    if [[ "$MOUNT" != "none" && "$MOUNT" != "" ]]; then
                        continue
                    fi

                    if [[ "$LABEL" == "bios_grub" || "$MOUNT" =~ ^/(boot|boot/efi|)$ ]]; then
                        continue
                    fi

                    PARTITIONS[$i]="$PART:/data$disk_counter:$FS:$LABEL"
                    color_cmd "$CYAN" "→ Auto-assigned $PART to /data$disk_counter"
                    ((disk_counter++))
                done
                ;;
            ""|[Nn])
                color_cmd "$GREEN" "→ No more disks. Continuing..."
                break
                ;;
            *)
                color_cmd "$YELLOW" "Please enter Y or n."
                ;;
        esac
    done
}

#=========================================================================================================================================#
#  Format AND Mount Custom - UPDATED (Skips bios_grub specially)
#=========================================================================================================================================#
#=========================================================================================================================================#
#  Format AND Mount Custom - UPDATED (Accumulate disks; mount root first; safe unmounts)
#=========================================================================================================================================#
format_and_mount_custom() {
    color_cmd "$GREEN" "→ Formatting and mounting custom partitions..."
    mkdir -p /mnt

    if [[ ${#PARTITIONS[@]} -eq 0 ]]; then
        die "$(color_cmd "$RED" "No partitions to format/mount (PARTITIONS is empty).")"
    fi

    # --- Order: root (/) first, then others ---
    local ordered=() others=()
    for entry in "${PARTITIONS[@]}"; do
        IFS=':' read -r p m f l <<< "$entry"
        if [[ "$m" == "/" ]]; then
            ordered+=("$entry")
        else
            others+=("$entry")
        fi
    done
    ordered+=("${others[@]}")

    for entry in "${ordered[@]}"; do
        IFS=':' read -r PART MOUNT FS LABEL <<< "$entry"

        partprobe "$PART" 2>/dev/null || true
        udevadm settle --timeout=5 || true
        [[ -b "$PART" ]] || die "$(color_cmd "$RED" "Partition $PART not available.")"

        # Skip reserved partitions
        [[ "$LABEL" == "bios_grub" ]] && { color_cmd "$CYAN" ">>> Skipping BIOS boot partition $PART"; continue; }
        [[ "$FS" == "none" ]] && continue

        color_cmd "$GREEN" ">>> Formatting $PART as $FS"
        case "$FS" in
            ext4) mkfs.ext4 -F "$PART" ;;
            btrfs) mkfs.btrfs -f "$PART" ;;
            xfs) mkfs.xfs -f "$PART" ;;
            f2fs) mkfs.f2fs -f "$PART" ;;
            fat32|vfat) mkfs.fat -F32 "$PART" ;;
            swap) mkswap "$PART"; swapon "$PART"; continue ;;
            *) die "$(color_cmd "$RED" "Unsupported filesystem: $FS")" ;;
        esac

        # Apply label if provided
        [[ -n "$LABEL" ]] && case "$FS" in
            ext4) e2label "$PART" "$LABEL" ;;
            btrfs) btrfs filesystem label "$PART" "$LABEL" ;;
            xfs) xfs_admin -L "$LABEL" "$PART" ;;
            f2fs) f2fslabel "$PART" "$LABEL" ;;
            fat32|vfat) fatlabel "$PART" "$LABEL" ;;
            swap) mkswap -L "$LABEL" "$PART" ;;
        esac

        # --- Mount ---
        case "$MOUNT" in
            "/") 
                if [[ "$FS" == "btrfs" ]]; then
                    mount "$PART" /mnt
                    mountpoint -q /mnt && btrfs subvolume create /mnt/@ || true
                    umount /mnt || true
                    mount -o subvol=@,compress=zstd "$PART" /mnt
                else
                    mount "$PART" /mnt || die "$(color_cmd "$RED" "Failed to mount root $PART on /mnt")"
                fi
                ;;
            /home) mkdir -p /mnt/home; mount "$PART" /mnt/home ;;
            /boot) mkdir -p /mnt/boot; mount "$PART" /mnt/boot ;;
            /efi|/boot/efi) mkdir -p /mnt/boot/efi; mount "$PART" /mnt/boot/efi ;;
            /data*)  # Auto-mount secondary disk partitions
                local DATA_DIR="/mnt${MOUNT}"
                mkdir -p "$DATA_DIR"
                mount "$PART" "$DATA_DIR" || die "$(color_cmd "$RED" "Failed to mount $PART on $DATA_DIR")"
                ;;
            *)  # Any other custom mountpoint
                mkdir -p "/mnt$MOUNT"
                mount "$PART" "/mnt$MOUNT"
                ;;
        esac
    done

    mountpoint -q /mnt || die "$(color_cmd "$RED" "Root (/) not mounted. Ensure you have a root partition.")"

    color_cmd "$GREEN" "✅ All custom partitions formatted and mounted correctly."

    color_cmd "$GREEN" "Generating /etc/fstab..."
    mkdir -p /mnt/etc
    genfstab -U /mnt >> /mnt/etc/fstab

    color_cmd "$CYAN" "→ /etc/fstab content:"
    cat /mnt/etc/fstab
}

#============================================================================================================================#
# ENSURE FS SUPPORT FOR CUSTOM PARTITION SCHEME (Robust for multiple disks / reserved partitions)
#============================================================================================================================#
ensure_fs_support_for_custom() {
    color_cmd "$GREEN" "→ Running ensure_fs_support_for_custom()"

    # Initialize FS detection flags
    local want_xfs=0 want_f2fs=0 want_btrfs=0 want_ext4=0

    # Detect requested FS types from PARTITIONS array
    if [[ ${#PARTITIONS[@]} -gt 0 ]]; then
        for entry in "${PARTITIONS[@]}"; do
            IFS=':' read -r PART MOUNT FS LABEL <<< "$entry"

            # Skip reserved partitions (e.g., BIOS boot, ESP, none)
            [[ "$FS" == "none" || "$LABEL" == "bios_grub" || "$MOUNT" == "/boot/efi" ]] && continue

            case "$FS" in
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
        color_cmd "$CYAN" "→ No special filesystem tools required for custom install."
        return 0
    fi

    color_cmd "$GREEN" "→ Installing filesystem tools into target: ${pkgs[*]}"
    arch-chroot /mnt pacman -Sy --noconfirm "${pkgs[@]}" || {
        color_cmd "$YELLOW" "⚠️ pacman install inside chroot failed once; retrying..."
        sleep 1
        arch-chroot /mnt pacman -Sy --noconfirm "${pkgs[@]}" || die "$(color_cmd "$RED" "Failed to install filesystem tools in target")"
    }
}

    # Patch mkinitcpio.conf inside target to ensure proper HOOKS and MODULES
    arch-chroot /mnt /bin/bash <<'CHROOT_EOF'
set -e
MKCONF="/etc/mkinitcpio.conf"

echo "→ (chroot) Patching ${MKCONF}..."

# Ensure HOOKS contains 'block' before 'filesystems'
if grep -q '^HOOKS=' "$MKCONF"; then
    current_hooks=$(sed -n 's/^HOOKS=(\(.*\))/\1/p' "$MKCONF" || echo "")
    base="base udev autodetect modconf block filesystems"
    for tok in $current_hooks; do
        if ! echo " $base " | grep -q " $tok "; then
            base="$base $tok"
        fi
    done
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

if grep -q '^MODULES=' "$MKCONF"; then
    existing=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "$MKCONF" || echo "")
    for m in "${desired_modules[@]}"; do
        if ! echo " $existing " | grep -q " $m "; then
            sed -i -E "s/^MODULES=\((.*)\)/MODULES=(\1 $m)/" "$MKCONF" || true
        fi
    done
else
    (( ${#desired_modules[@]} > 0 )) && echo "MODULES=(${desired_modules[*]})" >> "$MKCONF"
fi

# Remove fsck hook if no helpers are installed
has_fsck=0
command -v fsck.ext4 >/dev/null 2>&1 && has_fsck=1
command -v fsck.f2fs >/dev/null 2>&1 && has_fsck=1
command -v xfs_repair >/dev/null 2>&1 && has_fsck=1
(( has_fsck == 0 )) && sed -i '/fsck/d' "$MKCONF" || true

echo "→ (chroot) mkinitcpio.conf patch complete."
CHROOT_EOF

    echo "→ ensure_fs_support_for_custom() finished."
}
#=========================================================================================================================================#
# Multi-disk Custom Partition Flow
#=========================================================================================================================================#
custom_partition() {
# --- First disk ---
color_cmd "$CYAN" "=== Configuring first disk ==="
custom_partition_wizard

# --- Optional extra disks ---
color_cmd "$CYAN" "=== Optional extra disks ==="
create_more_disks

# --- Format & mount all partitions ---
color_cmd "$GREEN" "=== Formatting and mounting all partitions ==="
format_and_mount_custom

# --- Install base system ---
color_cmd "$GREEN" "=== Installing base system ==="
install_base_system

# --- Ensure filesystem tools inside target ---
color_cmd "$GREEN" "=== Installing necessary filesystem tools ==="
ensure_fs_support_for_custom

# --- Continue installation steps ---
color_cmd "$GREEN" "=== Configuring system ==="
configure_system

color_cmd "$GREEN" "=== Installing GRUB bootloader ==="
install_grub

color_cmd "$GREEN" "=== Selecting network mirror ==="
network_mirror_selection

color_cmd "$GREEN" "=== Installing GPU drivers ==="
gpu_driver

color_cmd "$GREEN" "=== Installing window manager ==="
window_manager

color_cmd "$GREEN" "=== Configuring display manager / login manager ==="
lm_dm

color_cmd "$GREEN" "=== Installing extra pacman packages ==="
extra_pacman_pkg

color_cmd "$GREEN" "=== Installing optional AUR packages ==="
optional_aur

color_cmd "$GREEN" "=== Running optional Hyprland setup ==="
hyprland_optional

color_cmd "$GREEN" "✅ Arch Linux installation complete."
}
#=========================================================================================================================================#
#=========================================================================================================================================#
#====================================== LUKS LVM // Choose Filesystem Custom #====================================================#
#=========================================================================================================================================#
#=========================================================================================================================================#
#=====================================================================
# Ensure system has support for LUKS + LVM (Option 3 only)
#=====================================================================
# ----------------------------
# ensure_fs_support_for_luks_lvm
# Patch: installs needed packages in the target and updates mkinitcpio
# arg1: enable_luks (0/1)
# ----------------------------
ensure_fs_support_for_luks_lvm() {
    color_cmd "$GREEN" "→ Running ensure_fs_support_for_luks_lvm() for post-install configuration."

    local enable_luks="${1:-0}"
    local want_xfs=0 want_f2fs=0 want_btrfs=0 want_ext4=0

    # Detect needed FS tools from LV_FSS global array if present
    if [[ ${#LV_FSS[@]} -gt 0 ]]; then
        for fs in "${LV_FSS[@]}"; do
            case "$fs" in
                xfs)   want_xfs=1 ;;
                f2fs)  want_f2fs=1 ;;
                btrfs) want_btrfs=1 ;;
                ext4)  want_ext4=1 ;;
                swap)  ;; # no package
            esac
        done
    else
        # Fallback: detect from mounted /mnt/etc/fstab if present
        if [[ -f /mnt/etc/fstab ]]; then
            while read -r _ _ fs _ _ _; do
                case "$fs" in
                    xfs)  want_xfs=1 ;;
                    f2fs) want_f2fs=1 ;;
                    btrfs)want_btrfs=1 ;;
                    ext4) want_ext4=1 ;;
                esac
            done < /mnt/etc/fstab
        fi
    fi

    local pkgs=()
    (( want_xfs ))  && pkgs+=(xfsprogs)
    (( want_f2fs )) && pkgs+=(f2fs-tools)
    (( want_btrfs ))&& pkgs+=(btrfs-progs)
    (( want_ext4 )) && pkgs+=(e2fsprogs)

    # Always include lvm2; cryptsetup only if enable_luks
    pkgs+=(lvm2)
    (( enable_luks )) && pkgs+=(cryptsetup)

    if (( ${#pkgs[@]} > 0 )); then
        color_cmd "$GREEN" "→ Installing packages inside target: ${pkgs[*]}"
        arch-chroot /mnt pacman -Syu --noconfirm "${pkgs[@]}" || die "$(color_cmd "$RED" "Failed to install tools in target.")"
    fi

    # Build HOOKS line deterministically depending on whether LUKS is used
    local HOOKS_LINE
    if [[ "$enable_luks" -eq 1 ]]; then
        color_cmd "$GREEN" "→ Setting mkinitcpio HOOKS for LUKS+LVM"
        HOOKS_LINE='HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)'
    else
        color_cmd "$GREEN" "→ Setting mkinitcpio HOOKS for LVM-only"
        HOOKS_LINE='HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)'
    fi
}

    # Replace HOOKS line inside chroot safely (create if missing)
    arch-chroot /mnt /bin/bash -e <<'CHROOT_EOF'
MKCONF=/etc/mkinitcpio.conf
HOOKS_LINE_PLACEHOLDER='__HOOKS_LINE_PLACEHOLDER__'
# placeholder will be replaced by outer shell
CHROOT_EOF

    # Use sed to replace HOOKS; use a temporary file if necessary
    arch-chroot /mnt bash -c "sed -i 's/^HOOKS=.*/${HOOKS_LINE}/' /etc/mkinitcpio.conf || echo '${HOOKS_LINE}' >> /etc/mkinitcpio.conf" || die "Failed to patch /etc/mkinitcpio.conf"

    echo "→ Regenerating initramfs inside target..."
    arch-chroot /mnt mkinitcpio -P || die "mkinitcpio regeneration failed"

    echo "→ ensure_fs_support_for_luks_lvm() finished."
}
# =====================================================================================================#
# === LUKS LVM Master Installation Flow (Call this from menu option 3) ===
# =====================================================================================================#

# ----------------------------
# master flow for option 3 (interactive multiple disks)
# ----------------------------
luks_lvm_master_flow() {
    # --- First disk ---
    color_cmd "$CYAN" "=== Configuring first disk for LUKS/LVM ==="
    luks_lvm_route || die "$(color_cmd "$RED" "First luks_lvm_route failed")"

    # --- Optional additional disks ---
    while true; do
        read -rp "$(color_cmd "$CYAN" "Do you want to edit another disk for LUKS/LVM? [Y/n]: ")" ans
        ans="${ans:-n}"
        case "$ans" in
            [Yy])
                color_cmd "$CYAN" "→ Editing another disk for LUKS/LVM..."
                luks_lvm_route || die "$(color_cmd "$RED" "luks_lvm_route failed for another disk")"
                ;;
            [Nn]) 
                color_cmd "$CYAN" "→ No more LUKS/LVM disks to configure. Continuing..."
                break
                ;;
            *)
                color_cmd "$YELLOW" "Please answer Y or n."
                ;;
        esac
    done

    # --- Post-install steps ---
    color_cmd "$GREEN" "=== Running LUKS/LVM post-install steps ==="
    luks_lvm_post_install_steps
}

wait_for_lv() {
    local dev="$1"
    local timeout=10
    color_cmd "$CYAN" "→ Waiting for logical volume $dev to appear (timeout: $timeout s)..."
    for ((i=0;i<timeout;i++)); do
        [[ -b "$dev" ]] && { color_cmd "$GREEN" "→ Device $dev is ready."; return 0; }
        sleep 0.5
        udevadm settle --timeout=2
    done
    color_cmd "$RED" "⚠️ Device $dev did not appear within $timeout seconds."
    return 1
}
#=====================================================================================================================================#
# LUKS LV
#=====================================================================================================================================#
# -------------------------------------------------------------------------
# Option 3: LUKS + LVM guided route
# -------------------------------------------------------------------------
# ----------------------------
# luks_lvm_route
# Interactive, safe LUKS+LVM partitioning for a single disk
# - supports BIOS and UEFI
# - creates ESP (UEFI) or bios_grub + /boot (BIOS)
# - optional LUKS on the large partition, optional LVM inside
# - robust re-prompting for user input
# ----------------------------
luks_lvm_route() {
    detect_boot_mode

    color_cmd "$CYAN" "Available block devices (disks):"
    lsblk -d -o NAME,SIZE,MODEL,TYPE

    # ---------------- Helper prompts ----------------
    ask_disk() {
        while true; do
            read -rp "$(color_cmd "$CYAN" "Enter target disk (example /dev/sda or nvme0n1): ")" _d
            _d="/dev/${_d##*/}"
            [[ -b "$_d" ]] && { DEV="$_d"; return 0; }
            color_cmd "$YELLOW" "Invalid block device: '$_d'. Try again."
        done
    }

    ask_yesno_default() {
        local prompt="$1"
        local def="${2:-N}"
        local ans
        while true; do
            read -rp "$(color_cmd "$CYAN" "$prompt ")" ans
            ans="${ans:-$def}"
            ans_upper=$(echo "$ans" | tr '[:lower:]' '[:upper:]')
            case "$ans_upper" in
                Y|YES) return 0 ;;
                N|NO)  return 1 ;;
                *) color_cmd "$YELLOW" "Please answer Y or N." ;;
            esac
        done
    }

    ask_nonempty() {
        local prompt="$1" val
        while true; do
            read -rp "$(color_cmd "$CYAN" "$prompt ")" val
            [[ -n "$val" ]] && { REPLY="$val"; return 0; }
            color_cmd "$YELLOW" "Cannot be empty."
        done
    }

    ask_lv_size() {
        local prompt="${1:-Size (40G, 512M, 10%VG, 100%FREE) [100%FREE]: }" ans
        while true; do
            read -rp "$(color_cmd "$CYAN" "$prompt ")" ans
            ans="${ans:-100%FREE}"
            if [[ "$ans" =~ ^([0-9]+G|[0-9]+M|[0-9]+%VG|[0-9]+%FREE|100%FREE)$ ]]; then
                REPLY="$ans"
                return 0
            fi
            if [[ "$ans" =~ ^[0-9]+$ ]]; then
                REPLY="${ans}G"; return 0
            fi
            color_cmd "$YELLOW" "Invalid LVM size format."
        done
    }

    ask_mountpoint() {
        local prompt="${1:-Mountpoint (/, /home, swap, /data, none): }" ans
        while true; do
            read -rp "$(color_cmd "$CYAN" "$prompt ")" ans
            ans="${ans:-none}"
            case "$ans" in
                /|/home|/boot|/efi|/boot/efi|swap|none|/data*|/srv|/opt) REPLY="$ans"; return 0 ;;
                *) color_cmd "$YELLOW" "Invalid mountpoint. Allowed: / /home /boot /efi /boot/efi swap none /dataX /srv /opt" ;;
            esac
        done
    }

    ask_fs() {
        local prompt="${1:-Filesystem (ext4,btrfs,xfs,f2fs) [ext4]: }" ans
        while true; do
            read -rp "$(color_cmd "$CYAN" "$prompt ")" ans
            ans="${ans:-ext4}"
            case "$ans" in
                ext4|btrfs|xfs|f2fs) REPLY="$ans"; return 0 ;;
                *) color_cmd "$YELLOW" "Invalid fs. Choose ext4,btrfs,xfs,f2fs" ;;
            esac
        done
    }

    # ---------------- Start main flow ----------------
    ask_disk
    color_cmd "$RED" "WARNING: This will ERASE ALL DATA on $DEV"
    ask_yesno_default "Continue? [y/N]:" "N" || { color_cmd "$YELLOW" "Aborted by user."; return 1; }

    # Verify system tools
    for cmd in parted blkid cryptsetup pvcreate vgcreate lvcreate vgchange lvdisplay mkfs.ext4 mkfs.fat; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            color_cmd "$RED" "ERROR: $cmd not found. Install lvm2, cryptsetup, parted."
            return 1
        fi
    done

    safe_disk_cleanup
    ps=$(part_suffix "$DEV")

    color_cmd "$CYAN" "→ Writing GPT to $DEV"
    parted -s "$DEV" mklabel gpt || die "$(color_cmd "$RED" "mklabel failed")"

    PART_BOOT=""   
    PART_LUKS=""   
    PART_GRUB_BIOS=""

    if [[ "$MODE" == "UEFI" ]]; then
        color_cmd "$CYAN" "→ MODE=UEFI: creating ESP and main partition"
        parted -s "$DEV" unit MiB mkpart primary fat32 1MiB 1025MiB || die "mkpart ESP failed"
        parted -s "$DEV" set 1 esp on || die "set esp failed"
        PART_BOOT="${DEV}${ps}1"
        parted -s "$DEV" unit MiB mkpart primary 1026MiB 100% || die "mkpart main failed"
        PART_LUKS="${DEV}${ps}2"

        partprobe "$DEV"; udevadm settle --timeout=5
        mkfs.fat -F32 "$PART_BOOT" || die "mkfs.fat failed on $PART_BOOT"
    else
        color_cmd "$CYAN" "→ MODE=BIOS: creating BIOS/boot and main partition"
        parted -s "$DEV" unit MiB mkpart primary 1MiB 2MiB || die "mkpart bios_grub failed"
        parted -s "$DEV" set 1 bios_grub on || die "set bios_grub failed"
        PART_GRUB_BIOS="${DEV}${ps}1"

        parted -s "$DEV" unit MiB mkpart primary 2MiB 514MiB || die "mkpart /boot failed"
        PART_BOOT="${DEV}${ps}2"

        parted -s "$DEV" unit MiB mkpart primary 515MiB 100% || die "mkpart main failed"
        PART_LUKS="${DEV}${ps}3"

        partprobe "$DEV"; udevadm settle --timeout=5
        mkfs.ext4 -F "$PART_BOOT" || die "mkfs.ext4 failed on $PART_BOOT"
    fi

    [[ -b "$PART_LUKS" ]] || die "Partition $PART_LUKS missing."

    # ---------------- LUKS encryption ----------------
    if ask_yesno_default "Encrypt main partition ($PART_LUKS) with LUKS2? [Y/n]:" "Y"; then
        ENCRYPTION_ENABLED=1
        cryptsetup luksFormat --type luks2 "$PART_LUKS" || die "luksFormat failed"

        while true; do
            read -rp "$(color_cmd "$CYAN" "Name for mapped device (default cryptlvm): ")" cryptname
            cryptname="${cryptname:-cryptlvm}"
            [[ -e "/dev/mapper/$cryptname" ]] && { color_cmd "$YELLOW" "$cryptname exists — choose another"; continue; }
            break
        done

        LUKS_MAPPER_NAME="$cryptname"
        cryptsetup open "$PART_LUKS" "$LUKS_MAPPER_NAME" || die "cryptsetup open failed"
        BASE_DEVICE="/dev/mapper/${LUKS_MAPPER_NAME}"
        LUKS_PART_UUID=$(blkid -s UUID -o value "$PART_LUKS" || true)
    else
        ENCRYPTION_ENABLED=0
        BASE_DEVICE="$PART_LUKS"
    fi

    color_cmd "$CYAN" "→ Creating PV on $BASE_DEVICE"
    pvcreate "$BASE_DEVICE" || die "pvcreate failed"

    # ---------------- VG creation ----------------
    while true; do
        read -rp "$(color_cmd "$CYAN" "Volume Group name (default vg0): ")" VGNAME
        VGNAME="${VGNAME:-vg0}"
        [[ "$VGNAME" =~ ^[a-zA-Z0-9._-]+$ ]] && break
        color_cmd "$YELLOW" "Invalid VG name."
    done

    if vgdisplay "$VGNAME" >/dev/null 2>&1; then
        if ask_yesno_default "VG $VGNAME exists — add PV? [Y/n]:" "Y"; then
            vgextend "$VGNAME" "$BASE_DEVICE" || die "vgextend failed"
        else
            while true; do
                read -rp "$(color_cmd "$CYAN" "New VG name: ")" VGNAME
                VGNAME="${VGNAME:-vg0}"
                [[ "$VGNAME" =~ ^[a-zA-Z0-9._-]+$ ]] && break
                color_cmd "$YELLOW" "Invalid VG name."
            done
            vgcreate "$VGNAME" "$BASE_DEVICE" || die "vgcreate failed"
        fi
    else
        vgcreate "$VGNAME" "$BASE_DEVICE" || die "vgcreate failed"
    fi

    vgscan --mknodes
    vgchange -ay "$VGNAME" || die "vgchange -ay failed"

    color_cmd "$GREEN" "→ Completed LUKS+LVM route for $DEV"
    return 0
}

# ----------------------------
# luks_lvm_post_install_steps
# Consumes the globals exported by luks_lvm_route()
# - mounts boot/EFI (if not yet)
# - writes /etc/crypttab, does pacstrap/install_base_system, genfstab
# - applies ensure_fs_support_for_luks_lvm and regenerates initramfs
# - installs GRUB
# ----------------------------
luks_lvm_post_install_steps() {
    color_cmd "$CYAN" echo "→ Running LUKS+LVM post-install steps..."

    # --- Mount boot/EFI partition ---
    if [[ "$MODE" == "UEFI" && -n "$PART_BOOT" ]]; then
        mkdir -p /mnt/boot/efi
        mount "$PART_BOOT" /mnt/boot/efi || die "Failed to mount $PART_BOOT on /mnt/boot/efi"
        color_cmd "$GREEN" echo "→ Mounted ESP at /mnt/boot/efi"
    elif [[ "$MODE" == "BIOS" && -n "$PART_BOOT" ]]; then
        mkdir -p /mnt/boot
        mount "$PART_BOOT" /mnt/boot || die "Failed to mount $PART_BOOT on /mnt/boot"
        color_cmd "$GREEN" echo "→ Mounted /boot at $PART_BOOT"
    fi

    # --- Write crypttab if LUKS enabled ---
    if [[ "${ENCRYPTION_ENABLED:-0}" -eq 1 && -n "${LUKS_PART_UUID:-}" && -n "${LUKS_MAPPER_NAME:-}" ]]; then
        mkdir -p /mnt/etc
        echo "${LUKS_MAPPER_NAME} UUID=${LUKS_PART_UUID} none luks" > /mnt/etc/crypttab
        color_cmd "$GREEN" echo "→ Wrote /mnt/etc/crypttab for LUKS device ${LUKS_MAPPER_NAME}"
    else
        color_cmd "$YELLOW" echo "→ No LUKS encryption configured; skipping crypttab"
    fi

    # --- Install base system ---
    color_cmd "$CYAN" echo "→ Installing base system..."
    install_base_system || die "install_base_system failed"
    color_cmd "$GREEN" echo "→ Base system installed successfully"

    # --- Generate /etc/fstab ---
    color_cmd "$CYAN" echo "→ Generating /mnt/etc/fstab..."
    genfstab -U /mnt > /mnt/etc/fstab || die "genfstab failed"
    color_cmd "$GREEN" echo "→ /mnt/etc/fstab generated:"
    sed -n '1,200p' /mnt/etc/fstab

    # --- Ensure filesystem tools and mkinitcpio hooks ---
    color_cmd "$CYAN" echo "→ Ensuring FS tools and mkinitcpio hooks..."
    ensure_fs_support_for_luks_lvm "${ENCRYPTION_ENABLED:-0}" || die "ensure_fs_support_for_luks_lvm failed"
    color_cmd "$GREEN" echo "→ Filesystem tools and hooks installed"

    # --- Chroot-level configuration ---
    color_cmd "$CYAN" echo "→ Configuring system in chroot..."
    configure_system || die "configure_system failed"
    color_cmd "$GREEN" echo "→ System configuration completed"

    # --- Install GRUB ---
    color_cmd "$CYAN" echo "→ Installing GRUB bootloader..."
    install_grub || die "install_grub failed"
    color_cmd "$GREEN" echo "→ GRUB installed successfully"

    # --- Optional post-install packages ---
    color_cmd "$CYAN" echo "→ Installing additional packages..."
    network_mirror_selection
    gpu_driver
    window_manager
    lm_dm
    extra_pacman_pkg
    optional_aur
    hyprland_optional
    color_cmd "$GREEN" echo "→ Additional packages installed"

    color_cmd "$CYAN" echo "→ LUKS+LVM post-install steps completed."
}
#=========================================================================================================================================#
# Main menu
#=========================================================================================================================================#
menu() {
clear
logo
            echo -e "${CYAN}#==================================================#${RESET}"
            echo -e "${CYAN}#     Select partitioning method for $DEV:         #${RESET}"
            echo -e "${CYAN}#==================================================#${RESET}"
            echo -e "${CYAN}|-1) Quick Partitioning  (automated, ext4, btrfs)  |${RESET}"
            echo -e "${CYAN}|--------------------------------------------------|${RESET}"
            echo -e "${CYAN}|-2) Custom Partitioning (FS:ext4,btrfs,f2fs,xfs)  |${RESET}"
            echo -e "${CYAN}|--------------------------------------------------|${RESET}"
            echo -e "${CYAN}|-3) Lvm & Luks Partitioning                       |${RESET}"
            echo -e "${CYAN}|--------------------------------------------------|${RESET}"
            echo -e "${CYAN}|-4) Return back to start                          |${RESET}"
            echo -e "${CYAN}#==================================================#${RESET}"
            read -rp "Enter choice [1-3]: " INSTALL_MODE
            case "$INSTALL_MODE" in
                1) quick_partition ;;
                2) custom_partition ;;
                3) luks_lvm_master_flow ;;
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
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo -e "${CYAN}# 11 Cleanup postinstall script & Final Messages & Instructions                                     #${RESET}"
echo -e "${CYAN}#===================================================================================================#${RESET}"
echo
echo 
echo -e "${GREEN}Custom package installation phase complete.${RESET}"
echo -e "${GREEN}You can later add more software manually or extend these lists:${RESET}"
echo -e "${GREEN}  - EXTRA_PKGS[] for pacman packages${RESET}"
echo -e "${GREEN}  - AUR_PKGS[] for AUR software${RESET}"
echo -e "${GREEN} ----------------------------------------------------------------------------------------------------${RESET}"
echo -e "${GREEN}You can now unmount and reboot:${RESET}"
echo -e "${GREEN}  umount -R /mnt${RESET}"
echo -e "${GREEN}  swapoff ${P_SWAP} || true${RESET}" # Changed from P3 to P_SWAP for consistency
echo -e "${GREEN}  reboot${RESET}"
#Cleanup postinstall script
rm -f /mnt/root/postinstall.sh
#Final messages & instructions
echo
echo -e "${GREEN}Installation base and basic configuration finished.${RESET}"
echo -e "${GREEN}To reboot into your new system:${RESET}"
echo -e "${GREEN}  umount -R /mnt${RESET}"
echo -e "${GREEN}  swapoff ${P_SWAP} || true${RESET}" # Changed from P3 to P_SWAP for consistency
echo -e "${GREEN}  reboot${RESET}"
echo
echo -e "${GREEN}Done.${RESET}"
echo -e "${CYAN}#===========================================================================#${RESET}"
echo -e "${CYAN}# -GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88             #${RESET}"
echo -e "${CYAN}# -Author  : Terra88                                                        #${RESET}"
echo -e "${CYAN}# -GitHub  : http://github.com/Terra88                                      #${RESET}"
echo -e "${CYAN}#===========================================================================#${RESET}"
