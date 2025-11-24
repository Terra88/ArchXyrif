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
# -
#=========================================================================================================================================#
# Preparation
#=========================================================================================================================================#
# Arch logo: Edited manually by Terra88
#=========================================================================================================================================#
logo(){
echo -e "#===================================================================================================#"
echo -e "| The Great Monolith of Installing Arch Linux!                                                      |"
echo -e "#===================================================================================================#"
echo -e "|                                                                                                   |"
echo -e "|        d8888                 888      Y88b   d88P                  d8b  .d888                     |"
echo -e "|       d88888                 888       Y88b d88P                   Y8P d88P                       |"
echo -e "|      d88P888                 888        Y88o88P                        888                        |"
echo -e "|     d88P 888 888d888 .d8888b 88888b.     Y888P    888  888 888d888 888 888888                     |"
echo -e "|    d88P  888 888P.  d88P.    888 .88b    d888b    888  888 888P.   888 888                        |"
echo -e "|   d88P   888 888    888      888  888   d88888b   888  888 888     888 888                        |"
echo -e "|  d8888888888 888    Y88b.    888  888  d88P Y88b  Y88b 888 888     888 888                        |"
echo -e "| d88P     888 888     .Y8888P 888  888 d88P   Y88b  .Y88888 888     888 888                        |"
echo -e "|                                                        888                                        |"
echo -e "|                                                  Y8b d88P                                         |"
echo -e "|                                                     Y88P                                          |"
echo -e "|         Semi-Automated / Interactive - Arch Linux Installer                                       |"
echo -e "|                                                                                                   |"
echo -e "|        GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88(Tero.H)                       |"
echo -e "#===================================================================================================#"
echo -e "|-Table of Contents:                |-0) Disk Format INFO                                           |"
echo -e "#===================================================================================================#"
echo -e "|-1)Disk Selection & Format         |- UEFI & BIOS(LEGACY) SUPPORT                                  |"
echo -e "|-2)Pacstrap:Installing Base system |- wipes old signatures                                         |"
echo -e "|-3)Generating fstab                |- Partitions: BOOT/EFI(1024MiB)(/ROOT)(/HOME)(SWAP)            |"
echo -e "|-4)Setting Basic variables         |- 1) Quick Partition: Root/Home & Swap on or off options       |"
echo -e "|-5)Installing GRUB for UEFI        |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |" 
echo -e "|-6)Setting configs/enabling.srv    |- Filesystems: FAT32 on Boot/EFI, EXT4 or BTRFS                |"
echo -e "|-7)Setting Pacman Mirror           |- 2) Custom Partition/Format Route for ext4,btrfs,xfs,f2fs     |"
echo -e "|-Optional:                         |- 3) LV & LUKS Coming soon.                                    |"
echo -e "|-8A)GPU-Guided install             |---------------------------------------------------------------|"
echo -e "|-8B)Guided Window Manager Install  |# Author  : Terra88(Tero.H)                                    |"
echo -e "|-8C)Guided Login Manager Install   |# Purpose : Arch Linux custom installer                        |"
echo -e "|-9)Extra Pacman & AUR PKG Install  |# GitHub  : http://github.com/Terra88                          |"
echo -e "|-If Hyprland Selected As WM        | ↜(╰ •ω•)╯ψ ↑_(ΦωΦ;)Ψ ୧( ಠ┏ل͜┓ಠ )୨ (ʘдʘ╬) ( •̀ᴗ•́ )و   (◣◢)ψ     |"
echo -e "|-10)Optional Theme install         | (づ｡◕‿‿◕｡)づ ◥(ฅº￦ºฅ)◤ (㇏(•̀ᵥᵥ•́)ノ) ＼(◑д◐)＞∠(◑д◐)          |"
echo -e "#===================================================================================================#"
}
#=========================================================================================================================================#
#!/usr/bin/env bash
loadkeys fi
timedatectl set-ntp true
set -euo pipefail
#=========================================================================================================================================#
# GLOBAL VARIABLES:
#=========================================================================================================================================#
#-------------------MAPPER---------------------#
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
P_BIOS_GRUB=""
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
#==========LANGLOCALHELPER============#
# 1. Helper to check if a file/path exists (Used for Timezone)
check_file_exists() {
    local mounted_path="/mnt$1"
    local live_path="$1"
    local config_name="$2"
    
    if [ -e "$mounted_path" ]; then
        return 0
    fi
    
    if [ -e "$live_path" ]; then
        return 0
    fi

    echo "Error: '${config_name}' is not a recognized configuration value." >&2
    echo "The required file/directory was not found at: ${mounted_path} (target) or ${live_path} (live)." >&2
    return 1
}

# 2. Helper to check locale existence in locale.gen
check_locale_exists() {
    local locale_string="$1"
    local config_file="/etc/locale.gen"
    local mounted_file="/mnt${config_file}"
    local file_to_check=""

    if [ -e "$mounted_file" ]; then
        file_to_check="$mounted_file"
    elif [ -e "$config_file" ]; then
        file_to_check="$config_file"
    else
        echo "Error: Cannot find locale.gen file." >&2
        return 1
    fi

    if grep -qE "^#?${locale_string}[[:space:]]+UTF-8" "$file_to_check"; then
        return 0
    else
        echo "Error: Locale '${locale_string}' not found in ${file_to_check}." >&2
        return 1
    fi
}

# 3. NEW HELPER: Check for keymap RECURSIVELY using 'find'
# This fixes the issue where 'fi' is hidden in subfolders, but rejects 'george'.
check_keymap_exists() {
    local keymap_name="$1"
    # Standard location for keymaps
    local search_paths=("/usr/share/kbd/keymaps" "/mnt/usr/share/kbd/keymaps")
    
    for search_dir in "${search_paths[@]}"; do
        if [ -d "$search_dir" ]; then
            # Look for exactly "keymapname.map.gz" anywhere under this folder
            if find "$search_dir" -name "${keymap_name}.map.gz" -print -quit | grep -q .; then
                return 0
            fi
        fi
    done

    echo "Error: Keymap '${keymap_name}' (file '${keymap_name}.map.gz') not found in system keymaps." >&2
    return 1
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
    echo -e "#===================================================================================================#"
    echo -e "# - PRE-CLEANUP: Unmounting old partitions, subvolumes, LUKS and LVM from $DEV                      #"
    echo -e "#===================================================================================================#"

    # 1) Protect the live ISO device
    local iso_dev
    iso_dev=$(findmnt -no SOURCE / 2>/dev/null || true)
    if [[ "$iso_dev" == "$DEV"* ]]; then
        echo "❌ This disk is being used as the live ISO source. Aborting."
        return 1
    fi

    # 2) Unmount all partitions of $DEV (not anything else!)
    echo "→ Unmounting mounted partitions of $DEV..."
    for p in $(lsblk -ln -o NAME,MOUNTPOINT "$DEV" | awk '$2!=""{print $1}' | tac); do
        local part="/dev/$p"
        if mountpoint -q "/dev/$p" 2>/dev/null || grep -q "^$part" /proc/mounts; then
            umount -R "$part" 2>/dev/null && echo "  Unmounted $part"
        fi
    done
    swapoff "${DEV}"* 2>/dev/null || true

    # 3) Deactivate LVMs on this disk
    echo "→ Deactivating LVM volumes related to $DEV ..."
    vgchange -an || true
    for lv in $(lsblk -rno NAME "$DEV" | grep -E '^.*--.*$' || true); do
        dmsetup remove "/dev/mapper/$lv" 2>/dev/null || true
    done

    # 4) Close any LUKS mappings that belong to this disk
    echo "→ Closing any LUKS mappings..."
    for map in $(lsblk -rno NAME,TYPE | awk '$2=="crypt"{print $1}'); do
        local backing
        backing=$(cryptsetup status "$map" 2>/dev/null | awk -F': ' '/device:/{print $2}')
        [[ "$backing" == "$DEV"* ]] && cryptsetup close "$map" && echo "  Closed $map"
    done

    echo "→ Removing stray device-mapper entries ..."
    dmsetup remove_all 2>/dev/null || true
    
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
#=========================================================================#
# Detect boot mode
#=========================================================================#
detect_boot_mode() {
    if [[ -d /sys/firmware/efi ]]; then
        MODE="UEFI"
        BIOS_BOOT_PART_CREATED=false
        BOOT_SIZE_MIB=$EFI_SIZE_MIB
        echo -e "${CYAN}UEFI detected.${RESET}"
    else
        MODE="BIOS"
        BIOS_BOOT_PART_CREATED=false
        BOOT_SIZE_MIB=$BOOT_SIZE_MIB
        echo -e "${CYAN}Legacy BIOS detected.${RESET}"
    fi
}
#=========================================================================================================================================#
# Install base system
#=========================================================================================================================================#
install_base_system() {

sleep 1
clear
echo -e "#===================================================================================================#"
echo -e "# - Installing base system - Pacstrap!                                                              #"
echo -e "#===================================================================================================#"
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
pacstrap /mnt "${PKGS[@]}"
}
#=========================================================================================================================================#
# Configure system
#=========================================================================================================================================#
configure_system() {
sleep 1
clear
echo -e "#===================================================================================================#"
echo -e "# - Setting Basic variables for chroot (defaults provided)                                      #"
echo -e "#===================================================================================================#"
echo
# -------------------------------
# Prompt for timezone, locale, hostname, and username
# -------------------------------
DEFAULT_TZ="Europe/Helsinki"

# Start the validation loop for Timezone
while true; do
    clear
    echo "#===================================================#"
    echo "#-Select a Time Zone Region:                         #"
    echo "#===================================================#"
    echo "1) 🇺🇸 USA (e.g., America/New_York, America/Los_Angeles)"
    echo "2) 🇪🇺 Europe (e.g., Europe/London, Europe/Berlin)"
    echo "3) 🌍 Africa (e.g., Africa/Cairo, Africa/Lagos)"
    echo "4) Other / Enter Custom Time Zone (e.g., Asia/Tokyo)"
    echo "5) Use Default: ${DEFAULT_TZ} 🇫🇮(Europe/Helsinki)"

    read -r -p "Enter choice [5]: " TZ_CHOICE
    TZ_CHOICE="${TZ_CHOICE:-5}"

    case $TZ_CHOICE in
        1) read -r -p "Enter specific USA Time Zone (e.g., America/New_York) [${DEFAULT_TZ}]: " TZ_INPUT; TZ="${TZ_INPUT:-$DEFAULT_TZ}" ;;
        2) read -r -p "Enter specific Europe Time Zone (e.g., Europe/London) [${DEFAULT_TZ}]: " TZ_INPUT; TZ="${TZ_INPUT:-$DEFAULT_TZ}" ;;
        3) read -r -p "Enter specific Africa Time Zone (e.g., Africa/Cairo) [${DEFAULT_TZ}]: " TZ_INPUT; TZ="${TZ_INPUT:-$DEFAULT_TZ}" ;;
        4) read -r -p "Enter custom Time Zone (e.g., Asia/Tokyo) [${DEFAULT_TZ}]: " TZ_INPUT; TZ="${TZ_INPUT:-$DEFAULT_TZ}" ;;
        5|*) TZ="${DEFAULT_TZ}"; echo "Using default Time Zone: ${TZ}" ;;
    esac

    if check_file_exists "/usr/share/zoneinfo/${TZ}" "Time Zone (${TZ})"; then
        echo "✅ Time Zone set to: ${TZ}"
        break
    else
        echo "⚠️ Invalid Time Zone entered. Please try again."
        sleep 2
    fi
