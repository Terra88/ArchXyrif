#!/bin/bash
################################################################################
#
# Author  : 
# Purpose : Arch Linux custom installer
# GitHub  :
#
################################################################################

set -e

################################################################################
# Source variables
################################################################################

. config-variables.sh

################################################################################
# Preparation
################################################################################

# Arch logo from : https://wiki.archlinux.org/title/ASCII_art
# Text generated with : https://textkool.com/en/ascii-art-generator?font=Big&text=Arch%20Installer
echo -e "${B}
                    -@
                   .##@
                  .####@
                  @#####@
                . *######@            ${W}                    _       _____           _        _ _            ${B}
               .##@o@#####@           ${W}     /\            | |     |_   _|         | |      | | |           ${B}
              /############@          ${W}    /  \   _ __ ___| |__     | |  _ __  ___| |_ __ _| | | ___ _ __  ${B}
             /##############@         ${W}   / /\ \ | '__/ __| '_ \    | | | '_ \/ __| __/ _\` | | |/ _ \ '__|${B}
            @######@**%######@        ${W}  / ____ \| | | (__| | | |  _| |_| | | \__ \ || (_| | | |  __/ |    ${B}
           @######\`     %#####o      ${W}  /_/    \_\_|  \___|_| |_| |_____|_| |_|___/\__\__,_|_|_|\___|_|   ${B}
          @######@       ######%
        -@#######h       ######@.\`
       /#####h**\`\`       \`**%@####@
      @H@*\`                    \`*%#@
     *\`                            \`* ${W}"

loadkeys fi
timedatectl set-ntp true

# Disk partition
echo -e "[${B}INFO${W}] Select destination disk for Arch Linux"
echo "Disk(s) available:"
parted -l | awk '/Disk \//{ gsub(":","") ; print "- \033[93m"$2"\033[0m",$3}' | column -t
read -r -p "Please enter destination disk: " system_disk

echo -e "Disk ${Y}${system_disk}${W} will be ${R}ERASED${W} !"
read -r -p "Are you sure you want to proceed? (y/n)" system_disk_format

if [[ "${system_disk_format}" != "y" ]] ; then
    echo "Installation aborted!"
    exit 0
fi

echo "Formatting Drive ${system_disk}"
swapoff -a || true
umount ${system_disk}?* 2>/dev/null || true
vgchange -an || true # deactivate any active volume groups

#wipe out old signatures lvm raid fs etc.
wipefs -a "${system_disk}"

# zero out first few MB to remove old headers
dd if=/dev/zero of ="${system_disk}" bs=1M count=10 status=none

# 1. wipe partition table
sgdisk --zap-all "${system_disk}"
parted -s "${system_disk}" mklabel gpt

# 2. Create a single partition for LVM
echo "Creating LVM partition..."
parted -s "${system_disk}" mkpart primary 1MiB 100%

# 3. Create physical volume (PV) on the partition
echo "Creating physical volume on the disk..."
pvcreate "${system_disk}1"

# 4. Create volume group (VG) named "vg_arch"
echo "Creating volume group 'vg_arch'..."
vgcreate vg_arch "${system_disk}1"

# 5. Create logical volumes (LV):
# - /boot (FAT32)
# - / (root, ext4)
# - swap
# - /home (ext4)

# Get system RAM size for swap
RAM_SIZE=$(free -m | awk '/^Mem/ { print $2 }')

# Set swap size based on RAM (in MB)
SWAP_SIZE=$((RAM_SIZE))  # Swap size = RAM size

echo "RAM size: "${RAM_SIZE}" MB. Setting swap size to "${SWAP_SIZE}" MB."

# Create logical volumes for each partition
lvcreate -L 300M -n lv_boot vg_arch      # /boot (300 MiB)
lvcreate -L 130301M -n lv_root vg_arch     # / (root, 130 GB)
lvcreate -L "${SWAP_SIZE}"M -n lv_swap vg_arch # Swap (equal to RAM size)
lvcreate -l 100%FREE -n lv_home vg_arch # /home (remaining space)

# 6. Format the logical volumes:
echo "Formatting logical volumes..."

mkfs.fat -F32 /dev/vg_arch/lv_boot       # /boot
mkfs.ext4 /dev/vg_arch/lv_root           # /
mkswap /dev/vg_arch/lv_swap             # swap
mkfs.ext4 /dev/vg_arch/lv_home           # /home

# 7. Mount the partitions:
echo "Mounting logical volumes..."

# Mount root
mount /dev/vg_arch/lv_root /mnt

# Mount /boot
mkdir -p /mnt/boot
mount /dev/vg_arch/lv_boot /mnt/boot

# Mount /home
mkdir -p /mnt/home
mount /dev/vg_arch/lv_home /mnt/home

# Enable swap
swapon /dev/vg_arch/lv_swap

# Install Arch
echo -e "[${B}INFO${W}] Install Arch Linux"
pacstrap /mnt --color auto base base-devel vim nano sudo linux linux-zen linux-firmware linux-headers intel-ucode amd-ucode grub efibootmgr lvm2

# Generate fstab
echo -e "[${B}INFO${W}] Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Copy postinstall files to /mnt chroot
echo -e "[${B}INFO${W}] Copy installation material for post-install"
cp -v archlinux-postinstall.sh /mnt/opt
cp -v archlinux-postinstall-desktop.sh /mnt/opt
cp -v config-variables.sh /mnt/opt

#echo -e "\nluks_partition=\"${luks_partition}\"" >> /mnt/opt/config-variables.sh

echo -e "[${B}INFO${W}] Installation complete!"
echo -e "[${B}INFO${W}] Please run ${Y}arch-chroot /mnt${W}, ${Y}cd /opt${W} and ${Y}./archlinux-postinstall.sh${W} to continue"
