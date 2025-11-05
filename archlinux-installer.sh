#!/usr/bin/env bash
#===========================================================================
#MIT License
#Copyright (c) 2025 Terra88
#===========================================================================
#===========================================================================
# Author  : Terra88 
# Purpose : Arch Linux custom installer
# GitHub  : http://github.com/Terra88
#===========================================================================
#===========================================================================
# Source variables
#===========================================================================
set -euo pipefail
#===========================================================================
# Preparation
#===========================================================================
# Arch logo: Edited manually by Terra88
#===========================================================================
echo "====================================================================================================="
echo "====================================================================================================="
echo "                
                    @@@@
                   @####@
                  @######@
                 @########@                               _       _____           _        _ _            
                @##########@               /\            | |     |_   _|         | |      | | |           
               @############@             /  \   _ __ ___| |__     | |  _ __  ___| |_ __ _| | | ___ _ __  
              @##############@           / /\ \ | '__/ __| '_ \    | | | '_ \/ __| __/ _\` | | |/_ \ '__|
             @######@@@@######@         / ____ \| | | (__| | | |  _| |_| | | \__ \ || (_| | | |  __/ |    
            @######@    @######@       /_/    \_\_|  \___|_| |_| |_____|_| |_|___/\__\__,_|_|_|\___|_|   
           @######@      @######@      =================================================================
          @######@        @######@
         @######@==========@######@     -MIT License-Copyright (c) 2025 Terra88
        @####@-              -@####@
       @###@-                  -@###@ "
echo "====================================================================================================="       
echo "====================================================================================================="

loadkeys fi
timedatectl set-ntp true

#===================================================================================================#
# 0) Disk Format INFO
#===================================================================================================#
# archformat.sh
# - shows lsblk and asks which device to use
# - wipes old signatures (sgdisk --zap-all, wipefs -a, dd first sectors)
# - partitions: EFI(1024MiB) | root(~120GiB) | swap(calculated from RAM) | home(rest)
# - creates filesystems: FAT32 on EFI, ext4 on root/home, mkswap on swap
#
# WARNING: destructive. Run as root. Double-check device before continuing.
#===================================================================================================#
# 1) Disk Selection & Format
#===================================================================================================#

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

# Show devices
echo "Available block devices (lsblk):"
lsblk -p -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL

# Ask device
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

# Unmount any mounted partitions and swapoff
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

#===================================================================================================#
# 1.1) Clearing Partition Tables / Luks / LVM Signatures
#===================================================================================================#

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

#===================================================================================================#
# 1.2) Re-Partitioning Selected Drive
#===================================================================================================#

partprobe "$DEV" || true

# Compute sizes
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

# Partitioning with parted (using MiB units)
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

# Derive partition names (/dev/sda1 vs /dev/nvme0n1p1)
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

#===================================================================================================#
# 1.3) Mounting Created Partitions
#===================================================================================================#

# Filesystems
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

#===================================================================================================#
# 1.4) Set up swap # Optionally set swap on (comment/uncomment swapon "$Partition" as needed) - might req tinkering
#===================================================================================================#
mkswap "$P3"
swapon "$P3"

# Sanity check: ensure partitions exist
for p in "$P1" "$P2" "$P3" "$P4"; do
  if [[ ! -b "$p" ]]; then
    echo "ERROR: Partition $p not found. Aborting." >&2
    exit 1
  fi
done

#Mount root and other partitions
echo "Mounting partitions..."
mount "$P2" /mnt
mkdir -p /mnt/boot
mount "$P1" /mnt/boot
mkdir -p /mnt/home
mount "$P4" /mnt/home

# Enable swap now (so pacstrap has more headroom if needed)
echo "Enabling swap on $P3..."
swapon "$P3" || echo "Warning: failed to enable swap (proceeding)"

#===================================================================================================#
# 2) Pacstrap: Installing Base system + recommended packages for basic use
#===================================================================================================#
# You can modify the package list below as needed.

PKGS=(
  base
  base-devel
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
  btrfs-progs     # optional, keep or remove
)

echo "Installing base system packages: ${PKGS[*]}"
pacstrap /mnt "${PKGS[@]}"

#===================================================================================================#
# 3) Generating fstab & Showing Partition Table / Mountpoints
#===================================================================================================#

echo "Generating /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Partition Table and Mountpoints:"
cat /mnt/etc/fstab

#===================================================================================================#
# 4) Setting Basic variables for chroot (defaults provided)
#===================================================================================================#

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

#===================================================================================================#
# 5) Installing GRUB for UEFI - Works now!!! (Possible in future: Bios support)
#===================================================================================================#
# EFI partition is expected to be mounted on /boot (as done before chroot)
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


# Grub Troubleshoot if needed - commands are here after install - you can run:
# efibootmgr -v
# ls /boot/efi/EFI/
#-Should Show:
# /boot/efi/EFI/GRUB/grubx64.efi
# /boot/efi/EFI/Boot/BOOTX64.EFI