done

DEFAULT_LOCALE="fi_FI.UTF-8"
# Start validation loop for Locale
while true; do
    clear
    echo "#===================================================#"
    echo "#-Select a System Locale (LANG):                     #"
    echo "#===================================================#"
    echo "1) 🇺🇸 English (US) - en_US.UTF-8"
    echo "2) 🇬🇧 English (UK) - en_GB.UTF-8"
    echo "3) 🇫🇷 French (France) - fr_FR.UTF-8"
    echo "4) 🇩🇪 German (Germany) - de_DE.UTF-8"
    echo "5) Default 🇫🇮(Finland): ${DEFAULT_LOCALE}"
    echo "6) Custom Locale (e.g., ja_JP.UTF-8, pt_BR.UTF-8)"

    read -r -p "Enter choice [5]: " LOCALE_CHOICE
    LOCALE_CHOICE="${LOCALE_CHOICE:-5}"

    case $LOCALE_CHOICE in
        1) LANG_LOCALE="en_US.UTF-8" ;;
        2) LANG_LOCALE="en_GB.UTF-8" ;;
        3) LANG_LOCALE="fr_FR.UTF-8" ;;
        4) LANG_LOCALE="de_DE.UTF-8" ;;
        6) read -r -p "Enter custom Locale (e.g., ja_JP.UTF-8) [${DEFAULT_LOCALE}]: " LOCALE_INPUT; LANG_LOCALE="${LOCALE_INPUT:-$DEFAULT_LOCALE}" ;;
        5|*) LANG_LOCALE="${DEFAULT_LOCALE}" ;;
    esac
    
    if check_locale_exists "${LANG_LOCALE}"; then
        echo "✅ LANG set to: ${LANG_LOCALE}"
        break
    else
        LOCALE_CHOICE=""
        sleep 2
        continue
    fi
done
echo "Set LANG to: ${LANG_LOCALE}"

DEFAULT_KEYMAP="fi"
# Start validation loop for Keymap (RESTORED AND FIXED)
while true; do
    clear
    echo "#===================================================#"
    echo "#-Select a Keyboard Keymap:                          #"
    echo "#===================================================#"
    echo "1) 🇺🇸 US (standard QWERTY)"
    echo "2) 🇬🇧 UK"
    echo "3) 🇫🇷 FR (AZERTY)"
    echo "4) 🇩🇪 DE"
    echo "5) Default 🇫🇮(Finnish): ${DEFAULT_KEYMAP} (Finnish)"
    echo "6) Custom Keymap (e.g., dvorak, se, es)"

    read -r -p "Enter choice [5]: " KEYMAP_CHOICE
    KEYMAP_CHOICE="${KEYMAP_CHOICE:-5}"

    case $KEYMAP_CHOICE in
        1) KEYMAP="us" ;;
        2) KEYMAP="uk" ;;
        3) KEYMAP="fr" ;;
        4) KEYMAP="de" ;;
        6)
            read -r -p "Enter custom Keymap (e.g., dvorak, se) [${DEFAULT_KEYMAP}]: " KEYMAP_INPUT
            KEYMAP="${KEYMAP_INPUT:-$DEFAULT_KEYMAP}"
            ;;
        5|*) KEYMAP="${DEFAULT_KEYMAP}" ;;
    esac

    # 1. Normalize to lowercase (e.g., FI -> fi)
    KEYMAP=$(echo "$KEYMAP" | tr '[:upper:]' '[:lower:]')

    # 2. Validate using the recursive finder
    # This will accept 'fi' (found in i386/qwerty/) but reject 'george'
    if check_keymap_exists "${KEYMAP}"; then
        echo "✅ Keymap set to: ${KEYMAP}"
        break
    else
        echo "⚠️ Invalid Keymap '${KEYMAP}' (File not found). Please try again."
        sleep 2
        KEYMAP_CHOICE=""
    fi
done
echo "Set KEYMAP to: ${KEYMAP}"

DEFAULT_HOSTNAME="archbox"
echo "#===================================================#"
echo "#-Input Hostname(ComputerName):                      #"
echo "#===================================================#"
read -r -p "Enter hostname [${DEFAULT_HOSTNAME}]: " HOSTNAME
HOSTNAME="${HOSTNAME:-$DEFAULT_HOSTNAME}"

DEFAULT_USER="user"
echo "#===================================================#"
echo "#-Input Username:                                   #"
echo "#===================================================#"
read -r -p "Enter username to create [${DEFAULT_USER}]: " NEWUSER
NEWUSER="${NEWUSER:-$DEFAULT_USER}"

# -------------------------------
# Create postinstall.sh inside chroot
# -------------------------------
cat > /mnt/root/postinstall.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# --- New Trap Function for Better Error Messages ---
error_handler() {
    local exit_code="$?"
    local command="${BASH_COMMAND}"
    if [ "$exit_code" != "0" ]; then
        echo "❌ FATAL CONFIGURATION ERROR!" >&2
        echo "The script halted with exit code $exit_code on command:" >&2
        echo "--> $command" >&2
        echo "" >&2
        echo "Please verify the values injected into postinstall.sh (TZ, LANG_LOCALE, KEYMAP, etc.)" >&2
        sleep 5
    fi
}
trap error_handler EXIT

# Variables
TZ="{{TIMEZONE}}"
LANG_LOCALE="{{LANG_LOCALE}}"
KEYMAP="{{KEYMAP}}"
HOSTNAME="{{HOSTNAME}}"
NEWUSER="{{NEWUSER}}"

# 1) Timezone
ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
hwclock --systohc

# 2) Locale
if grep -qE "^#?${LANG_LOCALE}[[:space:]]+UTF-8" /etc/locale.gen; then
    sed -i "s/^#\(${LANG_LOCALE} UTF-8\)/\1/" /etc/locale.gen
else
    echo "${LANG_LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LANG_LOCALE}" > /etc/locale.conf
export LANG="${LANG_LOCALE}"
export LC_ALL="${LANG_LOCALE}"

# 3) Hostname
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1       localhost
::1             localhost
127.0.1.1       ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# 4) Keymap
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "FONT=lat9w-16" >> /etc/vconsole.conf
localectl set-keymap ${KEYMAP}

# 5) Initramfs
mkinitcpio -P

# 6) Users & Passwords
: "${NEWUSER:?NEWUSER is not set}"
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

useradd -m -G wheel -s /bin/bash "${NEWUSER}" || true
set_password_interactive "${NEWUSER}"
set_password_interactive "root"

# 7) Sudoers
echo "${NEWUSER} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${NEWUSER}
chmod 440 /etc/sudoers.d/${NEWUSER}
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 8) Home
HOME_DIR="/home/$NEWUSER"
mkdir -p "$HOME_DIR/.config"
chown -R "$NEWUSER:$NEWUSER" "$HOME_DIR"

# 9) Services
systemctl enable NetworkManager
systemctl enable sshd
loginctl enable-linger "${NEWUSER}"

echo "Postinstall inside chroot finished."
EOF

# -------------------------------
# Inject values
# -------------------------------
sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
sed -i "s|{{KEYMAP}}|${KEYMAP}|g" /mnt/root/postinstall.sh
sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh

