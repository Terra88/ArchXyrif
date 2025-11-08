#!/usr/bin/env bash
#===========================================================================
#GNU GENERAL PUBLIC LICENSE Version 3License - Copyright (c) Terra88
#
#===========================================================================
#===========================================================================
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
loadkeys fi
timedatectl set-ntp true
echo "▄▖▌     ▄▖      ▗   ▖  ▖      ▜ ▘▗ ▌    "
echo "▐ ▛▌█▌  ▌ ▛▘█▌▀▌▜▘  ▛▖▞▌▛▌▛▌▛▌▐ ▌▜▘▛▌▖  "
echo "▐ ▌▌▙▖  ▙▌▌ ▙▖█▌▐▖  ▌▝ ▌▙▌▌▌▙▌▐▖▌▐▖▌▌▖  "
echo "#=====================================================================================================#"
echo "                                                                                 "      
echo "       d8888                 888      Y88b   d88P                  d8b  .d888    "        
echo "      d88888                 888       Y88b d88P                   Y8P d88P      "
echo "     d88P888                 888        Y88o88P                        888       "
echo "    d88P 888 888d888 .d8888b 88888b.     Y888P    888  888 888d888 888 888888    "
echo "   d88P  888 888P.  d88P.    888 .88b    d888b    888  888 888P.   888 888       "
echo "  d88P   888 888    888      888  888   d88888b   888  888 888     888 888       "
echo " d8888888888 888    Y88b.    888  888  d88P Y88b  Y88b 888 888     888 888       "
echo "d88P     888 888     .Y8888P 888  888 d88P   Y88b  .Y88888 888     888 888       "
echo "                                                       888                       "        
echo "                                                  Y8b d88P                       "                    
echo "                                                    Y88P                         "  
echo "        Semi-Automated / Interactive - Arch Linux Installer                      "
echo "                                                                                 "
echo "        GNU GENERAL PUBLIC LICENSE Version 3License - Copyright (c) Terra88      "
echo "#=====================================================================================================#"
echo "Table of Contents:               "
echo "---------------------------------"
echo "1)Disk Selection & Format        "
echo "2)Pacstrap:Installing Base system"
echo "3)Generating fstab               "
echo "4)Setting Basic variables        "
echo "5)Installing GRUB for UEFI       "
echo "6)Setting configs/enabling.srv   "
echo "7)Setting Pacman Mirror          "
echo "Optional:                        "
echo "8A)GPU-Guided install            "
echo "8B)Guided Window Manager Install "
echo "8C)Guided Login Manager Install  "   
echo "9)Extra Pacman & AUR PKG Install "
echo "If Hyprland Selected As WM       "
echo "10)Optional Theme install        "
echo
echo "#==================================================================================================#"
echo " 0) Disk Format INFO                                                                                "
echo "#==================================================================================================#"
echo " archformat.sh                                                                                      "
echo " - shows lsblk and asks which device to use                                                         "
echo " - wipes old signatures (sgdisk --zap-all, wipefs -a, dd first sectors)                             "
echo " - partitions: EFI(1024MiB) | root(~100GiB) | swap(2*ram if under 16 and 1* if above) | home(rest)  "
echo " - filesystems: FAT32 on Boot/EFI                                                                   "
echo " - filesystems: ext4: /root /home mkswap=swap |btrfs@mnt @root @home swap|btrfs@root EXT4/home swap "
echo " WARNING: destructive. Run as root. Double-check device before continuing.                          "
echo "#==================================================================================================#"
echo " 1) Disk Selection: Format (Enter device path: example /dev/sda or /dev/nvme0 etc.)                                                                        "
echo "#==================================================================================================#"
echo

#!/usr/bin/env bash
set -euo pipefail

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

echo
echo "#===================================================================================================#"
echo "# 1.3 Choose Partitioning Mode                                                                     #"
echo "#===================================================================================================#"
echo
            echo "Select partitioning method for $DEV:"
            echo "1) Quick Partitioning  (automated, recommended)"
            echo "2) Custom Partitioning (manual, using cfdisk)"
            echo "3) Return back to start"
            echo

            read -rp "Enter choice [1-2, default=1]: " PART_CHOICE
            PART_CHOICE="${PART_CHOICE:-1}"

                case "$PART_CHOICE" in
                    1)
                        quick_partition ;;
                    2)
                        custom_partition ;;
                    3)
                        echo "Invalid choice. Restarting..."
                        exec "$0";;
                    *)
                        echo "Invalid choice."; exec "$0" ;;
                esac


