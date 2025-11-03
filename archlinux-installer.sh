#!/usr/bin/env bash

#MIT License
#Copyright (c) 2025 Terra88

################################################################################
#
# Author  : Terra88 
# Purpose : Arch Linux custom installer
# GitHub  : http://github.com/Terra88
#
################################################################################

set -euo pipefail

################################################################################
# Source variables
################################################################################

################################################################################
# Preparation
################################################################################

# Arch logo: Edited manually by Terra88
# Text generated with : https://textkool.com/en/ascii-art-generator?font=Big&text=Arch%20Installer
echo "====================================================================================================="
echo "
                     @@
                    @##@
                   @####@
                  @######@
                 @########@                                _       _____           _        _ _            
                @##########@               /\            | |     |_   _|         | |      | | |           
               @############@             /  \   _ __ ___| |__     | |  _ __  ___| |_ __ _| | | ___ _ __  
              @##############@           / /\ \ | '__/ __| '_ \    | | | '_ \/ __| __/ _\` | | |/_ \ '__|
             @######@@@@######@         / ____ \| | | (__| | | |  _| |_| | | \__ \ || (_| | | |  __/ |    
            @######@    @######@       /_/    \_\_|  \___|_| |_| |_____|_| |_|___/\__\__,_|_|_|\___|_|   
           @######@      @######@
          @#######@      @#######@
         @#########@    @#########@
        @###@                  @###@
       @###@-                  -@###@ "
echo "====================================================================================================="

loadkeys fi
timedatectl set-ntp true

# archformat.sh
# - shows lsblk and asks which device to use
# - wipes old signatures (sgdisk --zap-all, wipefs -a, dd first sectors)
# - partitions: EFI(1024MiB) | root(~120GiB) | swap(calculated from RAM) | home(rest)
# - creates filesystems: FAT32 on EFI, ext4 on root/home, mkswap on swap
#
# WARNING: destructive. Run as root. Double-check device before continuing.