# -------------------------------
# Execute Chroot
# -------------------------------
chmod +x /mnt/root/postinstall.sh
arch-chroot /mnt /root/postinstall.sh
rm -f /mnt/root/postinstall.sh
echo "✅ System configured."
}
#=========================================================================================================================================#
# GRUB installation
#=========================================================================================================================================#
install_grub() {

    detect_boot_mode

    echo "🛈 Installing Bootloader (GRUB)..."

    # -----------------------------------------------------------------------------------
    # SMART DISK SELECTION
    # -----------------------------------------------------------------------------------

    local TARGET_DISK="${BOOT_LOADER_DISK:-$DEV}"
    [[ -z "$TARGET_DISK" ]] && die "install_grub: No target disk defined."

    echo "→ Target Disk: $TARGET_DISK"

    # -----------------------------------------------------------------------------------
    # 1. Enable Cryptodisk BEFORE grub-install
    # -----------------------------------------------------------------------------------

    if [[ "$ENCRYPTION_ENABLED" -eq 1 ]]; then

        echo "→ Enabling GRUB cryptodisk support..."

        arch-chroot /mnt bash -c "
            sed -i '/^GRUB_ENABLE_CRYPTODISK/d' /etc/default/grub
            echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
        "

        echo "→ Configuring kernel parameters for encrypted root..."

        if [[ -n "$LUKS_PART_UUID" && -n "$LUKS_MAPPER_NAME" ]]; then

            local crypt_params="cryptdevice=UUID=${LUKS_PART_UUID}:${LUKS_MAPPER_NAME}"

            if [[ -n "$LVM_VG_NAME" ]]; then
                crypt_params="$crypt_params root=/dev/mapper/${LVM_VG_NAME}-${LVM_ROOT_LV_NAME}"
            else
                crypt_params="$crypt_params root=/dev/mapper/${LUKS_MAPPER_NAME}"
            fi

            arch-chroot /mnt bash -c "
                sed -i \"s|^GRUB_CMDLINE_LINUX_DEFAULT=\\\"\\(.*\\)\\\"|GRUB_CMDLINE_LINUX_DEFAULT=\\\"\\1 ${crypt_params}\\\"|\" /etc/default/grub
            "
        fi
    fi

    # -----------------------------------------------------------------------------------
    # 2. GRUB Modules
    # -----------------------------------------------------------------------------------

    local GRUB_MODULES="part_gpt part_msdos normal boot linux search search_fs_uuid ext2 btrfs f2fs cryptodisk luks lvm"

    # -----------------------------------------------------------------------------------
    # 3. Install GRUB
    # -----------------------------------------------------------------------------------

    if [[ "$MODE" == "BIOS" ]]; then

        echo "→ Installing GRUB to MBR of $TARGET_DISK (BIOS Mode)..."

        arch-chroot /mnt grub-install \
            --target=i386-pc \
            --modules="$GRUB_MODULES" \
            --recheck "$TARGET_DISK" \
            || die "GRUB BIOS install failed on $TARGET_DISK"

    else
        echo "→ Installing GRUB to ESP (UEFI Mode) with LUKS crash mitigation..."

        mountpoint -q /mnt/boot/efi || die "EFI partition not mounted at /mnt/boot/efi."

        arch-chroot /mnt grub-install \
            --target=x86_64-efi \
            --efi-directory=/boot/efi \
            --bootloader-id=Arch \
            --modules="$GRUB_MODULES" \
            --skip-fs-probe \
            --recheck \
            "$TARGET_DISK" \
            || die "GRUB UEFI install failed"

        # Secure Boot (optional)
        if arch-chroot /mnt command -v sbctl &>/dev/null; then
            echo "→ Secure Boot detected, signing GRUB and kernel..."
            arch-chroot /mnt sbctl status || arch-chroot /mnt sbctl create-keys
            arch-chroot /mnt sbctl enroll-keys --microsoft || true
            arch-chroot /mnt sbctl sign --path /boot/efi/EFI/Arch/grubx64.efi || true
            arch-chroot /mnt sbctl sign --path /boot/vmlinuz-linux || true
        fi
    fi

    # -----------------------------------------------------------------------------------
    # 4. Generate grub.cfg
    # -----------------------------------------------------------------------------------

    echo "→ Generating grub.cfg..."

    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg \
        || die "Failed to generate grub.cfg"

    echo "✅ GRUB installation complete."
}
#=========================================================================================================================================#
# Network Mirror Selection
#=========================================================================================================================================#
network_mirror_selection(){
sleep 1
clear
echo
echo -e "#===================================================================================================#"
echo -e "# - INTERACTIVE MIRROR SELECTION & OPTIMIZATION                                                     #"
echo -e "#===================================================================================================#"
echo
# Ensure reflector is installed in chroot
arch-chroot /mnt pacman -Sy --needed --noconfirm reflector || {
    echo "⚠️ Failed to install reflector inside chroot — continuing with defaults."
    }
echo -e "#========================================================#"
echo -e "#                   MIRROR SELECTION                     #" 
echo -e "#========================================================#"
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
gpu_driver(){    
     sleep 1
     clear
     echo
     echo -e "#===================================================================================================#"
     echo -e "# - GPU DRIVER INSTALLATION & MULTILIB                                                              #"
     echo -e "#===================================================================================================#"
     echo
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
# ---------- WM/DE Selection ----------
window_manager() {
    sleep 1
    clear
    echo -e "#===================================================================================================#"
    echo -e "# - WINDOW MANAGER / DESKTOP ENVIRONMENT SELECTION                                                  #"
    echo -e "#===================================================================================================#"
    echo
    echo "1) Hyprland (Wayland)"
    echo "2) KDE Plasma (X11/Wayland)"
    echo "3) GNOME (X11/Wayland)"
    echo "4) XFCE (X11)"
    echo "5) Niri"
    echo "6) Cinnamon"
    echo "7) Mate"
    echo "8) Sway (Wayland)"
    echo "9) Skip selection"
    read -r -p "Select your preferred WM/DE [1-9, default=9]: " WM_CHOICE
    WM_CHOICE="${WM_CHOICE:-6}"
    
    WM_PKGS=()
    WM_AUR_PKGS=()
    
    # ---------- Set WM packages and selected WM ----------
    case "$WM_CHOICE" in
        1)
            SELECTED_WM="hyprland"
            echo -e "→ Selected: Hyprland"
            WM_PKGS=(hyprland hyprpaper hyprshot hypridle hyprlock nano wget networkmanager network-manager-applet bluez bluez-utils blueman hypridle hyprlock hyprpaper hyprshot slurp swayidle swaylock waybar xdg-desktop-portal-hyprland qt5-wayland qt6-wayland qt5ct qt6ct xdg-utils breeze breeze-icons discover dolphin dolphin-plugins kate konsole krita kvantum polkit-kde-agent pipewire gst-plugin-pipewire pavucontrol gst-libav gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly otf-font-awesome ttf-hack cpupower brightnessctl thermald smartmontools htop btop nvtop qview ark kitty konsole firefox dunst rofi wofi nwg-look nwg-displays archlinux-xdg-menu uwsm )
            WM_AUR_PKGS=(kvantum-theme-catppuccin-git wlogout wlrobs-hg)
            ;;
        2)
            SELECTED_WM="kde"
            echo -e "→ Selected: KDE Plasma"
            WM_PKGS=(plasma-desktop kde-applications konsole kate dolphin ark sddm firefox kitty)
            ;;
        3)
            SELECTED_WM="gnome"
            echo -e "→ Selected: GNOME"
            WM_PKGS=(gnome gdm gnome-tweaks firefox kitty)
            ;;
        4)
            SELECTED_WM="xfce"
            echo -e "→ Selected: XFCE"
            WM_PKGS=(xfce4 xfce4-goodies xarchiver gvfs pavucontrol lightdm-gtk-greeter firefox kitty)
            ;;
        5)
            SELECTED_WM="niri"
            echo -e "→ Selected: Niri"
            WM_PKGS=(niri alacritty fuzzel mako swaybg swayidle swaylock waybar xdg-desktop-portal-gnome xorg-xwayland)
            ;;
        6)
            SELECTED_WM="cinnamon"
            echo -e "→ Selected: Cinnamon"
            WM_PKGS=(cinnamon engrampa gnome-keyring gnome-screenshot gnome-terminal gvfs-smb system-config-printer xdg-user-dirs-gtk xed firefox kitty)
            ;;
        7)
            SELECTED_WM="mate"
            echo -e "→ Selected: Mate"
            WM_PKGS=(mate mate-extra kitty firefox)
            ;;
        8)
            SELECTED_WM="sway"
            echo -e "→ Selected: Sway"
            WM_PKGS=(sway swaybg swaylock swayidle waybar wofi xorg-xwayland wmenu slurp pavucontrol grim foot brightnessctl)
            ;;
        9|*)
            SELECTED_WM="none"
            echo "Skipping window manager installation."
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
    # ---------- Install only WM/DE packages ----------
    if [[ ${#WM_PKGS[@]} -gt 0 ]]; then
        safe_pacman_install CHROOT_CMD[@] "${WM_PKGS[@]}"
    fi
    if [[ ${#WM_AUR_PKGS[@]} -gt 0 ]]; then
        safe_aur_install CHROOT_CMD[@] "${WM_AUR_PKGS[@]}"
    fi

    echo "→ WM/DE packages installation completed. Skipping extra packages."
}
# ---------- DM Selection ----------
lm_dm() {
    sleep 1
    clear
    echo -e "#===================================================================================================#"
    echo -e "# -   Display Manager Selection                                                                     #"
    echo -e "#===================================================================================================#"
    
    DM_MENU=()
    DM_AUR_PKGS=()
    DM_SERVICE=""
    
    # ---------- Build recommended DM menu based on selected WM ----------
    case "$SELECTED_WM" in
        gnome)
            DM_MENU=("1) GDM (required for GNOME Wayland)")
            ;;
        kde)
            DM_MENU=("2) SDDM (recommended for KDE)" "1) GDM (works but not ideal)")
            ;;
        niri)
            DM_MENU=("1) GDM (recommended)" "2) SDDM (works but sometimes session missing)" "4) Ly (TUI, always works)")
            ;;
        hyprland|sway)
            DM_MENU=("2) SDDM (recommended)" "1) GDM" "4) Ly (TUI)")
            ;;
        xfce)
            DM_MENU=("3) LightDM (recommended)" "1) GDM" "2) SDDM" "5) LXDM")
            ;;
        cinnamon|mate)
            DM_MENU=("3) LightDM (recommended)" "1) GDM" "5) LXDM")
            ;;
        none)
            DM_MENU=("6) Skip Display Manager")
            ;;
        *)
            DM_MENU=("1) GDM" "2) SDDM" "3) LightDM" "4) Ly" "5) LXDM")
            ;;
    esac
    # ---------- Add Skip DM option ONLY if it is not already there ----------
    if ! printf "%s\n" "${DM_MENU[@]}" | grep -q "Skip"; then
        next=$(( ${#DM_MENU[@]} + 1 ))
        DM_MENU+=("${next}) Skip Display Manager")
    fi
    # ---------- Show menu ----------
    for entry in "${DM_MENU[@]}"; do
        echo "$entry"
    done
    # ---------- Auto-set default: number of the FIRST entry ----------
    DM_DEFAULT=$( echo "${DM_MENU[0]}" | cut -d')' -f1 )
    read -r -p "Select DM [default=${DM_DEFAULT}]: " DM_CHOICE
    DM_CHOICE="${DM_CHOICE:-$DM_DEFAULT}"
    
    DM_PKGS=()
    # ---------- Match selection ----------
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
        *)
            echo "Skipping display manager installation."
            return
            ;;
    esac
    
    # ---------- Install packages ----------
    if [[ ${#DM_PKGS[@]} -gt 0 ]]; then
        safe_pacman_install CHROOT_CMD[@] "${DM_PKGS[@]}"
    fi
    if [[ ${#DM_AUR_PKGS[@]} -gt 0 ]]; then
        safe_aur_install CHROOT_CMD[@] "${DM_AUR_PKGS[@]}"
    fi
    # ---------- Enable service ----------
    if [[ -n "$DM_SERVICE" ]]; then
        "${CHROOT_CMD[@]}" systemctl enable "$DM_SERVICE"
        echo "✅ Display manager service enabled: $DM_SERVICE"
    fi
    # ---------- Ly autologin ----------
    if [[ "$DM_SERVICE" == "ly.service" && -n "$USER_NAME" ]]; then
        echo "Setting up Ly autologin for $USER_NAME..."
        sudo mkdir -p /etc/systemd/system/ly.service.d
        printf "%s\n" \
            "[Service]" \
            "ExecStart=" \
            "ExecStart=/usr/bin/ly -a $USER_NAME" \
            | sudo tee /etc/systemd/system/ly.service.d/override.conf >/dev/null
    
        sudo systemctl daemon-reload
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
    echo -e "#===================================================================================================#"
    echo -e "# - EXTRA PACMAN PACKAGE INSTALLATION (Resilient + Safe)                                            #"
    echo -e "#===================================================================================================#"
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
optional_aur(){    
     sleep 1
     clear
     echo
     echo -e "#===================================================================================================#"
     echo -e "# - OPTIONAL AUR PACKAGE INSTALLATION (with Conflict Handling)                                      #"
     echo -e "#===================================================================================================#"
     echo
     
                     read -r -p "Install additional AUR packages using paru? [y/N]: " install_aur
                     install_aur="${install_aur:-N}"
                     if [[ "$install_aur" =~ ^[Yy]$ ]]; then
                         read -r -p "Enter any AUR packages (space-separated), or leave empty: " EXTRA_AUR_INPUT
                     
                         # Predefined extra AUR packages
                         EXTRA_AUR_PKGS=( )
                     
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
hyprland_theme() {
    sleep 1
    clear
    echo
    echo -e "#===================================================================================================#"
    echo -e "# - Hyprland Theme Setup (Optional) with .Config Backup                                     #"
    echo -e "#===================================================================================================#"
    echo
    sleep 1

    # Only proceed if Hyprland was selected (WM_CHOICE == 1)
    if [[ " ${WM_CHOICE:-} " =~ "1" ]]; then

        # FIX: Ensure 'sudo' is installed inside the chroot, as the inner script uses 'sudo -u $NEWUSER'.
        echo "🔧 Installing unzip, git, and sudo inside chroot to ensure theme download works..."
        arch-chroot /mnt pacman -S --needed --noconfirm unzip git sudo  # Added 'sudo'

        read -r -p "Do you want to install the Hyprland theme from GitHub? [Y/n]: " INSTALL_HYPR_THEME
        INSTALL_HYPR_THEME="${INSTALL_HYPR_THEME:-Y}"
        
        if [[ "$INSTALL_HYPR_THEME" =~ ^[Yy]$ ]]; then
            echo "→ Running Hyprland theme setup inside chroot..."

            # Using /bin/bash -c "..." structure, variables must be double-quoted and inner quotes escaped.
            arch-chroot /mnt /bin/bash -c "
NEWUSER=\"$NEWUSER\"
HOME_DIR=\"/home/\$NEWUSER\"
CONFIG_DIR=\"\$HOME_DIR/.config\"
REPO_DIR=\"\$HOME_DIR/hyprland-setup\"
TEMP_EXTRACT=\"\$HOME_DIR/hypr_extract_temp\"

# 1. Ensure home directory exists and is correctly owned
mkdir -p \"\$HOME_DIR\"
chown \$NEWUSER:\$NEWUSER \"\$HOME_DIR\"
chmod 755 \"\$HOME_DIR\"

# 2. Clone theme repo as the new user
if [[ -d \"\$REPO_DIR\" ]]; then
    rm -rf \"\$REPO_DIR\"
fi
# FIX: Use absolute path /usr/bin/git to bypass sudo PATH limitations and ensure execution.
sudo -u \$NEWUSER /usr/bin/git clone https://github.com/terra88/hyprland-setup.git \"\$REPO_DIR\" || { echo '❌ Git clone failed, skipping theme setup.'; exit 1; }

# 3. Copy zip and script files to home directory
sudo -u \$NEWUSER cp -f \"\$REPO_DIR/config.zip\" \"\$HOME_DIR/\" 2>/dev/null || echo '⚠️ config.zip missing'
sudo -u \$NEWUSER cp -f \"\$REPO_DIR/wallpaper.zip\" \"\$HOME_DIR/\" 2>/dev/null || echo '⚠️ wallpaper.zip missing'
sudo -u \$NEWUSER cp -f \"\$REPO_DIR/wallpaper.sh\" \"\$HOME_DIR/\" 2>/dev/null || echo '⚠️ wallpaper.sh missing'

# 4. Backup existing .config if not empty
if [[ -d \"\$CONFIG_DIR\" && \$(ls -A \"\$CONFIG_DIR\") ]]; then
    # Use sudo -u for move to maintain correct user ownership
    sudo -u \$NEWUSER mv \"\$CONFIG_DIR\" \"\$CONFIG_DIR.backup.\$(date +%s)\"
    echo '==> Existing .config backed up.'
fi

# 5. Extract config.zip and rename to .config (new requested logic)
if [[ -f \"\$HOME_DIR/config.zip\" ]]; then
    sudo -u \$NEWUSER mkdir -p \"\$TEMP_EXTRACT\"
    sudo -u \$NEWUSER unzip -o \"\$HOME_DIR/config.zip\" -d \"\$TEMP_EXTRACT\"
    
    # Determine the source directory inside the temporary folder
    SOURCE_DIR=\"\$TEMP_EXTRACT\"
    if [[ -d \"\$TEMP_EXTRACT\"/config ]]; then
        # Case 1: The zip extracted into a 'config' subdirectory
        SOURCE_DIR=\"\$TEMP_EXTRACT\"/config
    fi
    
    # Move/Rename the extracted directory to .config
    if [[ -d \"\$SOURCE_DIR\" ]]; then
        # Ensure target is clear before the move
        sudo -u \$NEWUSER rm -rf \"\$CONFIG_DIR\"
        
        # Move the source config folder to the final .config location
        sudo -u \$NEWUSER mv \"\$SOURCE_DIR\" \"\$CONFIG_DIR\"
        echo '==> config.zip extracted contents moved to .config'
    else
        echo '⚠️ Extracted config folder not found (expected config/ or top-level), skipping move.'
    fi
    
    # Cleanup the temporary extraction directory and zip file
    sudo -u \$NEWUSER rm -rf \"\$TEMP_EXTRACT\"
else
    echo '⚠️ config.zip not found, skipping config extraction.'
fi


# 6. Extract wallpaper.zip to HOME_DIR
if [[ -f \"\$HOME_DIR/wallpaper.zip\" ]]; then
    sudo -u \$NEWUSER unzip -o \"\$HOME_DIR/wallpaper.zip\" -d \"\$HOME_DIR\" && echo '==> wallpaper.zip extracted'
    sudo -u \$NEWUSER rm -f \"\$HOME_DIR/wallpaper.zip\"
fi

# 7. Copy wallpaper.sh and make executable
if [[ -f \"\$HOME_DIR/wallpaper.sh\" ]]; then
    sudo -u \$NEWUSER chmod +x \"\$HOME_DIR/wallpaper.sh\"
    echo '==> wallpaper.sh copied and made executable'
fi

# 8. Set secure permissions on .config (final check)
if [[ -d \"\$CONFIG_DIR\" ]]; then
    sudo -u \$NEWUSER find \"\$CONFIG_DIR\" -type d -exec chmod 700 {} \;
    sudo -u \$NEWUSER find \"\$CONFIG_DIR\" -type f -exec chmod 600 {} \;
fi

# 9. Cleanup cloned repo
sudo -u \$NEWUSER rm -rf \"\$REPO_DIR\"
"
            echo "✅ Hyprland theme setup completed."
        else
            echo "Skipping Hyprland theme setup."
        fi
    fi
}
#=========================================================================================================================================#
#=========================================================================================================================================#
# Quick Partition - Section:
#=========================================================================================================================================#
#=========================================================================================================================================#
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
    echo -e "#===============================================================================#"
    echo -e "|  Filesystem Selection Options                                                 |"
    echo -e "#===============================================================================#"
    echo -e "| 1) EXT4 (root + home)                                                         |"
    echo -e "|-------------------------------------------------------------------------------|"
    echo -e "| 2) BTRFS (root + home)                                                        |"
    echo -e "|-------------------------------------------------------------------------------|"
    echo -e "| 3) BTRFS root + EXT4 home                                                     |"
    echo -e "#===============================================================================#"
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
    echo -e "#===============================================================================#"
    echo -e "| Swap On / Off                                                                 |"
    echo -e "#===============================================================================#"
    echo -e "| 1) Swap On                                                                    |"
    echo -e "|-------------------------------------------------------------------------------|"
    echo -e "| 2) Swap Off                                                                   |"
    echo -e "|-------------------------------------------------------------------------------|"
    echo -e "| 3) exit                                                                       |"
    echo -e "#===============================================================================#"
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
#=========================================================================#
# Ask partition sizes (fixed)
#=========================================================================#
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

        local reserved_gib
        if [[ "$MODE" == "UEFI" ]]; then
            reserved_gib=$(( EFI_SIZE_MIB / 1024 ))
        else
            reserved_gib=$(( BOOT_SIZE_MIB / 1024 + BIOS_GRUB_SIZE_MIB / 1024 ))
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
            HOME_SIZE_GIB=$remaining_home_gib
            HOME_SIZE_MIB=0      # will handle as 100% in partitioning
            home_end="100%"
        else
            [[ "$HOME_SIZE_GIB_INPUT" =~ ^[0-9]+$ ]] || { echo "Must be numeric"; continue; }

            if (( HOME_SIZE_GIB_INPUT > remaining_home_gib )); then
                echo "⚠️ Maximum available HOME size is ${remaining_home_gib} GiB. Setting HOME to maximum."
                HOME_SIZE_GIB=$remaining_home_gib
            else
                HOME_SIZE_GIB=$HOME_SIZE_GIB_INPUT
            fi

            HOME_SIZE_MIB=$(( HOME_SIZE_GIB * 1024 ))
        fi

        echo "✅ Partition sizes set: ROOT=${ROOT_SIZE_GIB} GiB, HOME=${HOME_SIZE_GIB} GiB, SWAP=$((SWAP_SIZE_MIB/1024)) GiB"
        break
    done
}
#=========================================================================#
# Partition disk (Fixed: Unified Layout, No separate /boot)
#=========================================================================#
partition_disk() {
    [[ -z "$DEV" ]] && die "partition_disk(): DEV not set"
    detect_boot_mode
    calculate_swap_quick

    echo -e "\n🛈 Starting partitioning on $DEV..."
    # Wipe old signatures to prevent conflict
    wipefs -af "$DEV"
    parted -s "$DEV" mklabel gpt || die "Failed to create GPT label"

    local start end root_start root_end swap_start swap_end home_start home_end

    # ---------------------------------------------------------
    # PARTITION 1: Boot Loader/Manager
    # ---------------------------------------------------------
    if [[ "$MODE" == "BIOS" ]]; then
        echo "→ Creating BIOS GRUB mandatory partition (1MiB)..."
        # Create 1MiB partition for GRUB embedding
        parted -s "$DEV" mkpart primary 1MiB 2MiB || die "Failed to create BIOS GRUB"
        parted -s "$DEV" set 1 bios_grub on
        parted -s "$DEV" name 1 bios_grub  # Set PARTLABEL
        start=2
    else
        echo "→ Creating EFI System Partition (${EFI_SIZE_MIB}MiB)..."
        end=$((1 + EFI_SIZE_MIB))
        parted -s "$DEV" mkpart primary fat32 1MiB "${end}MiB" || die "Failed to create EFI"
        parted -s "$DEV" set 1 boot on
        parted -s "$DEV" set 1 esp on
        parted -s "$DEV" name 1 efi      # Set PARTLABEL
        start=$end
    fi

    # ---------------------------------------------------------
    # PARTITION 2: ROOT (Contains /boot folder)
    # ---------------------------------------------------------
    root_start=$start
    root_end=$((root_start + ROOT_SIZE_MIB))
    
    echo "→ Creating ROOT partition..."
    parted -s "$DEV" mkpart primary "$ROOT_FS" "${root_start}MiB" "${root_end}MiB" || die "Failed to create ROOT"
    parted -s "$DEV" name 2 root         # Set PARTLABEL

    # ---------------------------------------------------------
    # PARTITION 3: SWAP (Optional)
    # ---------------------------------------------------------
    if [[ "$SWAP_ON" == "1" ]]; then
        swap_start=$root_end
        swap_end=$((swap_start + SWAP_SIZE_MIB))
        echo "→ Creating SWAP partition..."
        parted -s "$DEV" mkpart primary linux-swap "${swap_start}MiB" "${swap_end}MiB"
        parted -s "$DEV" name 3 swap     # Set PARTLABEL
        home_start=$swap_end
        home_num=4
    else
        home_start=$root_end
        home_num=3
    fi

    # ---------------------------------------------------------
    # PARTITION 3/4: HOME (Optional)
    # ---------------------------------------------------------
    # Check if a separate HOME partition was chosen (either manual size, or using all remaining space where HOME_SIZE_MIB is 0).
    if (( HOME_SIZE_MIB > 0 )) || [[ -z "$HOME_SIZE_GIB_INPUT" ]]; then
        echo "→ Creating HOME partition..."
        # Use 100% because if HOME_SIZE_MIB > 0, the disk has been calculated precisely,
        # and if HOME_SIZE_MIB == 0, it means use the rest of the disk.
        parted -s "$DEV" mkpart primary "$HOME_FS" "${home_start}MiB" 100%
        parted -s "$DEV" name "$home_num" home # Set PARTLABEL
    fi

    partprobe "$DEV" || true
    udevadm settle --timeout=5 || true
    echo "✅ Partitioning completed."
}
#=========================================================================#
# Format & mount (Fixed: Robust PARTLABEL detection)
#=========================================================================#
format_and_mount() {
    [[ -z "$DEV" ]] && die "format_and_mount(): DEV not set"
    detect_boot_mode

    echo -e "\n🛈 Refreshing partition table..."
    partprobe "$DEV"
    udevadm settle
    sleep 2

    # Reset variables
    P_BIOS_GRUB="" P_EFI="" P_ROOT="" P_SWAP="" P_HOME=""

    # 1. Map partitions using PARTLABEL (Name)
    # This is safer than filesystem labels because mkfs hasn't run yet.
    while read -r part path name; do
        # Convert name to lowercase
        name="${name,,}"
        case "$name" in
            bios_grub) P_BIOS_GRUB="$path" ;;
            efi)       P_EFI="$path" ;;
            root)      P_ROOT="$path" ;;
            swap)      P_SWAP="$path" ;;
            home)      P_HOME="$path" ;;
        esac
    done < <(lsblk -rn -o PARTTYPE,PATH,PARTLABEL "$DEV" | awk '{print $1, $2, $3}')

    # Fallback: If labels failed, map by index (Standardized Layout)
    # Layout is always: [1:Boot/EFI] -> [2:Root] -> [3:Swap/Home]
    mapfile -t PARTS < <(lsblk -ln -o PATH,TYPE -p "$DEV" | awk '$2=="part"{print $1}')
    
    if [[ -z "$P_ROOT" ]]; then
        echo "⚠ Auto-detection by label failed, falling back to position..."
        if [[ "$MODE" == "UEFI" ]]; then
            [[ -z "$P_EFI" ]] && P_EFI="${PARTS[0]}"
        else
            [[ -z "$P_BIOS_GRUB" ]] && P_BIOS_GRUB="${PARTS[0]}"
        fi
        
        # ROOT is ALWAYS partition index 1 (the second partition) in this fixed layout
        P_ROOT="${PARTS[1]}" 
        
        # Simple mapping for Swap/Home based on user selection
        if [[ "$SWAP_ON" == "1" ]]; then
            [[ -z "$P_SWAP" ]] && P_SWAP="${PARTS[2]}"
            [[ -z "$P_HOME" && "${#PARTS[@]}" -gt 3 ]] && P_HOME="${PARTS[3]}"
        else
            [[ -z "$P_HOME" && "${#PARTS[@]}" -gt 2 ]] && P_HOME="${PARTS[2]}"
        fi
    fi

    echo "Detected Mapping:"
    echo " ROOT: $P_ROOT"
    [[ -n "$P_EFI" ]] && echo " EFI : $P_EFI"
    [[ -n "$P_BIOS_GRUB" ]] && echo " BIOS: $P_BIOS_GRUB"

    [[ -z "$P_ROOT" ]] && die "Could not determine ROOT partition."

    # Safety Check
    if mountpoint -q /mnt; then
        umount -R /mnt || true
    fi

    # 2. Format & Mount ROOT
    echo "→ Formatting ROOT ($ROOT_FS) on $P_ROOT..."
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        mkfs.btrfs -f -L root "$P_ROOT"
        mount "$P_ROOT" /mnt
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        umount /mnt
        mount -o subvol=@,compress=zstd "$P_ROOT" /mnt
    else
        mkfs.ext4 -F -L root "$P_ROOT"
        mount "$P_ROOT" /mnt
    fi

    mkdir -p /mnt/boot /mnt/home /mnt/etc

    # 3. Format & Mount EFI (UEFI Only)
    if [[ "$MODE" == "UEFI" && -n "$P_EFI" ]]; then
        echo "→ Formatting EFI on $P_EFI..."
        mkfs.fat -F32 -n EFI "$P_EFI"
        mkdir -p /mnt/boot/efi
        mount "$P_EFI" /mnt/boot/efi
    fi

    # 4. Swap
    if [[ -n "$P_SWAP" ]]; then
        echo "→ Activating SWAP on $P_SWAP..."
        mkswap -L swap "$P_SWAP"
        swapon "$P_SWAP"
    fi

    # 5. Home
    if [[ -n "$P_HOME" ]]; then
        echo "→ Formatting HOME on $P_HOME..."
        if [[ "$HOME_FS" == "btrfs" ]]; then
            # If root was btrfs, we might just use subvolumes, but if partition exists:
             mkfs.btrfs -f -L home "$P_HOME"
             mount -o compress=zstd "$P_HOME" /mnt/home
        else
             mkfs.ext4 -F -L home "$P_HOME"
             mount "$P_HOME" /mnt/home
        fi
    elif [[ "$ROOT_FS" == "btrfs" ]]; then
        # Mount @home subvolume if we don't have a separate partition
        mount -o subvol=@home,compress=zstd "$P_ROOT" /mnt/home
    fi

    # 6. Fstab
    genfstab -U /mnt >> /mnt/etc/fstab

    echo "✅ Formatting and mounting complete."
}
#===============================#
#=QUICK PARTITION MAIN FUNCTION=#
#===============================#
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
    hyprland_theme

    echo -e "✅ Arch Linux installation complete."
}
#=========================================================================================================================================#
#=========================================================================================================================================#
#====================================== Custom Partition // Choose Filesystem Custom : SECTION #==========================================#
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
        echo "Invalid size format: $1. Use M, MiB, G, GiB, or 100%" >&2
        return 1
    fi
}
#=========================================================================================================================================#
# Custom Partition Wizard (Unlimited partitions, any FS) - FIXED VERSION
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
    read -rp "Type y/n to continue (Enter for yes): " CONFIRM
    if [[ -n "$CONFIRM" && ! "$CONFIRM" =~ ^(YES|yes|Y|y)$ ]]; then
        die "Aborted."
    fi

    safe_disk_cleanup
    parted -s "$DEV" mklabel gpt

    local ps=""
    [[ "$DEV" =~ nvme ]] && ps="p"

    # local per-disk partition array
    local NEW_PARTS=()
    local START=1
    local RESERVED_PARTS=0

    # ---------------- BIOS / UEFI reserved partitions ----------------
    if [[ "$MODE" == "BIOS" ]]; then
        read -rp "Create BIOS Boot Partition automatically? (y/n): " bios_auto
        bios_auto="${bios_auto:-n}"
        if [[ "$bios_auto" =~ ^[Yy]$ ]]; then
            parted -s "$DEV" unit MiB mkpart primary 1MiB 2MiB || die "Failed to create BIOS partition"
            parted -s "$DEV" set 1 bios_grub on || die "Failed to set bios_grub flag"
            NEW_PARTS+=("${DEV}${ps}1:none:none:bios_grub")
            RESERVED_PARTS=$((RESERVED_PARTS+1))
            START=2

            # --- SAVE THE DISK FOR GRUB INSTALLER ---
            export BOOT_LOADER_DISK="$DEV"   ### <--- ADD THIS
            echo "→ Boot disk set to: $BOOT_LOADER_DISK"
        fi
    fi

    if [[ "$MODE" == "UEFI" ]]; then
        read -rp "Automatically create 1024MiB EFI System Partition? (y/n): " esp_auto
        esp_auto="${esp_auto:-n}"
        if [[ "$esp_auto" =~ ^[Yy]$ ]]; then
            parted -s "$DEV" unit MiB mkpart primary fat32 1MiB 1025MiB || die "Failed to create ESP"
            parted -s "$DEV" set 1 esp on
            parted -s "$DEV" set 1 boot on || true
            NEW_PARTS+=("${DEV}${ps}1:/boot/efi:fat32:EFI")
            RESERVED_PARTS=$((RESERVED_PARTS+1))
            START=1025

            # --- SAVE THE DISK FOR GRUB INSTALLER ---
            export BOOT_LOADER_DISK="$DEV"   ### <--- ADD THIS
            echo "→ Boot disk set to: $BOOT_LOADER_DISK"
        fi
    fi

    # ---------------- Disk info ----------------
    local disk_bytes disk_mib
    disk_bytes=$(lsblk -b -dn -o SIZE "$DEV") || die "Cannot read disk size."
    disk_mib=$(( disk_bytes / 1024 / 1024 ))
    echo "Disk size: $(( disk_mib / 1024 )) GiB"

    # ---------------- User-defined partitions ----------------
    read -rp "How many partitions would you like to create on $DEV? " COUNT
    [[ "$COUNT" =~ ^[0-9]+$ && "$COUNT" -ge 1 ]] || die "Invalid partition count."

    for ((j=1; j<=COUNT; j++)); do
        i=$((j + RESERVED_PARTS))
        parted -s "$DEV" unit MiB print

        # Determine available space for this partition
        local AVAILABLE=$((disk_mib - START))
        echo "Available space on disk: $AVAILABLE MiB"

        # Size
        while true; do
            read -rp "Size (ex: 20G, 512M, 100% for last, default 100%): " SIZE
            SIZE="${SIZE:-100%}"
            SIZE_MI=$(convert_to_mib "$SIZE") || continue

            if [[ "$SIZE_MI" != "100%" && $SIZE_MI -gt $AVAILABLE ]]; then
                echo "⚠ Requested size too large. Max available: $AVAILABLE MiB"
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
        read -rp "Mountpoint (/, /home, /boot, swap, none, leave blank for auto /dataX): " MNT
        if [[ -z "$MNT" ]]; then
            # Auto-assign /dataX for secondary partitions
            local next_data=1
            while grep -q "/data$next_data" <<<"${PARTITIONS[*]}"; do
                ((next_data++))
            done
            MNT="/data$next_data"
            echo "→ Auto-assigned mountpoint: $MNT"
        fi

        # Filesystem
        while true; do
            read -rp "Filesystem (ext4, btrfs, xfs, f2fs, fat32, swap): " FS
            case "$FS" in
                ext4|btrfs|xfs|f2fs|fat32|swap) break ;;
                *) echo "Unsupported FS." ;;
            esac
        done

        # Label
        read -rp "Label (optional): " LABEL

        # Create partition
        parted -s "$DEV" unit MiB mkpart primary $PART_SIZE || die "Failed to create partition $i"
        PART="${DEV}${ps}${i}"
        NEW_PARTS+=("$PART:$MNT:$FS:$LABEL")
        [[ "$END" != "100%" ]] && START=$END
    done

    # Merge per-disk NEW_PARTS into global PARTITIONS
    PARTITIONS+=("${NEW_PARTS[@]}")
    echo "=== Partitions for $DEV ==="
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
        read -rp "Do you want to edit another disk? (Yy/Nn, default no): " answer
        case "$answer" in
            [Yy])
                echo "→ Editing another disk..."
                custom_partition_wizard

                # Auto-assign /dataX for new partitions with 'none' mount
                for i in "${!PARTITIONS[@]}"; do
                    IFS=':' read -r PART MOUNT FS LABEL <<< "${PARTITIONS[$i]}"

                    # Skip partitions already assigned
                    if [[ "$MOUNT" != "none" && "$MOUNT" != "" ]]; then
                        continue
                    fi

                    # Skip root /boot /efi etc
                    if [[ "$LABEL" == "bios_grub" || "$MOUNT" =~ ^/(boot|boot/efi|)$ ]]; then
                        continue
                    fi

                    PARTITIONS[$i]="$PART:/data$disk_counter:$FS:$LABEL"
                    echo "→ Auto-assigned $PART to /data$disk_counter"
                    ((disk_counter++))
                done
                ;;
            ""|[Nn])
                echo "→ No more disks. Continuing..."
                break
                ;;
            *)
                echo "Please enter Y or n."
                ;;
        esac
    done
}

#=========================================================================================================================================#
#  Format AND Mount Custom - UPDATED (Accumulate disks; mount root first; safe unmounts)
#=========================================================================================================================================#
format_and_mount_custom() {
    echo "→ Formatting and mounting custom partitions..."
    mkdir -p /mnt

    if [[ ${#PARTITIONS[@]} -eq 0 ]]; then
        die "No partitions to format/mount (PARTITIONS is empty)."
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
        [[ -b "$PART" ]] || die "Partition $PART not available."

        # Skip reserved partitions
        [[ "$LABEL" == "bios_grub" ]] && { echo ">>> Skipping BIOS boot partition $PART"; continue; }
        [[ "$FS" == "none" ]] && continue

        echo ">>> Formatting $PART as $FS"
        case "$FS" in
            ext4) mkfs.ext4 -F "$PART" ;;
            btrfs) mkfs.btrfs -f "$PART" ;;
            xfs) mkfs.xfs -f "$PART" ;;
            f2fs) mkfs.f2fs -f "$PART" ;;
            fat32|vfat) mkfs.fat -F32 "$PART" ;;
            swap) mkswap "$PART"; swapon "$PART"; continue ;;
            *) die "Unsupported filesystem: $FS" ;;
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
                    mount "$PART" /mnt || die "Failed to mount root $PART on /mnt"
                fi
                ;;
            /home) mkdir -p /mnt/home; mount "$PART" /mnt/home ;;
            /boot) mkdir -p /mnt/boot; mount "$PART" /mnt/boot ;;
            /efi|/boot/efi) mkdir -p /mnt/boot/efi; mount "$PART" /mnt/boot/efi ;;
            /data*)  # Auto-mount secondary disk partitions
                local DATA_DIR="/mnt${MOUNT}"
                mkdir -p "$DATA_DIR"
                mount "$PART" "$DATA_DIR" || die "Failed to mount $PART on $DATA_DIR"
                ;;
            *)  # Any other custom mountpoint
                mkdir -p "/mnt$MOUNT"
                mount "$PART" "/mnt$MOUNT"
                ;;
        esac
    done

    mountpoint -q /mnt || die "Root (/) not mounted. Ensure you have a root partition."

    echo "✅ All custom partitions formatted and mounted correctly."

    echo "Generating /etc/fstab..."
    mkdir -p /mnt/etc
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "→ /etc/fstab content:"
    cat /mnt/etc/fstab
}
#============================================================================================================================#
# ENSURE FS SUPPORT FOR CUSTOM PARTITION SCHEME (Robust for multiple disks / reserved partitions)
#============================================================================================================================#
ensure_fs_support_for_custom() {
    echo "→ Running ensure_fs_support_for_custom()"

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
    custom_partition_wizard

    # --- Optional extra disks ---
    create_more_disks

    # --- Format & mount all partitions ---
    format_and_mount_custom

    # --- Install base system ---
    install_base_system

    # --- Ensure filesystem tools inside target ---
    ensure_fs_support_for_custom

    # --- Continue installation steps ---
    configure_system
    install_grub
    network_mirror_selection
    gpu_driver
    window_manager
    lm_dm
    extra_pacman_pkg
    optional_aur
    hyprland_theme
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
    echo "→ Running ensure_fs_support_for_luks_lvm() for post-install configuration."

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
        echo "→ Installing packages inside target: ${pkgs[*]}"
        arch-chroot /mnt pacman -Syu --noconfirm "${pkgs[@]}" || die "Failed to install tools in target."
    fi

    # Build HOOKS line deterministically depending on whether LUKS is used
    local HOOKS_LINE
    if [[ "$enable_luks" -eq 1 ]]; then
        echo "→ Setting mkinitcpio HOOKS for LUKS+LVM"
        HOOKS_LINE='HOOKS=(base udev autodetect keyboard modconf block encrypt lvm2 filesystems fsck)'
    else
        echo "→ Setting mkinitcpio HOOKS for LVM-only"
        HOOKS_LINE='HOOKS=(base udev autodetect modconf block lvm2 filesystems keyboard fsck)'
    fi

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
    # first disk
    luks_lvm_route || die "First luks_lvm_route failed"

    # optional additional disks (allows adding PVs to existing VG or creating new VGs)
    while true; do
        read -rp "Do you want to edit another disk for LUKS/LVM? (Y/n): " ans
        ans="${ans:-n}"
        case "$ans" in
            [Yy])
                luks_lvm_route || die "luks_lvm_route failed for another disk"
                ;;
            [Nn]) break ;;
            *) echo "Please answer Y or n." ;;
        esac
    done

    # single post-install run
    luks_lvm_post_install_steps
}
wait_for_lv() {
    local dev="$1"
    local timeout=10
    for ((i=0;i<timeout;i++)); do
        [[ -b "$dev" ]] && return 0
        sleep 0.5
        udevadm settle --timeout=2
    done
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

    echo "Available block devices (disks):"
    lsblk -d -o NAME,SIZE,MODEL,TYPE

    # helper re-prompt functions
    ask_disk() {
        while true; do
            read -rp "Enter target disk (example /dev/sda or nvme0n1): " _d
            _d="/dev/${_d##*/}"
            [[ -b "$_d" ]] && { DEV="$_d"; return 0; }
            echo "Invalid block device: '$_d'. Try again."
        done
    }
ask_yesno_default() {
    local prompt="$1"
    local def="${2:-N}"
    local ans
    while true; do
        read -rp "$prompt " ans
        ans="${ans:-$def}"
        ans_upper=$(echo "$ans" | tr '[:lower:]' '[:upper:]')  # normalize input
        case "$ans_upper" in
            Y|YES) return 0 ;;    # success = yes
            N|NO)  return 1 ;;    # failure = no
            *) echo "Please answer Y or N." ;;
        esac
    done
}
    ask_nonempty() {
        local prompt="$1" val
        while true; do
            read -rp "$prompt" val
            [[ -n "$val" ]] && { REPLY="$val"; return 0; }
            echo "Cannot be empty."
        done
    }
    ask_lv_size() {
        # basic validation for LVM size: accept 40G, 512M, 10%VG, 100%FREE
        local prompt="${1:-Size (40G, 512M, 10%VG, 100%FREE) [100%FREE]: }" ans
        while true; do
            read -rp "$prompt" ans
            ans="${ans:-100%FREE}"
            if [[ "$ans" =~ ^([0-9]+G|[0-9]+M|[0-9]+%VG|[0-9]+%FREE|100%FREE)$ ]]; then
                REPLY="$ans"
                return 0
            fi
            if [[ "$ans" =~ ^[0-9]+$ ]]; then
                REPLY="${ans}G"; return 0
            fi
            echo "Invalid LVM size format."
        done
    }
    ask_mountpoint() {
        local prompt="${1:-Mountpoint (/, /home, swap, /data, none): }" ans
        while true; do
            read -rp "$prompt" ans
            ans="${ans:-none}"
            case "$ans" in
                /|/home|/boot|/efi|/boot/efi|swap|none|/data*|/srv|/opt) REPLY="$ans"; return 0 ;;
                *) echo "Invalid mountpoint. Allowed: / /home /boot /efi /boot/efi swap none /dataX /srv /opt" ;;
            esac
        done
    }
    ask_fs() {
        local prompt="${1:-Filesystem (ext4,btrfs,xfs,f2fs) [ext4]: }" ans
        while true; do
            read -rp "$prompt" ans
            ans="${ans:-ext4}"
            case "$ans" in
                ext4|btrfs|xfs|f2fs) REPLY="$ans"; return 0 ;;
                *) echo "Invalid fs. Choose ext4,btrfs,xfs,f2fs" ;;
            esac
        done
    }

    # start
    ask_disk
    echo "WARNING: This will ERASE ALL DATA on $DEV"
    ask_yesno_default "Continue? [y/N]:" "N" || { echo "Aborted by user."; return 1; }

    # verify required system tools exist in live env
    for cmd in parted blkid cryptsetup pvcreate vgcreate lvcreate vgchange lvdisplay mkfs.ext4 mkfs.fat; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "ERROR: $cmd not found on live system. Install required packages (lvm2, cryptsetup, parted) and retry."
            return 1
        fi
    done

    safe_disk_cleanup

    ps=$(part_suffix "$DEV")
    echo "→ Writing GPT to $DEV"
    parted -s "$DEV" mklabel gpt || die "mklabel failed"

    PART_BOOT=""    # path to boot/esp partition (unencrypted)
    PART_LUKS=""    # path to big partition that will be LUKS or PV
    PART_GRUB_BIOS=""

    if [[ "$MODE" == "UEFI" ]]; then
        echo "→ MODE=UEFI: creating 1MiB..1025MiB ESP and main partition"
        parted -s "$DEV" unit MiB mkpart primary fat32 1MiB 1025MiB || die "mkpart ESP failed"
        parted -s "$DEV" set 1 esp on || die "set esp failed"
        PART_BOOT="${DEV}${ps}1"
        parted -s "$DEV" unit MiB mkpart primary 1026MiB 100% || die "mkpart main failed"
        PART_LUKS="${DEV}${ps}2"

        partprobe "$DEV"; udevadm settle --timeout=5

        # create esp filesystem now
        mkfs.fat -F32 "$PART_BOOT" || die "mkfs.fat failed on $PART_BOOT"
    else
        echo "→ MODE=BIOS: creating bios_grub (1MiB), /boot (512MiB), and main partition"
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

    [[ -b "$PART_LUKS" ]] || die "Partition $PART_LUKS missing after partitioning."