quick_partition() 
            {
echo "#===================================================================================================#"
echo "# 1.4 Quick-Partition Mode:                                                                         "
echo "#===================================================================================================#"

            partprobe "$DEV" || true

            # Get total disk size in MiB
            DISK_SIZE_MIB=$(lsblk -b -dn -o SIZE "$DEV")
            DISK_SIZE_MIB=$(( DISK_SIZE_MIB / 1024 / 1024 ))  # convert bytes → MiB

            # Compute sizes
            # EFI: 1024 MiB
            EFI_SIZE_MIB=1024
            
            while true; do
            echo "Example: 100GB = ~107GiB - Suggest:~45GiB-150GiB"
            read -r -p $'\nEnter ROOT Partition Size in GiB: ' ROOT_SIZE_GIB

            # Validate input: positive integer
            if ! [[ "$ROOT_SIZE_GIB" =~ ^[0-9]+$ ]] || (( ROOT_SIZE_GIB <= 0 )); then
                echo "Invalid input! Enter a positive integer in GiB."
                continue
            fi

            # Convert to MiB
            ROOT_SIZE_MIB=$(( ROOT_SIZE_GIB * 1024 ))

            # Check if it fits on disk
            MIN_REQUIRED_MIB=$(( ROOT_SIZE_MIB + EFI_SIZE_MIB ))
            if (( MIN_REQUIRED_MIB > DISK_SIZE_MIB )); then
                echo "Error: Requested root size + EFI ($MIN_REQUIRED_MIB MiB) exceeds disk size ($DISK_SIZE_MIB MiB)."
                echo "Please enter a smaller value."
                continue
            fi

            # Valid input fits on disk
            break
        done

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
            echo "Root will be set to ${ROOT_SIZE_MIB} MiB (~$ROOT_SIZE_GIB GiB)."
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

            sleep 1
            clear
            echo "#===================================================================================================#"
            echo "# 1.5)SELECT FILESYSTEM                                                                             "
            echo "#===================================================================================================#"
            echo 

            echo "Partition table (MiB):"
            echo "  1) EFI    : ${p1_start}MiB - ${p1_end}MiB (FAT32, boot)"
            echo "  2) Root   : ${p2_start}MiB - ${p2_end}MiB (~100GiB, root)"
            echo "  3) Swap   : ${p3_start}MiB - ${p3_end}MiB (~${SWAP_SIZE_MIB} MiB)"
            echo "  4) Home   : ${p4_start}MiB - 100% (home)"
            echo
            echo "-------------------------------------------"
            echo "Filesystem Partition Options"
            echo "-------------------------------------------"
            echo "1) EXT4"
            echo "   → The classic, reliable Linux filesystem."
            echo "     • Stable and widely supported"
            echo "     • Simple, fast, and easy to recover"
            echo "     • Recommended for most users"
            echo 
            echo "2) BTRFS"
            echo "   → A modern, advanced filesystem with extra features."
            echo "     • Built-in compression and snapshots"
            echo "     • Good for SSDs and frequent backups"
            echo "     • Slightly more complex; better for advanced users"
            echo
            echo "3) BTRFS(root)-EXT4(home)"
            echo "   → A balanced setup combining both worlds."
            echo "     • BTRFS for system (root) — allows snapshots & rollback"
            echo "     • EXT4 for home — simpler and very stable for data"
            echo "     • Recommended if you want snapshots but prefer EXT4 for personal files"
            echo
            read -r -p "Select File System [1-2, default=1]: " DEV_CHOICE
            DEV_CHOICE="${DEV_CHOICE:-1}"

            case "$DEV_CHOICE" in
                1)
                    echo "→ Selected EXT4"
                    parted -s "$DEV" mkpart primary fat32 "${p1_start}MiB" "${p1_end}MiB"
                    parted -s "$DEV" mkpart primary ext4 "${p2_start}MiB" "${p2_end}MiB"
                    parted -s "$DEV" mkpart primary linux-swap "${p3_start}MiB" "${p3_end}MiB"
                    parted -s "$DEV" mkpart primary ext4 "${p4_start}MiB" 100%
                    ;;
                    2)
                    echo "→ Selected BTRFS"
                    parted -s "$DEV" mkpart primary fat32 "${p1_start}MiB" "${p1_end}MiB"
                    parted -s "$DEV" mkpart primary btrfs "${p2_start}MiB" "${p2_end}MiB"
                    parted -s "$DEV" mkpart primary linux-swap "${p3_start}MiB" "${p3_end}MiB"
                    parted -s "$DEV" mkpart primary btrfs "${p4_start}MiB" 100%
                    ;;  
                    3)  
                    echo "→ Selected BTRFS (root) + EXT4 (home)"
                    parted -s "$DEV" mkpart primary fat32 "${p1_start}MiB" "${p1_end}MiB"
                    parted -s "$DEV" mkpart primary btrfs "${p2_start}MiB" "${p2_end}MiB"
                    parted -s "$DEV" mkpart primary linux-swap "${p3_start}MiB" "${p3_end}MiB"
                    parted -s "$DEV" mkpart primary ext4 "${p4_start}MiB" 100%
                    ;;
                        
            esac

            # Set boot flag on partition 1 (UEFI)
            parted -s "$DEV" set 1 boot on
            partprobe "$DEV"
            sleep 1

            # Derive partition names (/dev/sda1 vs /dev/nvme0n1p1)
            PSUFF=$(part_suffix "$DEV")
            P1="${DEV}${PSUFF}1"
            P2="${DEV}${PSUFF}2"
            P3="${DEV}${PSUFF}3"
            P4="${DEV}${PSUFF}4"

            #===================================================================================================#
            # 1.6) Mounting and formatting
            #===================================================================================================#

            if [[ "$DEV_CHOICE" == "2" ]]; then  # BTRFS

                echo "→ Formatting root (P2) as BTRFS..."
                mkfs.btrfs -f "$P2"

                echo "→ Formatting home (P4) as BTRFS..."
                mkfs.btrfs -f "$P4"

                echo "→ Mounting root to create subvolumes..."
                mount "$P2" /mnt

            echo "→ Creating BTRFS subvolumes on root..."
                btrfs subvolume create /mnt/@
                btrfs subvolume create /mnt/@snapshots
                btrfs subvolume create /mnt/@cache
                btrfs subvolume create /mnt/@log

                umount /mnt

                echo "→ Mounting root subvolumes..."
                mount -o noatime,compress=zstd,subvol=@ "$P2" /mnt
                mkdir -p /mnt/{.snapshots,var/cache,var/log,home}

                mount -o noatime,compress=zstd,subvol=@snapshots "$P2" /mnt/.snapshots
                mount -o noatime,compress=zstd,subvol=@cache "$P2" /mnt/var/cache
                mount -o noatime,compress=zstd,subvol=@log "$P2" /mnt/var/log

                echo "→ Mounting separate home partition..."
                mount "$P4" /mnt/home

                echo "→ BTRFS root and home setup complete."

                # EFI
                mkfs.fat -F32 "$P1"
                mkdir -p /mnt/boot
                mount "$P1" /mnt/boot

                # Swap
                mkswap "$P3"
                swapon "$P3"


            elif [[ "$DEV_CHOICE" == "3" ]]; then  # BTRFS root + EXT4 home
                echo "→ Formatting root (P2) as BTRFS..."
                mkfs.btrfs -f "$P2"

                echo "→ Formatting home (P4) as EXT4..."
                mkfs.ext4 -F "$P4"

                echo "→ Mounting root to create subvolumes..."
                mount "$P2" /mnt
                    
                btrfs subvolume create /mnt/@
                btrfs subvolume create /mnt/@snapshots
                btrfs subvolume create /mnt/@cache
                btrfs subvolume create /mnt/@log
                umount /mnt

                echo "→ Mounting root subvolumes..."
                mount -o noatime,compress=zstd,subvol=@ "$P2" /mnt
                mkdir -p /mnt/{.snapshots,var/cache,var/log,home}
                mount -o noatime,compress=zstd,subvol=@snapshots "$P2" /mnt/.snapshots
                mount -o noatime,compress=zstd,subvol=@cache "$P2" /mnt/var/cache
                mount -o noatime,compress=zstd,subvol=@log "$P2" /mnt/var/log

                 echo "→ Mounting separate home partition (EXT4)..."
                 mount "$P4" /mnt/home

                 # Swap
                 mkswap "$P3"
                 swapon "$P3"

                 echo "→ BTRFS root and home setup complete."

                 # EFI
                 mkfs.fat -F32 "$P1"
                 mkdir -p /mnt/boot
                 mount "$P1" /mnt/boot

                echo "→ Mixed setup (BTRFS root + EXT4 home) complete."
                
            else
                # EXT4 path
                echo "Formatting partitions as EXT4..."
                mkfs.ext4 -F "$P2"
                mkfs.ext4 -F "$P4"
                mkfs.fat -F32 "$P1"

                mount "$P2" /mnt
                mkdir -p /mnt/boot /mnt/home
                mount "$P1" /mnt/boot
                mount "$P4" /mnt/home

                # Swap
                mkswap "$P3"
                swapon "$P3"
            fi

            }           
            echo "Partitioning and filesystem setup complete."


