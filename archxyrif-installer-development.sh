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

}
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
BIOS_BOOT_PART_CREATED=false
SWAP_SIZE_MIB=0
SWAP_ON=""
ROOT_FS=""
HOME_FS=""
ROOT_SIZE_MIB=0
HOME_SIZE_MIB=0
EFI_SIZE_MIB=1024
BIOS_BOOT_SIZE_MIB=512
BOOT_SIZE_MIB=0
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
#========================#
# Helpers
#========================#
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

#===========================================================================#

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

#========================#
# Detect boot mode
#========================#
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

#========================#
# Swap calculation
#========================#
calculate_swap() {
    local ram_kb ram_mib
    ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    ram_mib=$(( (ram_kb + 1023) / 1024 ))
    SWAP_SIZE_MIB=$(( ram_mib <= 8192 ? ram_mib*2 : ram_mib ))
    echo "Detected RAM ${ram_mib} MiB -> swap ${SWAP_SIZE_MIB} MiB"
}

#--------------------------------------#
# Helper: Show filesystem menu
#--------------------------------------#
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

#========================#
# Ask partition sizes
#========================#
ask_partition_sizes() {
    detect_boot_mode
    calculate_swap

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
        [[ "$ROOT_SIZE_GIB" =~ ^[0-9]+$ ]] || { echo "Must be numeric"; continue; }
        ROOT_SIZE_MIB=$(( ROOT_SIZE_GIB * 1024 ))

      if [[ "$MODE" == "UEFI" ]]; then
          reserved_gib=$(( EFI_SIZE_MIB / 1024 ))
      else
          reserved_gib=$(( BIOS_BOOT_SIZE_MIB / 1024 ))
      fi
        REMAINING_HOME_GIB=$(( disk_gib_int - ROOT_SIZE_GIB - SWAP_SIZE_MIB/1024 - reserved_gib - 1 ))
        [[ $REMAINING_HOME_GIB -ge 1 ]] || { echo "Not enough space for home"; continue; }

        read -rp "Enter HOME size in GiB (ENTER for remaining ${REMAINING_HOME_GIB}): " HOME_SIZE_GIB
        HOME_SIZE_GIB="${HOME_SIZE_GIB:-$REMAINING_HOME_GIB}"
        [[ "$HOME_SIZE_GIB" =~ ^[0-9]+$ ]] || { echo "Must be numeric"; continue; }
        HOME_SIZE_MIB=$(( HOME_SIZE_GIB * 1024 ))

        echo "Root ${ROOT_SIZE_GIB} GiB, Home ${HOME_SIZE_GIB} GiB, Swap $((SWAP_SIZE_MIB/1024)) GiB"
        break
    done
}

#=========================================================================================================================================#