# Ask whether to encrypt main partition
    if ask_yesno_default "Encrypt main partition ($PART_LUKS) with LUKS2? [Y/n]:" "Y"; then
        ENCRYPTION_ENABLED=1
        
        local luks_type
        if ask_yesno_default "Use LUKS2 (recommended)? [Y/n]:" "Y"; then
            luks_type="luks2"
        else
            luks_type="luks1"
        fi

        # --- LUKS FORMATTING (Set Passphrase) ---
        
        echo "========================================================"
        echo "🚨 ATTENTION: Please enter the NEW LUKS PASSPHRASE twice."
        echo "    This password will secure your partition."
        echo "========================================================"
        
        # --- FIX: Removed the 'echo "YES" |' pipe to allow interactive passphrase input.
        cryptsetup luksFormat --type "$luks_type" "$PART_LUKS" || die "LUKS format failed"
        
        echo "✅ LUKS format complete."
        # --- END LUKS FORMATTING ---

        # ask mapper name and ensure uniqueness (This part is correctly placed now)
        while true; do
            read -rp "Name for mapped device (default cryptlvm): " cryptname
            cryptname="${cryptname:-cryptlvm}"
            if [[ -e "/dev/mapper/$cryptname" ]]; then
                echo "/dev/mapper/$cryptname exists — choose another"
                continue
            fi
            break
        done

        LUKS_MAPPER_NAME="$cryptname"
        
        # --- LUKS OPENING (Provide Passphrase) ---
        echo "========================================================================="
        echo "🔑 Enter the PASSPHRASE you JUST SET to open the device."
        echo "    (This creates /dev/mapper/$LUKS_MAPPER_NAME)"
        echo "========================================================================="
        # The user must type the same password again here.
        cryptsetup open "$PART_LUKS" "$LUKS_MAPPER_NAME" || die "cryptsetup open failed"
        
        # --- END LUKS OPENING ---
        
        BASE_DEVICE="/dev/mapper/${LUKS_MAPPER_NAME}"
        LUKS_PART_UUID=$(blkid -s UUID -o value "$PART_LUKS" || true)
    else
        ENCRYPTION_ENABLED=0
        BASE_DEVICE="$PART_LUKS"
    fi

    echo "→ Creating PV on $BASE_DEVICE"
    pvcreate "$BASE_DEVICE" || die "pvcreate failed on $BASE_DEVICE"

    # ask VG name and create/extend
    while true; do
        read -rp "Volume Group name (default vg0): " VGNAME
        VGNAME="${VGNAME:-vg0}"
        if [[ "$VGNAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then break; fi
        echo "Invalid VG name."
    done

    if vgdisplay "$VGNAME" >/dev/null 2>&1; then
        if ask_yesno_default "VG $VGNAME exists — add PV to it? [Y/n]:" "Y"; then
            vgextend "$VGNAME" "$BASE_DEVICE" || die "vgextend failed"
        else
            while true; do
                read -rp "New VG name: " VGNAME
                VGNAME="${VGNAME:-vg0}"
                [[ "$VGNAME" =~ ^[a-zA-Z0-9._-]+$ ]] && break
                echo "Invalid name"
            done
            vgcreate "$VGNAME" "$BASE_DEVICE" || die "vgcreate failed"
        fi
    else
        vgcreate "$VGNAME" "$BASE_DEVICE" || die "vgcreate failed"
    fi

    vgscan --mknodes
    vgchange -ay "$VGNAME" || die "vgchange -ay failed"

    # Interactively create LVs (re-prompt on invalid input)
    LV_NAMES=()
    LV_SIZES=()
    LV_FSS=()
    LV_MOUNTS=()

    echo
    echo "Create logical volumes. Enter empty LV name to finish."
    while true; do
        read -rp "LV name (empty to finish): " lvname
        lvname="${lvname// /}"
        [[ -z "$lvname" ]] && break
        if ! [[ "$lvname" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            echo "Invalid LV name."
            continue
        fi

        ask_lv_size
        lvsize="$REPLY"    # validated LVM size (like 40G, 100%FREE)

        ask_mountpoint
        lvmnt="${REPLY:-none}"

        if [[ "$lvmnt" == "/" ]]; then
            LVM_ROOT_LV_NAME="$lvname"
        fi

        if [[ "$lvmnt" == "swap" ]]; then
            lvfs="swap"
        else
            ask_fs
            lvfs="$REPLY"
        fi

        LV_NAMES+=("$lvname")
        LV_SIZES+=("$lvsize")
        LV_FSS+=("$lvfs")
        LV_MOUNTS+=("$lvmnt")
    done

    if [[ ${#LV_NAMES[@]} -eq 0 ]]; then
        die "No LVs defined; aborting."
    fi

    # create LVs; if lvcreate fails, allow retry/adjust
    for idx in "${!LV_NAMES[@]}"; do
        name="${LV_NAMES[idx]}"
        size="${LV_SIZES[idx]}"
    
        while true; do
    
            # Detect percentage-based sizes → must use -l (extents)
            if [[ "$size" =~ % ]]; then
                LVCREATE_CMD=(lvcreate -l "$size" "$VGNAME" -n "$name")
            else
                LVCREATE_CMD=(lvcreate -L "$size" "$VGNAME" -n "$name")
            fi
    
            # Attempt LV creation
            if "${LVCREATE_CMD[@]}" 2>/tmp/lvcreate.err; then
                break
            fi
    
            echo "lvcreate failed for $name (size=$size):"
            sed -n '1,200p' /tmp/lvcreate.err
    
            read -rp "Retry with new size? (y to retry / n to abort) [y]: " r
            r="${r:-y}"
    
            case "$r" in
                [Yy])
                    ask_lv_size "New size for $name: "
                    size="$REPLY"
                    ;;
                [Nn])
                    die 'User aborted LV creation.'
                    ;;
                *)
                    echo "Please answer y or n."
                    ;;
            esac
        done
    done

    udevadm settle --timeout=5

    # Format & mount LVs: root first
    mkdir -p /mnt
    root_index=""
    for i in "${!LV_MOUNTS[@]}"; do
        [[ "${LV_MOUNTS[i]}" == "/" ]] && { root_index="$i"; break; }
    done

    format_and_mount_lv() {
        local idx="$1"
        local name="${LV_NAMES[idx]}"
        local fs="${LV_FSS[idx]}"
        local mnt="${LV_MOUNTS[idx]}"
        local lvpath="/dev/${VGNAME}/${name}"

        wait_for_lv "$lvpath" || die "LV $lvpath not available"

        if [[ "$fs" == "swap" || "$mnt" == "swap" ]]; then
            mkswap "$lvpath" || die "mkswap failed on $lvpath"
            swapon "$lvpath" || die "swapon failed on $lvpath"
            P_SWAP="$lvpath"
            return 0
        fi

        case "$fs" in
            ext4) mkfs.ext4 -F "$lvpath" ;;
            btrfs) mkfs.btrfs -f "$lvpath" ;;
            xfs) mkfs.xfs -f "$lvpath" ;;
            f2fs) mkfs.f2fs -f "$lvpath" ;;
            *) die "Unsupported FS $fs" ;;
        esac

        case "$mnt" in
            /)
                if [[ "$fs" == "btrfs" ]]; then
                    mount "$lvpath" /mnt || die "mount $lvpath /mnt failed"
                    btrfs subvolume create /mnt/@ || true
                    umount /mnt || true
                    mount -o subvol=@,compress=zstd "$lvpath" /mnt || die "btrfs mount failed"
                else
                    mount "$lvpath" /mnt || die "mount $lvpath /mnt failed"
                fi
                P_ROOT="$lvpath"
                ;;
            /home)
                mkdir -p /mnt/home; mount "$lvpath" /mnt/home || die "mount failed"; P_HOME="$lvpath" ;;
            /boot)
                mkdir -p /mnt/boot; mount "$lvpath" /mnt/boot || die "mount failed"; P_BOOT="$lvpath" ;;
            /efi|/boot/efi)
                mkdir -p /mnt/boot/efi; mount "$lvpath" /mnt/boot/efi || die "mount failed"; P_EFI="$lvpath" ;;
            /data*|/srv|/opt)
                mkdir -p "/mnt${mnt}"; mount "$lvpath" "/mnt${mnt}" || die "mount failed" ;;
            none) ;; # skip
            *)
                mkdir -p "/mnt${mnt}"; mount "$lvpath" "/mnt${mnt}" || die "mount failed" ;;
        esac
    }

    if [[ -n "$root_index" ]]; then
        format_and_mount_lv "$root_index"
    fi
    for i in "${!LV_NAMES[@]}"; do
        [[ -n "$root_index" && "$i" -eq "$root_index" ]] && continue
        format_and_mount_lv "$i"
    done

    # store common globals for post-install step
    export LVM_VG_NAME="$VGNAME"
    export LVM_ROOT_LV_NAME="${LVM_ROOT_LV_NAME:-}"
    export LUKS_MAPPER_NAME="${LUKS_MAPPER_NAME:-}" # Cleaned up variable usage
    export LUKS_PART_UUID="${LUKS_PART_UUID:-}" # Cleaned up variable usage
    export ENCRYPTION_ENABLED="${ENCRYPTION_ENABLED:-0}"
    export PART_BOOT="${PART_BOOT:-}"
    export PART_LUKS="${PART_LUKS:-}" # Cleaned up variable usage

    echo "→ Completed LUKS+LVM route for $DEV"
    return 
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
    echo "→ Running LUKS+LVM post-install steps..."

    # Mount boot/EFI if not already mounted (the route function formats/mounts LVs but we might need to mount disk boot)
    if [[ "$MODE" == "UEFI" && -n "$PART_BOOT" ]]; then
        mkdir -p /mnt/boot/efi
        mount "$PART_BOOT" /mnt/boot/efi || die "Failed to mount $PART_BOOT on /mnt/boot/efi"
    elif [[ "$MODE" == "BIOS" && -n "$PART_BOOT" ]]; then
        mkdir -p /mnt/boot
        mount "$PART_BOOT" /mnt/boot || die "Failed to mount $PART_BOOT on /mnt/boot"
    fi

    # If LUKS used, write crypttab inside target using UUID
    if [[ "${ENCRYPTION_ENABLED:-0}" -eq 1 && -n "${LUKS_PART_UUID:-}" && -n "${LUKS_MAPPER_NAME:-}" ]]; then
        mkdir -p /mnt/etc
        echo "${LUKS_MAPPER_NAME} UUID=${LUKS_PART_UUID} none luks" > /mnt/etc/crypttab
        echo "→ Wrote /mnt/etc/crypttab"
    fi

    # install base system (pacstrap/pacstrap wrapper)
    install_base_system || die "install_base_system failed"

    # generate /etc/fstab
    genfstab -U /mnt > /mnt/etc/fstab || die "genfstab failed"
    echo "→ /mnt/etc/fstab:"
    sed -n '1,200p' /mnt/etc/fstab

    # ensure fs support and mkinitcpio hooks inside target
    ensure_fs_support_for_luks_lvm "${ENCRYPTION_ENABLED:-0}" || die "ensure_fs_support_for_luks_lvm failed"

    # chroot-level configuration
    configure_system || die "configure_system failed"

    # install grub in chroot
    install_grub || die "install_grub failed"

    network_mirror_selection
    gpu_driver
    window_manager
    lm_dm
    extra_pacman_pkg
    optional_aur
    hyprland_theme
    
    echo "→ LUKS+LVM post-install done."
}
#=========================================================================================================================================#
# Main menu
#=========================================================================================================================================#
menu() {
clear
logo
            echo -e "#==================================================#"
            echo -e "#     Select partitioning method for $DEV:         #"
            echo -e "#==================================================#"
            echo -e "|-1) Quick Partitioning  (automated, ext4, btrfs)  |"
            echo -e "|--------------------------------------------------|"
            echo -e "|-2) Custom Partitioning (FS:ext4,btrfs,f2fs,xfs)  |"
            echo -e "|--------------------------------------------------|"
            echo -e "|-3) Lvm & Luks Partitioning                       |"
            echo -e "|--------------------------------------------------|"
            echo -e "|-4) Exit                                          |"
            echo -e "#==================================================#"
            read -rp "Enter choice [1-4]: " INSTALL_MODE
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
echo -e "#===================================================================================================#"
echo -e "# - Cleanup postinstall script & Final Messages & Instructions                                      #"
echo -e "#===================================================================================================#"
echo
echo 
echo -e "Custom package installation phase complete."
echo -e "You can later add more software manually or extend these lists:"
echo -e "  - EXTRA_PKGS[] for pacman packages"
echo -e "  - AUR_PKGS[] for AUR software"
echo -e " ----------------------------------------------------------------------------------------------------"
echo -e "You can now unmount and reboot:"
echo -e "  umount -R /mnt"
echo -e "  swapoff ${P_SWAP} || true" # Changed from P3 to P_SWAP for consistency
echo -e "  reboot"
#Cleanup postinstall script
rm -f /mnt/root/postinstall.sh
#Final messages & instructions
echo
echo -e "Installation base and basic configuration finished."
echo -e "To reboot into your new system:"
echo -e "  umount -R /mnt"
echo -e "  swapoff ${P_SWAP} || true" # Changed from P3 to P_SWAP for consistency
echo -e "  reboot"
echo
echo -e "Done."
echo -e "#===========================================================================#"
echo -e "# -GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88             #"
echo -e "# -Author  : Terra88                                                        #"
echo -e "# -GitHub  : http://github.com/Terra88                                      #"
echo -e "#===========================================================================#"