custom_partition(){
echo "#===================================================================================================#"
echo "# 1.7)Custom-Partition Mode: Selected Drive  - Still in progress not finished                        "
echo "#===================================================================================================#"

                    partprobe "$DEV" || true

                    echo "→ You chose custom partition mode."
                    echo "→ You will manually partition your drive using cfdisk or parted."
                    echo
                    echo "IMPORTANT:"
                    echo "  - Ensure you create an EFI partition (if using UEFI)."
                    echo "  - Create root (/) and optionally home (/home), swap, etc."
                    echo "  - Do NOT mount anything yet — the script will handle it after setup."
                    echo

                    read -rp "Press Enter to launch cfdisk on $DEV..."
                    cfdisk "$DEV"

                    echo
                    echo "Partitioning complete. Let’s define which partition is which."
                    echo "Example: /dev/nvme0n1p1, /dev/sda2, etc."
                    echo

                    # Ask for partitions
                    read -rp "Enter EFI partition (or leave empty if BIOS): " P1
                    read -rp "Enter ROOT partition (/): " P2
                    read -rp "Enter SWAP partition (or leave empty): " P3
                    read -rp "Enter HOME partition (or leave empty): " P4

                    echo
                    echo "-------------------------------------------"
                    echo "Filesystem Setup Options"
                    echo "-------------------------------------------"
                    echo "1) EXT4"
                    echo "2) BTRFS"
                    echo "3) BTRFS (root) + EXT4 (home)"
                    echo
                    read -rp "Select filesystem layout [1-3, default=1]: " FS_CHOICE
                    FS_CHOICE="${FS_CHOICE:-1}"

                    # Formatting and mounting logic
                    echo
                    echo "Formatting and mounting partitions..."
                    case "$FS_CHOICE" in
                        2)
                            echo "→ Formatting root as BTRFS..."
                            mkfs.btrfs -f "$P2"

                            mount "$P2" /mnt
                            echo "→ Creating BTRFS subvolumes..."
                            btrfs subvolume create /mnt/@
                            btrfs subvolume create /mnt/@snapshots
                            btrfs subvolume create /mnt/@cache
                            btrfs subvolume create /mnt/@log
                            umount /mnt

                            echo "→ Mounting root subvolume..."
                            mount -o noatime,compress=zstd,subvol=@ "$P2" /mnt
                            mkdir -p /mnt/{.snapshots,var/cache,var/log,home}

                            if [[ -n "$P4" ]]; then
                                echo "→ Formatting home as BTRFS..."
                                mkfs.btrfs -f "$P4"
                                mount "$P4" /mnt/home
                            fi
                            ;;
                        3)
                            echo "→ Formatting root as BTRFS..."
                            mkfs.btrfs -f "$P2"
                            echo "→ Formatting home as EXT4..."
                            [[ -n "$P4" ]] && mkfs.ext4 -F "$P4"

                            mount "$P2" /mnt
                            btrfs subvolume create /mnt/@
                            btrfs subvolume create /mnt/@snapshots
                            btrfs subvolume create /mnt/@cache
                            btrfs subvolume create /mnt/@log
                            umount /mnt

                            mount -o noatime,compress=zstd,subvol=@ "$P2" /mnt
                            mkdir -p /mnt/{.snapshots,var/cache,var/log,home}

                            [[ -n "$P4" ]] && mount "$P4" /mnt/home
                            ;;
                        *)
                            echo "→ Formatting root as EXT4..."
                            mkfs.ext4 -F "$P2"
                            mount "$P2" /mnt

                            mkdir -p /mnt/home
                            [[ -n "$P4" ]] && mkfs.ext4 -F "$P4" && mount "$P4" /mnt/home
                            ;;
                    esac

                    # EFI
                    if [[ -n "$P1" ]]; then
                        echo "→ Formatting EFI partition..."
                        mkfs.fat -F32 "$P1"
                        mkdir -p /mnt/boot
                        mount "$P1" /mnt/boot
                    fi

                    # Swap
                    if [[ -n "$P3" ]]; then
                        echo "→ Setting up swap..."
                        mkswap "$P3"
                        swapon "$P3"
                    fi

                    echo
                    echo "Custom partitioning and mounting complete!"

                    }

        