# Helpers
confirm() {
  # ask Yes/No, return 0 if yes
  local msg="${1:-Continue?}"
  read -r -p "$msg [yes/NO]: " ans
  case "$ans" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

part_suffix() {
  # given /dev/sdX or /dev/nvme0n1, print partition suffix ('' or 'p')
  local dev="$1"
  if [[ "$dev" =~ nvme|mmcblk ]]; then
    echo "p"
  else
    echo ""
  fi
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# 1) Show devices
echo "Available block devices (lsblk):"
lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL

# 2) Ask device
read -r -p $'\nEnter block device to use (example /dev/sda or /dev/nvme0n1): ' DEV
DEV="${DEV:-}"

if [[ -z "$DEV" ]]; then
  die "No device given. Exiting."
fi

if [[ ! -b "$DEV" ]]; then
  die "Device '$DEV' not found or not a block device."
fi

echo
echo "You selected: $DEV"
echo "This will DESTROY ALL DATA on $DEV (partitions, LUKS headers, LVM, etc)."
if ! confirm "Are you absolutely sure you want to wipe and repartition $DEV?"; then
  die "User cancelled."
fi

# 3) Unmount any mounted partitions and swapoff
echo "Attempting to unmount any mounted partitions and disable swap on $DEV..."
mapfile -t MOUNTS < <(lsblk -ln -o NAME,MOUNTPOINT "$DEV" | awk '$2!="" {print $1":"$2}')
for m in "${MOUNTS[@]:-}"; do
  name="${m%%:*}"
  mnt="${m#*:}"
  if [[ -n "$mnt" ]]; then
    echo "  Unmounting /dev/$name from $mnt"
    umount -l "/dev/$name" || true
  fi
done

# swapoff on partitions of this device
for sw in $(cat /proc/swaps | awk 'NR>1 {print $1}'); do
  if [[ "$sw" == "$DEV"* ]]; then
    echo "  Turning off swap on $sw"
    swapoff "$sw" || true
  fi
done

# 4) Clear partition table / LUKS / LVM signatures
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

partprobe "$DEV" || true

# 5) Compute sizes
# EFI: 1024 MiB
EFI_SIZE_MIB=1024

# Root: ~120 GiB -> 120*1024 MiB
ROOT_SIZE_MIB=$((120 * 1024))

# Detect RAM in MiB
ram_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
if [[ -z "$ram_kb" ]]; then
  die "Failed to read RAM from /proc/meminfo"
fi
ram_mib=$(( (ram_kb + 1023) / 1024 ))

# Swap sizing policy:
# - If RAM <= 8192 MiB (8 GiB): swap = 2 * RAM
# - Otherwise swap = RAM (1:1)
if (( ram_mib <= 8192 )); then
  SWAP_SIZE_MIB=$(( ram_mib * 2 ))
else
  SWAP_SIZE_MIB=$(( ram_mib ))
fi

echo
echo "Detected RAM: ${ram_mib} MiB (~$((ram_mib/1024)) GiB)."
echo "Swap will be set to ${SWAP_SIZE_MIB} MiB (~$((SWAP_SIZE_MIB/1024)) GiB)."
echo "Root will be set to ${ROOT_SIZE_MIB} MiB (~120 GiB)."
echo "EFI will be ${EFI_SIZE_MIB} MiB (1024 MiB)."
echo

if ! confirm "Proceed to partition $DEV with the sizes above?"; then
  die "User cancelled."
fi

# 6) Partitioning with parted (using MiB units)
which parted >/dev/null 2>&1 || die "parted required but not found."

echo "Creating GPT label and partitions..."
parted -s "$DEV" mklabel gpt

# Calculate partition boundaries (MiB)
p1_start=1
p1_end=$((p1_start + EFI_SIZE_MIB))         # 1MiB..1024MiB

p2_start=$p1_end                             # root start
p2_end=$((p2_start + ROOT_SIZE_MIB))         # root end

p3_start=$p2_end                             # swap start
p3_end=$((p3_start + SWAP_SIZE_MIB))         # swap end

p4_start=$p3_end                             # home start; end = 100%

# Rounded values to avoid fractional MiB
echo "Partition table (MiB):"
echo "  1) EFI    : ${p1_start}MiB - ${p1_end}MiB (FAT32, boot)"
echo "  2) Root   : ${p2_start}MiB - ${p2_end}MiB (~120GiB, ext4)"
echo "  3) Swap   : ${p3_start}MiB - ${p3_end}MiB (~${SWAP_SIZE_MIB} MiB)"
echo "  4) Home   : ${p4_start}MiB - 100% (ext4)"

# Create partitions
parted -s "$DEV" mkpart primary fat32 "${p1_start}MiB" "${p1_end}MiB"
parted -s "$DEV" mkpart primary ext4 "${p2_start}MiB" "${p2_end}MiB"
parted -s "$DEV" mkpart primary linux-swap "${p3_start}MiB" "${p3_end}MiB"
parted -s "$DEV" mkpart primary ext4 "${p4_start}MiB" 100%

# Set boot flag on partition 1 (UEFI)
parted -s "$DEV" set 1 boot on

# Inform kernel of new partitions
partprobe "$DEV"
sleep 1

# 7) Derive partition names (/dev/sda1 vs /dev/nvme0n1p1)
PSUFF=$(part_suffix "$DEV")
P1="${DEV}${PSUFF}1"
P2="${DEV}${PSUFF}2"
P3="${DEV}${PSUFF}3"
P4="${DEV}${PSUFF}4"

echo "Partitions created:"
lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT "$DEV"

# Wait a bit for device nodes to appear
sleep 1
if [[ ! -b "$P1" || ! -b "$P2" || ! -b "$P3" || ! -b "$P4" ]]; then
  echo "Waiting for partition nodes..."
  sleep 2
fi

# 8) Filesystems
echo "Creating filesystems:"
echo "  EFI -> $P1 (FAT32)"
echo "  Root -> $P2 (ext4)"
echo "  Swap -> $P3 (mkswap)"
echo "  Home -> $P4 (ext4)"

# Format EFI
mkfs.fat -F32 "$P1"

# Format root and home
mkfs.ext4 -F "$P2"
mkfs.ext4 -F "$P4"

# Setup swap
mkswap "$P3"
# Optionally enable swap now (comment/uncomment as needed)
# swapon "$P3"

# ---------------------------
# Continue: mount / pacstrap / arch-chroot / mkinitcpio / grub
# Assumes P1,P2,P3,P4 defined as in previous script
# ---------------------------

set -euo pipefail

# Sanity check: ensure partitions exist
for p in "$P1" "$P2" "$P3" "$P4"; do
  if [[ ! -b "$p" ]]; then
    echo "ERROR: Partition $p not found. Aborting." >&2
    exit 1
  fi
done

# 1) Mount root and other partitions
echo "Mounting partitions..."
mount "$P2" /mnt
mkdir -p /mnt/boot
mount "$P1" /mnt/boot
mkdir -p /mnt/home
mount "$P4" /mnt/home

# Enable swap now (so pacstrap has more headroom if needed)
echo "Enabling swap on $P3..."
swapon "$P3" || echo "Warning: failed to enable swap (proceeding)"

# 2) Pacstrap: base system + recommended packages for basic use
# You can modify the package list below as needed.
PKGS=(
  base
  base-devel
  git
  grub
  linux
  linux-firmware
  linux-zen
  linux-headers
  vim
  sudo
  nano
  networkmanager
  efibootmgr
  openssh
  intel-ucode
  amd-ucode
  btrfs-progs     # optional, keep or remove
)

echo "Installing base system packages: ${PKGS[*]}"
pacstrap /mnt "${PKGS[@]}"

# 3) Generate fstab
echo "Generating /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# 4) Basic variables for chroot steps (defaults provided)
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

set -euo pipefail

# 6) Inject variables into /mnt/root/postinstall.sh
# Replace placeholders with actual values (safe substitution)
sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh

# Make the script executable
chmod +x /mnt/root/postinstall.sh

# 7) chroot and run postinstall.sh
echo "Entering chroot to run configuration (this will prompt for root and user passwords)..."
arch-chroot /mnt /root/postinstall.sh

# ---------------------------
# Extra packages installation (official + AUR)
# ---------------------------

# Define the lists below — edit as you like
EXTRA_PKGS=(
    blueman
    bluez
    bluez-utils
    dolphin
    dolphin-plugins
    dunst
    git
    gdm
    grim
    grub
    htop
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprshot
    kitty
    nano
    network-manager-applet
    networkmanager
    polkit-kde-agent
    qt5-wayland
    qt6-wayland
    unzip
    uwsm
    rofi
    slurp
    vim
    wget
    wofi
    nftables
    waybar
    wine-staging
    wine-gecko
    wine-mono
    winetricks
    archlinux-xdg-menu
    ark
    bemenu-wayland
    breeze
    brightnessctl
    btop
    cliphist
    cpupower
    discord
    discover
    efibootmgr
    evtest
    firefox
    flatpak
    gamemode
    goverlay
    gst-libav
    gst-plugin-pipewire
    gst-plugins-bad
    gst-plugins-base
    gst-plugins-good
    gst-plugins-ugly
    iwd
    kate
    konsole
    kvantum
    libpulse
    linuxconsole
    lutris
    mangohud
    nvtop
    nwg-displays
    nwg-look
    otf-font-awesome
    pavucontrol
    pipewire
    pipewire-alsa
    pipewire-jack
    pipewire-pulse
    qbittorrent
    qt5ct
    smartmontools
    steam
    sway
    thermald
    ttf-hack
    vlc-plugin-ffmpeg
    vlc-plugins-all
    vulkan-radeon
    wireless_tools
    wireplumber
    wl-clipboard
    xdg-desktop-portal-wlr
    xdg-utils
    xf86-video-amdgpu
    xf86-video-ati
    xorg-server
    xorg-xinit
    zram-generator
    base-devel  # needed for AUR building
)

AUR_PKGS=(
hyprland-protocols-git
hyprlang-git
hyprlang-git-debug 
hyprutils-git 
hyprutils-git-debug 
hyprwayland-scanner-git 
hyprwayland-scanner-git-debug 
kvantum-theme-catppuccin-git 
obs-studio-git 
proton-ge-custom-bin 
protonup-qt 
python-inputs 
python-steam 
python-vdf 
qt6ct-kde 
wlogout 
wlrobs-hg 
xdg-desktop-portal-hyprland-git 
xdg-desktop-portal-hyprland-git-debug
)

# Optional prompt
echo
read -r -p "Install extra official packages (pacman) now? [y/N]: " install_extra
if [[ "$install_extra" =~ ^[Yy]$ ]]; then
  echo "Installing extra packages inside chroot..."
  arch-chroot /mnt pacman -Syu --noconfirm "${EXTRA_PKGS[@]}"
fi

read -r -p "Install AUR packages (requires paru)? [y/N]: " install_aur
if [[ "$install_aur" =~ ^[Yy]$ ]]; then
  echo "Setting up yay AUR helper inside chroot..."

  # Create a postinstall script for AUR setup inside chroot
  cat > /mnt/root/install_aur.sh <<'AURINSTALL'
#!/usr/bin/env bash
set -euo pipefail

# Variables injected by outer script
NEWUSER="{{NEWUSER}}"

# 1) Switch to new user (non-root) to build AUR packages
#    Paru is used as AUR helper. You can switch to yay if preferred.

sudo -u "${NEWUSER}" bash <<'INNER'
set -euo pipefail
cd ~
if ! command -v yay >/dev/null 2>&1; then
  echo "Installing yay..."
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
fi

# Now install your AUR packages
AUR_PKGS=({{AUR_PKGS}})
yay -S --noconfirm --needed "${AUR_PKGS[@]}"
INNER
AURINSTALL

  # Inject variables (username and AUR package list)
  sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/install_aur.sh
  sed -i "s|{{AUR_PKGS}}|${AUR_PKGS[*]}|g" /mnt/root/install_aur.sh

  chmod +x /mnt/root/install_aur.sh

  echo "Running AUR installation inside chroot..."
  arch-chroot /mnt /root/install_aur.sh

  rm -f /mnt/root/install_aur.sh
fi

echo
echo "Custom package installation phase complete."
echo "You can later add more software manually or extend these lists:"
echo "  - EXTRA_PKGS[] for pacman packages"
echo "  - AUR_PKGS[] for AUR software"
echo
echo "Full base + extras installation is complete."
echo "You can now unmount and reboot:"
echo "  umount -R /mnt"
echo "  swapoff ${P3} || true"
e
cho "  reboot"

# 8) Cleanup postinstall script
rm -f /mnt/root/postinstall.sh

# 9) Install GRUB for UEFI / BIOS
# EFI partition is expected to be mounted on /boot (as done before chroot)
#echo "Installing GRUB (UEFI)..."
#arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
#arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

Install GRUB Bootloader
 Check for UEFI or BIOS boot mode

if [[ -d /sys/firmware/efi ]]; then
   UEFI Mode
  echo "UEFI boot detected. Installing GRUB for UEFI..."
  
  Ensure EFI partition is mounted at /mnt/boot
  mkdir -p /mnt/boot
  mount "$P1" /mnt/boot
  
  Install GRUB for UEFI
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  
else
  BIOS Mode
  echo "BIOS boot detected. Installing GRUB for BIOS..."
  
  Install GRUB for BIOS
  arch-chroot /mnt grub-install --target=i386-pc --recheck --bootloader-id=GRUB "$DEV"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi
done
# Ensure EFI partition is mounted at /mnt/boot
#mkdir -p /mnt/boot
#mount "$P1" /mnt/boot

# Install GRUB for UEFI
#arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
#arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Prompt for passwords (will be set inside chroot)
#echo "You will be asked to enter the root and the new user's passwords inside the chroot."
#echo

# 10) Create an inline script for arch-chroot operations
cat > /mnt/root/postinstall.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# This script runs inside the new system (chroot). Variables are injected from the outer script.
# It will:
#  - set timezone and hwclock
#  - generate locales
#  - set hostname and /etc/hosts
#  - install and configure GRUB (UEFI)
#  - generate initramfs
#  - enable NetworkManager and sshd
#  - create a user, add to wheel group and enable sudo for wheel

# Replace placeholders injected by outer script
TZ="{{TIMEZONE}}"
LANG_LOCALE="{{LANG_LOCALE}}"
HOSTNAME="{{HOSTNAME}}"
NEWUSER="{{NEWUSER}}"

# 1) Timezone
ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
hwclock --systohc

# 2) Locale
if ! grep -q "^${LANG_LOCALE} UTF-8" /etc/locale.gen 2>/dev/null; then
  echo "${LANG_LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LANG_LOCALE}" > /etc/locale.conf

# 3) Hostname and hosts
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# 4) Initramfs
# Use mkinitcpio -P to rebuild all preset kernels
mkinitcpio -P

# 5) Set root password (prompt)
echo "Set root password:"
passwd

# 6) Create user and set password
useradd -m -G wheel -s /bin/bash "${NEWUSER}"
echo "Set password for user ${NEWUSER}:"
passwd "${NEWUSER}"

# 7) Enable wheel sudo (uncomment %wheel line)
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers || true

# 8) Enable basic services
systemctl enable NetworkManager
systemctl enable sshd

#====================================================================================================================================
# 9) Install GRUB for UEFI / BIOS
# EFI partition is expected to be mounted on /boot (as done before chroot)
#echo "Installing GRUB (UEFI)..."
#arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
#arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

Install GRUB Bootloader
 Check for UEFI or BIOS boot mode

if [[ -d /sys/firmware/efi ]]; then
   UEFI Mode
  echo "UEFI boot detected. Installing GRUB for UEFI..."
  
  Ensure EFI partition is mounted at /mnt/boot
  mkdir -p /mnt/boot
  mount "$P1" /mnt/boot
  
  Install GRUB for UEFI
  arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --recheck
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
  
else
  BIOS Mode
  echo "BIOS boot detected. Installing GRUB for BIOS..."
  
  Install GRUB for BIOS
  arch-chroot /mnt grub-install --target=i386-pc --recheck --bootloader-id=GRUB "$DEV"
  arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi
done
#======================================================================================================================================
echo "Postinstall inside chroot finished."
EOF

# 9) Final messages & instructions
echo
echo "Installation base and basic configuration finished."
echo "Suggested next steps:"
echo "  - If you mounted extra disks, add them to /etc/fstab inside the new system."
echo "  - Install any additional packages (e.g. desktop environment, display manager)."
echo
echo "To reboot into your new system:"
echo "  umount -R /mnt"
echo "  swapoff ${P3} || true"
echo "  reboot"
echo
echo "Done."