#========================#
# Partition disk
#========================#
partition_disk() {
    [[ -z "$DEV" ]] && die "partition_disk(): missing device argument"
    parted -s "$DEV" mklabel gpt || die "Failed to create GPT"

    clear
    echo "#===============================================================================#"
    echo "| Swap On / Off                                                                 |"
    echo "#===============================================================================#"
    echo "| 1) Swap On                                                                    |"
    echo "|-------------------------------------------------------------------------------|"
    echo "| 2) Swap Off                                                                   |"
    echo "| 3) exit                                                                       |"
    echo "#===============================================================================#"
    read -rp "Select filesystem [default=1]: " FS_CHOICE
    SWAP_ON="${SWAP_ON:-1}"
    case "$SWAP_ON" in
        1) SWAP_ON="1"
        ;;
        2) SWAP_ON="2" 
        ;;
        3) = exec "0"
        ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac    


      if [[ "$MODE" == "BIOS" ]]; then
                    # BIOS partitions
                    if [[ "$SWAP_ON" == "1" ]]; then
                    
                    parted -s "$DEV" mkpart primary 1MiB $((1+BIOS_BOOT_SIZE_MIB))MiB
                    parted -s "$DEV" set 1 bios_grub on
                    local boot_start=$((1+BIOS_BOOT_SIZE_MIB))
                    local boot_end=$((boot_start+BOOT_SIZE_MIB))
                    parted -s "$DEV" mkpart primary fat32 ${boot_start}MiB ${boot_end}MiB
                    local swap_start=$boot_end
                    local swap_end=$((swap_start+SWAP_SIZE_MIB))
                    parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB
                    local root_start=$swap_end
                    local root_end=$((root_start+ROOT_SIZE_MIB))
                    parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB
                    parted -s "$DEV" mkpart primary "$HOME_FS" ${root_end}MiB 100%
                    
                    else 
               
                    parted -s "$DEV" mkpart primary 1MiB $((1+BIOS_BOOT_SIZE_MIB))MiB
                    parted -s "$DEV" set 1 bios_grub on
                    local boot_start=$((1+BIOS_BOOT_SIZE_MIB))
                    local boot_end=$((boot_start+BOOT_SIZE_MIB))
                    parted -s "$DEV" mkpart primary fat32 ${boot_start}MiB ${boot_end}MiB
                    local root_start=$boot_end
                    local root_end=$((root_start+ROOT_SIZE_MIB))
                    parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB
                    parted -s "$DEV" mkpart primary "$HOME_FS" ${root_end}MiB 100%
   
                        partprobe "$DEV" || true
                        udevadm settle --timeout=5 || true
                        echo "✅ Partitioning completed. Verify with lsblk."
                    fi
       else

              if [[ "$SWAP_ON" == "1" ]]; then
                 # UEFI partitions
                 parted -s "$DEV" mkpart primary fat32 1MiB $((1+EFI_SIZE_MIB))MiB
                 parted -s "$DEV" set 1 boot on
                 local root_start=$((1+EFI_SIZE_MIB))
                 local root_end=$((root_start+ROOT_SIZE_MIB))
                 parted -s "$DEV" mkpart primary "$ROOT_FS" ${root_start}MiB ${root_end}MiB
                 local swap_start=$root_end
                 local swap_end=$((swap_start+SWAP_SIZE_MIB))
                 parted -s "$DEV" mkpart primary linux-swap ${swap_start}MiB ${swap_end}MiB
                 parted -s "$DEV" mkpart primary "$HOME_FS" ${swap_end}MiB 100%
                 
               else

                 parted -s "$DEV" mkpart primary fat32 1MiB $((1+EFI_SIZE_MIB))MiB
                 parted -s "$DEV" set 1 boot on
                 local root_start=$((1+EFI_SIZE_MIB))
                 local root_end=$((root_start+ROOT_SIZE_MIB))
                 parted -s "$DEV" mkpart primary "$HOME_FS" ${root_end}MiB 100%

       fi

    partprobe "$DEV" || true
    udevadm settle --timeout=5 || true
    echo "✅ Partitioning completed. Verify with lsblk."
}

#======================================================================================================================#

#========================#
# Format & mount
#========================#
format_and_mount() {
    local ps
    ps=$(part_suffix "$DEV")

    if [[ "$MODE" == "BIOS" ]]; then
        P_BIOS="${DEV}${ps}1"
        P_BOOT="${DEV}${ps}2"
        P_SWAP="${DEV}${ps}3"
        P_ROOT="${DEV}${ps}4"
        P_HOME="${DEV}${ps}5"
        mkfs.ext4 -L boot "$P_BOOT"
    else
        P_EFI="${DEV}${ps}1"
        P_ROOT="${DEV}${ps}2"
        P_SWAP="${DEV}${ps}3"
        P_HOME="${DEV}${ps}4"
        mkfs.fat -F32 "$P_EFI"
    fi

    mkswap -L swap "$P_SWAP"
    swapon "$P_SWAP"

    mkfs.btrfs -f -L root "$P_ROOT"
    mkfs.ext4 -L home "$P_HOME"

    mount "$P_ROOT" /mnt
    if [[ "$ROOT_FS" == "btrfs" ]]; then
        btrfs subvolume create /mnt/@
        btrfs subvolume create /mnt/@home
        umount /mnt
        mount -o subvol=@,noatime,compress=zstd "$P_ROOT" /mnt
        mkdir -p /mnt/home
        mount -o subvol=@home "$P_ROOT" /mnt/home
    else
        mount "$P_ROOT" /mnt
        mkdir -p /mnt/home
        mount "$P_HOME" /mnt/home
    fi

    mkdir -p /mnt/boot
    if [[ "$MODE" == "BIOS" ]]; then
        mount "$P_BOOT" /mnt/boot
    else
        mkdir -p /mnt/boot/efi
        mount "$P_EFI" /mnt/boot/efi
    fi

    echo "✅ Partitions formatted and mounted under /mnt."
}