#===================================================================================================#
# 6) Running chroot and setting mkinitcpio - Setting Hostname, Username, enabling services etc.
#===================================================================================================#
# inline script for arch-chroot operations "postinstall.sh"

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

# 7) Ensure user has sudo privileges
# Create sudoers drop-in file (recommended method)
echo "${NEWUSER} ALL=(ALL:ALL) ALL" > /etc/sudoers.d/${NEWUSER}
chmod 440 /etc/sudoers.d/${NEWUSER}

# 8) Alternatively, enable wheel group sudo rights (optional)
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
# sed -i -E 's/^#?\s*%wheel\s+ALL=\(ALL(:ALL)?\)\s+ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# 9) Enable basic services
systemctl enable NetworkManager
systemctl enable sshd

echo "Postinstall inside chroot finished."
EOF
#===================================================================================================#
# 7) Inject variables into /mnt/root/postinstall.sh
#===================================================================================================#
# Replace placeholders with actual values (safe substitution)

sed -i "s|{{TIMEZONE}}|${TZ}|g" /mnt/root/postinstall.sh
sed -i "s|{{LANG_LOCALE}}|${LANG_LOCALE}|g" /mnt/root/postinstall.sh
sed -i "s|{{HOSTNAME}}|${HOSTNAME}|g" /mnt/root/postinstall.sh
sed -i "s|{{NEWUSER}}|${NEWUSER}|g" /mnt/root/postinstall.sh

# Make the script executable
chmod +x /mnt/root/postinstall.sh

# chroot and run postinstall.sh
echo "Entering chroot to run configuration (this will prompt for root and user passwords)..."
arch-chroot /mnt /root/postinstall.sh

#===================================================================================================#
# 8) Extra Pacman/Aur package lists.
#===================================================================================================#
# Define the lists below — edit as you like

EXTRA_PKGS=(
    blueman
    bluez
    bluez-utils
    dolphin
    dolphin-plugins
    dunst
    gdm
    grim
    htop
    hypridle
    hyprland
    hyprlock
    hyprpaper
    hyprshot
    kitty
    network-manager-applet
    polkit-kde-agent
    qt5-wayland
    qt6-wayland
    unzip
    uwsm
    rofi
    slurp
    wget
    wofi
    nftables
    waybar
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
    qt5ct
    smartmontools
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
hyprutils-git
hyprwayland-scanner-git
kvantum-theme-catppuccin-git
obs-studio-git
proton-ge-custom
protonup-qt
python-inputs
python-steam
python-vdf
qt6ct-kde
wlogout
wlrobs-hg
xdg-desktop-portal-hyprland-git
)

#===================================================================================================#
# 9) Installing extra Pacman and AUR packages
#===================================================================================================#

echo
read -r -p "Install extra official packages (pacman) now? [y/N]: " install_extra
read -r -p "Install AUR packages (requires yay)? [y/N]: " install_aur

# Convert Y/N to numeric flags
INSTALL_EXTRA=0
INSTALL_AUR=0
[[ "$install_extra" =~ ^[Yy]$ ]] && INSTALL_EXTRA=1
[[ "$install_aur" =~ ^[Yy]$ ]] && INSTALL_AUR=1

# Skip everything if both are no
if [[ $INSTALL_EXTRA -eq 0 && $INSTALL_AUR -eq 0 ]]; then
    echo "Skipping extra package installation."