echo "Partitioning and filesystem setup complete."


clear
echo
echo "#===================================================================================================#"
echo "# 2) Pacstrap: Installing Base system + recommended packages for basic use                           "
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
echo "# 3) Generating fstab & Showing Partition Table / Mountpoints                                        "
echo "#===================================================================================================#"
echo
sleep 1

echo "Generating /etc/fstab..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Partition Table and Mountpoints:"
cat /mnt/etc/fstab


clear
echo
echo "#===================================================================================================#"
echo "# 4) Setting Basic variables for chroot (defaults provided)                                          "
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



clear
sleep 1
echo
echo "#===================================================================================================#"
echo "# 5) Installing GRUB for UEFI - Works now!!! (Possible in future: Bios support)                      "
echo "#===================================================================================================#"
echo
sleep 1
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

clear
echo
echo "#===================================================================================================#"
echo "# 6A) Running chroot and setting mkinitcpio - Setting Hostname, Username, enabling services etc.     "
echo "#===================================================================================================#"
echo
# inline script for arch-chroot operations "postinstall.sh"
# Ask for passwords before chroot (silent input)

cat > /mnt/root/postinstall.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# --------------------------
# Variables injected by main installer
# --------------------------
TZ="{{TIMEZONE}}"
LANG_LOCALE="{{LANG_LOCALE}}"
HOSTNAME="{{HOSTNAME}}"
NEWUSER="{{NEWUSER}}"