#========================#
# Install base system
#========================#
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
          mount "$P_EFI" /mnt/boot/efi # Use global variable P_EFI
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

#=========================================================================================================================================#

configure_system() {

#========================#
# Configure system
#========================#
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

cat > /mnt/root/postinstall.sh <<EOF
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
echo "#=======================================================#"
echo " Set password for user '$NEWUSER'                       #"
echo "#=======================================================#"
useradd -m -G wheel -s /bin/bash "${NEWUSER}"
echo "Set password for user ${NEWUSER}:"
passwd "${NEWUSER}"
#========================================================#
clear
# Root password
echo
echo "#========================================================#"
echo " Set ROOT password                                       #"
echo "#========================================================#"
passwd
echo" #========================================================#"
echo "# 7) Ensure user has sudo privileges" 
echo "#========================================================#"
# Create sudoers drop-in file (recommended method)
echo "${NEWUSER} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${NEWUSER}
chmod 440 /etc/sudoers.d/${NEWUSER}
#========================================================#
# Give sudo rights
#========================================================#
echo "$NEWUSER ALL=(ALL:ALL) ALL" > /etc/sudoers.d/$NEWUSER
chmod 440 /etc/sudoers.d/$NEWUSER
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
set -e  # restore strict error handling
#========================================================#
# 7) Home directory setup
#========================================================#
HOME_DIR="/home/$NEWUSER"
mkdir -p /home/$NEWUSER
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
#-------------------INJECTS VARIABLES INTO /mnt/root/postinstall.sh-------------------------------------------------#
# Replace placeholders with actual values (safe substitution)
sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh

    chmod +x /mnt/root/postinstall.sh
    arch-chroot /mnt /root/postinstall.sh
    rm -f /mnt/root/postinstall.sh
    echo "✅ System configured."
#================================================================================================================#
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

#========================#
# Quick Partition Main
#========================#
quick_partition() {
    detect_boot_mode
    echo "Available disks:"
    lsblk -d -o NAME,SIZE,MODEL,TYPE
    while true; do
        read -rp "Enter target disk (e.g. /dev/sda): " DEV
        DEV="/dev/${DEV##*/}"
        [[ -b "$DEV" ]] && break || echo "Invalid device, try again."
    done

    read -rp "This will ERASE all data on $DEV. Continue? [y/N]: " yn
    [[ "$yn" =~ ^[Yy]$ ]] || die "Aborted by user."

    ask_partition_sizes
    select_filesystem
    partition_disk
    format_and_mount
    install_base_system
    configure_system
    install_grub
    

    echo -e "${GREEN}✅ Arch Linux installation complete.${RESET}"
}

#=========================================================================================================================================#

#========================#
# Custom partition (placeholder)
#========================#
custom_partition() {

sleep 1
clear
echo "#===================================================================================================#"
echo "# 1.3) Custom Partition Mode: Selected Drive $DEV                                                   #"
echo "#===================================================================================================#"
echo
    echo "Custom Partition Mode under construction. Restarting..."
    sleep 2
    exec "$0"
}

#=========================================================================================================================================#
#========================#
# Main menu
#========================#
menu() {
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
            read -rp "Enter choice [1-2]: " PART_CHOICE
            case "$PART_CHOICE" in
                1) quick_partition ;;
                2) custom_partition ;;
                3) echo "Exiting..."; exit 0 ;;
                *) echo "Invalid choice"; menu ;;
            esac
}

#========================#
# Entry
#========================#
menu
                  
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