else
    echo ">>> Preparing extra package installation inside chroot..."

    # -------------------------------
    # 1) Pacman packages
    # -------------------------------
    if [[ $INSTALL_EXTRA -eq 1 && ${#EXTRA_PKGS[@]} -gt 0 ]]; then
        echo "Installing extra official packages: ${EXTRA_PKGS[*]}"
        arch-chroot /mnt pacman -Sy --noconfirm
        arch-chroot /mnt pacman -S --needed --noconfirm "${EXTRA_PKGS[@]}"
    else
        echo "Skipping extra official packages..."
    fi

    # -------------------------------
    # 2)Prepare AUR build environment inside chroot
    # -------------------------------
    echo "→ Preparing environment for AUR builds..."
    arch-chroot /mnt pacman -S --needed --noconfirm base-devel git meson ninja cmake wayland-protocols pkgconf mercurial
    cp -L /etc/resolv.conf /mnt/etc/resolv.conf
    arch-chroot /mnt pacman-key --init || true
    arch-chroot /mnt pacman-key --populate archlinux || true
    arch-chroot /mnt swapon -a || true
    arch-chroot /mnt bash -c 'echo "MAKEFLAGS=\"-j$(nproc)\"" >> /etc/makepkg.conf'
    
    # -------------------------------
    # 3) AUR packages (Installer)
    # -------------------------------
   if [[ $INSTALL_AUR -eq 1 && ${#AUR_PKGS[@]} -gt 0 ]]; then
        echo "Installing AUR packages via yay (with logging and retries)..."
    
            arch-chroot /mnt runuser -u "$NEWUSER" -- bash -c '
            set -euo pipefail
            LOGFILE="$HOME/aur-install.log"
            mkdir -p "$(dirname "$LOGFILE")"
            touch "$LOGFILE"
    
            echo "==============================" | tee -a "$LOGFILE"
            echo " AUR installation started: $(date)" | tee -a "$LOGFILE"
            echo "==============================" | tee -a "$LOGFILE"
    
            # Ensure yay exists
            if ! command -v yay >/dev/null 2>&1; then
                echo "Installing yay AUR helper..." | tee -a "$LOGFILE"
                cd ~
                git clone https://aur.archlinux.org/yay.git >>"$LOGFILE" 2>&1
                cd yay
                makepkg -si --noconfirm --skippgpcheck >>"$LOGFILE" 2>&1
                cd ..
                rm -rf yay
            fi
    
            # Refresh AUR DB
            yay -Y --gendb >>"$LOGFILE" 2>&1
            yay -Syu --devel --noconfirm >>"$LOGFILE" 2>&1
    
            # Package install loop with retries
            RETRIES=2
            for pkg in '"${AUR_PKGS[@]}"'; do
                echo -e "\n→ Installing $pkg ..." | tee -a "$LOGFILE"
                attempt=1
                success=0
                while (( attempt <= RETRIES )); do
                    if yay -S --needed --noconfirm --mflags "--skippgpcheck" "$pkg" >>"$LOGFILE" 2>&1; then
                        echo "✅ $pkg installed successfully (attempt $attempt)" | tee -a "$LOGFILE"
                        success=1
                        break
                    else
                        echo "⚠️  $pkg failed (attempt $attempt)" | tee -a "$LOGFILE"
                        sleep 3
                    fi
                    ((attempt++))
                done
                if (( success == 0 )); then
                    echo "❌ $pkg failed to install after $RETRIES attempts" | tee -a "$LOGFILE"
                fi
            done
            
            echo -e "\n==============================" | tee -a "$LOGFILE"
            echo " AUR installation completed: $(date)" | tee -a "$LOGFILE"
            echo " Logs saved to $LOGFILE"
            
        '
        
        echo "✅ AUR package installation (with logging) completed."
    else
        echo "Skipping AUR packages..."
   fi
      # Copy AUR install log to host root for inspection
      if [[ -f /mnt/home/$NEWUSER/aur-install.log ]]; then
      cp "/mnt/home/$NEWUSER/aur-install.log" /root/aur-install.log
      echo "📋 Copied AUR log to /root/aur-install.log for review."
      fi
fi   
echo
echo "▶ Extra installation phase finished."

#===================================================================================================#
# 10) GUI Setup: Enable Display/Login Manager if available
#===================================================================================================#

echo
echo "Checking for installed graphical login managers..."

    # List of common display managers
    DISPLAY_MANAGERS=(
      gdm
      sddm
      lightdm
      lxdm
      ly
    )
    
    # Detect which one exists in chroot and enable it
    ENABLED_DM=""
    for dm in "${DISPLAY_MANAGERS[@]}"; do
      if arch-chroot /mnt bash -c "command -v ${dm}" >/dev/null 2>&1; then
        echo "→ Found display manager: ${dm}"
        echo "→ Enabling ${dm}..."
        arch-chroot /mnt systemctl enable "${dm}.service" || true
        ENABLED_DM="${dm}"
        break
      fi
    done
    
    if [[ -n "$ENABLED_DM" ]]; then
      echo "✅ Display manager '${ENABLED_DM}' enabled. It will start automatically on boot."
    else
      echo "⚠️ No known display manager (GDM/SDDM/LightDM/etc.) was found installed."
      echo "   You can install and enable one manually after reboot, for example:"
      echo "     pacman -S sddm && systemctl enable sddm"
    fi
    
    echo
    echo "GUI setup step complete."
    
    # Optional: set Hyprland as default session if present
    if arch-chroot /mnt bash -c "command -v hyprland" >/dev/null 2>&1; then
      echo "→ Hyprland detected. Ensuring XDG session file exists..."
      arch-chroot /mnt bash -c 'mkdir -p /usr/share/wayland-sessions && \
        cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
    [Desktop Entry]
    Name=Hyprland
    Comment=Dynamic tiling Wayland compositor
    Exec=Hyprland
    Type=Application
    EOF'
    fi

#===================================================================================================#
# 11 Hyprland - Configs / Theme downloader
#===================================================================================================#

#===================================================================================================#
# 13 Cleanup postinstall script & Final Messages & Instructions - Not Finished
#===================================================================================================#
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
echo "  reboot"

#Cleanup postinstall script
rm -f /mnt/root/postinstall.sh

#Final messages & instructions
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