# --------------------------
# 1) Timezone & hardware clock
# --------------------------
ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
hwclock --systohc

# --------------------------
# 2) Locale
# --------------------------
if ! grep -q "^${LANG_LOCALE} UTF-8" /etc/locale.gen 2>/dev/null; then
    echo "${LANG_LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LANG_LOCALE}" > /etc/locale.conf

# --------------------------
# 3) Hostname & /etc/hosts
# --------------------------
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
HOSTS

# --------------------------
# 4) Keyboard layout
# --------------------------
echo "KEYMAP=fi" > /etc/vconsole.conf
echo "FONT=lat9w-16" >> /etc/vconsole.conf
localectl set-keymap fi
localectl set-x11-keymap fi

# --------------------------
# 5) Initramfs
# --------------------------
mkinitcpio -P

# --------------------------
# 6) Root + user passwords (interactive)
# --------------------------
set +e  # allow retries
MAX_RETRIES=3

# Ensure user exists
if ! id "$NEWUSER" &>/dev/null; then
    echo "Creating user '$NEWUSER'..."
    useradd -m -G wheel -s /bin/bash "$NEWUSER"
fi

# Root password
echo
echo "============================"
echo " Set ROOT password "
echo "============================"
for i in $(seq 1 $MAX_RETRIES); do
    if passwd root; then
        break
    else
        echo "⚠️ Passwords did not match. Try again. ($i/$MAX_RETRIES)"
    fi
done

# User password
echo
echo "============================"
echo " Set password for user '$NEWUSER' "
echo "============================"
for i in $(seq 1 $MAX_RETRIES); do
    if passwd "$NEWUSER"; then
        break
    else
        echo "⚠️ Passwords did not match. Try again. ($i/$MAX_RETRIES)"
    fi
done

# Give sudo rights
echo "$NEWUSER ALL=(ALL:ALL) ALL" > /etc/sudoers.d/$NEWUSER
chmod 440 /etc/sudoers.d/$NEWUSER
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

set -e  # restore strict error handling

# --------------------------
# 7) Home directory setup
# --------------------------
HOME_DIR="/home/$NEWUSER"
CONFIG_DIR="$HOME_DIR/.config"
mkdir -p "$CONFIG_DIR"
chown -R "$NEWUSER:$NEWUSER" "$HOME_DIR"

# --------------------------
# 8) Enable basic services
# --------------------------
systemctl enable NetworkManager
systemctl enable sshd

echo "Postinstall inside chroot finished."
EOF


#===================================================================================================#
# 6B) Inject variables into /mnt/root/postinstall.sh                                                 
#===================================================================================================#

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
clear
echo
echo "#===================================================================================================#"
echo "# 7A) INTERACTIVE MIRROR SELECTION & OPTIMIZATION                                                    "
echo "#===================================================================================================#"
echo

echo
echo "-------------------------------------------"
echo "📡 Arch Linux Mirror Selection & Optimization"
echo "-------------------------------------------"
echo "Choose your country or region for faster package downloads."

# Ensure reflector is installed in chroot
arch-chroot /mnt pacman -Sy --needed --noconfirm reflector || {
    echo "⚠️ Failed to install reflector inside chroot — continuing with defaults."
}

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

# Conflict-preventing, retry-aware installer
install_with_retry() {
    local CHROOT_CMD=("${!1}")
    shift
    local CMD=("$@")
    local MAX_RETRIES=3
    local RETRY_DELAY=5
    local MIRROR_COUNTRY="${SELECTED_COUNTRY:-United States}"

    for ((i=1; i<=MAX_RETRIES; i++)); do
        echo "Attempt $i of $MAX_RETRIES: ${CMD[*]}"
        if "${CHROOT_CMD[@]}" "${CMD[@]}"; then
            echo "✅ Installation succeeded"
            return 0
        else
            echo "⚠️ Failed attempt $i"
            if (( i < MAX_RETRIES )); then
                "${CHROOT_CMD[@]}" bash -c '
                    pacman-key --init
                    pacman-key --populate archlinux
                    pacman -Sy --noconfirm archlinux-keyring
                '
                [[ -n "$MIRROR_COUNTRY" ]] && \
                "${CHROOT_CMD[@]}" reflector --country "$MIRROR_COUNTRY" --age 12 --protocol https --sort rate \
                    --save /etc/pacman.d/mirrorlist || echo "⚠️ Mirror refresh failed."
                sleep "$RETRY_DELAY"
            fi
        fi
    done

    echo "❌ Installation failed after $MAX_RETRIES attempts."
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

sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 8A) GPU DRIVER INSTALLATION & MULTILIB                                                             "
echo "#===================================================================================================#"
echo

echo
echo "-------------------------------------------"
echo "🎮 GPU DRIVER INSTALLATION"
echo "-------------------------------------------"
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

sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 8B) WINDOW MANAGER / DESKTOP ENVIRONMENT SELECTION                                                 "
echo "#===================================================================================================#"
echo

echo
echo "-------------------------------------------"
echo "🖥️  WINDOW MANAGER / DESKTOP ENVIRONMENT SELECTION"
echo "-------------------------------------------"
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



sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 8C) LOGIN / DISPLAY MANAGER SELECTION                                                              "
echo "#===================================================================================================#"
echo

echo
echo "-------------------------------------------"
echo "🔐 LOGIN / DISPLAY MANAGER SELECTION"
echo "-------------------------------------------"
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


sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 9A) EXTRA PACMAN PACKAGE INSTALLATION (Resilient + Safe)                                           "
echo "#===================================================================================================#"
echo

echo
echo "-------------------------------------------"
echo "📦 EXTRA SYSTEM PACKAGE INSTALLATION"
echo "-------------------------------------------"

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


sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 9B) OPTIONAL AUR PACKAGE INSTALLATION (with Conflict Handling)                                     "
echo "#===================================================================================================#"
echo

echo
echo "-------------------------------------------"
echo "🌐 OPTIONAL AUR PACKAGE INSTALLATION"
echo "-------------------------------------------"

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

sleep 1
clear
echo
echo "#===================================================================================================#"
echo "# 10) Hyprland Theme Setup (Optional) with .Config Backup                                            "
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

        echo "✅ Hyprland theme setup completed."
    else
        echo "Skipping Hyprland theme setup."
    fi
fi

sleep 2
clear
echo
echo "#===================================================================================================#"
echo "# 11 Cleanup postinstall script & Final Messages & Instructions                                      "
echo "#===================================================================================================#"
echo

echo 
echo "Custom package installation phase complete."
echo "You can later add more software manually or extend these lists:"
echo "  - EXTRA_PKGS[] for pacman packages"
echo "  - AUR_PKGS[] for AUR software"
echo " -------------------------------------------------------------------------------------------------------------------"
echo "Full base + extras installation is complete."
echo "You can now unmount and reboot:"
echo "  umount -R /mnt"
echo "  swapoff ${P3} || true"
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
