# ArchXyrif - Semi-Automated & Interactive Install Script, With guided steps, to install Archlinux with. 
<img width="723" height="360" alt="2025-11-08-145308_hyprshot" src="https://github.com/user-attachments/assets/a2f2e2a3-0c51-442c-80fa-5af7de453cd1" />
Warning! this is an install tool, that will format and repartition your system. Handle with care.<br><br>


UEFI/Bios Support. <br>
GNU GENERAL PUBLIC LICENSE Version 3License - Copyright (c) Terra88 - Read LICENCE section for more.<br>
<br>
Aim of the project:<br> 
Is to create a semi-automated script, that will help you install Arch Linux, semi-automatically. The program will guide you through the installation and stop with prompts step by step.<br>
<br>1)Partition, set root/home size manually, currently EXT4 or btrfs 2) Installing bare minimum build with pacstrap 3) Ask for user/host informations and set user/root pw, sets up basic services.
<br>
Optional: [y/n] options: 4) Guides you through GPU driver/Window manager/Login manager setup with simple "example: (1.Intel,2.Nvidia,3.AMD,4.All drivers,5.Skip) options" 5) asks if you want to install extra Pacman or AUR packages y/n and finishes the install.
<br><br>
HOW TO USE: Create a USB Boot Stick with Balena Etcher & Iso file from: https://archlinux.org/download/ <br>
Set USB Boot to 1st priority from startup menu f2/del and Restart to Boot Archlinux Bootable installer ISO(USB Media)<br>
Make sure you have internet connection turned on.<br>
Type:<br>
loadkeys fi or en etc. depending your keyboard language/layout.
<br>
git clone https://github.com/terra88/archXyrif <br>
cd archxyrif <br>
chmod +x archxyrif-installer.sh <br>
./archxyrif-installer.sh <br> <br>

Presenting you Version 1.3 - right after 1.0, due to adding a lot more features and fixes to the first release. So i claim the right to add a couple numbers.
<br><br>
### **1.0 - Version Feature Recall**

-1. Gives lsblk disk layout to interact with, which disk to choose, format and re-partition.

-2. Clears any encryptions set on the disk, if the chosen disk had encryption on it.

-3. Formats the disk to Boot, Root, Home, Swap (FAT32 boot&efi, ext4 for Root and Home) - More features coming later.

-4. Calculates swap automatically and rezises (Swap) partition based ur ram amount.

-5. Boot is set to be 1024MiB to fit more than 1 kernel, and Root is set to be around 100GB and rest 100% of the disk goes to Home. "can be changed in the code to your liking"

-6. Can turn on or off swap from the code, by putting comment mark # before swapon line.

-7. mounts disks automatically and sets the layout to fstab before running mkinitcpio.

-8. Basic pacstrap packages are base base-devel bash go git grub linux linux-zen linux-headers linux-firmware vim

sudo nano networkmanager efibootmgr openssh intel-ucode amd-ucode btrfs-progs

-9. Installs GRUB Bootloader UEFI - Supports Secure Boot - Works atleast on my secure boot laptop. -"might require tinkering, but should work out of the box"

-10. Asks for Timezone, Lang_Local, Hostname, username, root password, user password and sets user as sudoer to conf.

-11. Installs extra pacman & aur packages, multilib is enabled for extra packages, but are totally optional and need to be modified manually to the file.
<br>

### **Changes in Version 1.3**
<br><br>
-1. First of all i decided to name the installer file to archxyrif-installer.sh instead of archlinux-installer.sh
<br><br>
-2. Added Block 7:
<br><br>
-3. 7A) Interactive mirror selection & optimization for pacman, you can choose closest pacman mirror from a menu and it will automatically change your mirrorlist, to conf and download packages through there.
<br><br>
-Current mirrorlist options available: United States, Canada, Germany, Finland, United Kingdom, Japan, Australia, Custom country code (2-letter ISO, e.g., FR)
<br><br>
-4. Added Block 7B) Pacman Helper: Sets pacman a helper through out the installer, to retry 3 times downloading a package if an error occurs, or if connection to the server fails or is bad.
<br><br>
-5. 7B) Safe pacman install: checks if there are conflicts with packages being installed throughout the install process and overwrites files, let's say, if you want to install a git file manually at 9B) additional aur package, the aur pkg will overwrite the packman package without error.
<br><br>
-6. Block 8:
<br><br>
-7. 8A) Asks the user if the user wants to install gpu drivers or not, default is "all drivers - if you don't know what you should install. There is also an option for no driver at all. Intel, Nvidia, AMD, All, None.
<br><br>
-8, 8B) Asks the user if the user wants to install a window manager to your system and gives options to choose from.
<br><br>
-Current Window Managers Available: Hyprland, Sway, XFCE, KDE Plasma, Skip WM/DE Installation
<br><br>
-9. 8C Asks the user if the user wants to install a Login / Display manager and gives options to choose from.
<br><br>
-Current Login / Display managers Available: GDM, SDDM, LightDM, LXDM, Ly, Skip Display Manager
<br><br>
-Block 9:<br><br>
-9A) Changed and simplified the Pacman Extra packet handler, but now it calls the Helper before the GPU,WM/DM, to handle all pacman packets with same rules through out the installation.
<br><br>
-Extra Pacman PKG "EXTRA_PKGS" list needs to still be edited manually, if you want to install any extra.
<br><br>
-9B) Changed AUR Helper/Package installer to Paru instead of YAY, due to it simplifying the install process of packages, compared to YAY in 1.0.
<br><br>
-AUR_Additional packages are asked as manual prompt for now, i haven't added "Extra_AUR" to the code yet, because i wanted to make a Release with the changes that are working now. So any extra package works if u just know the pkg you want to install, like "Hyprland-git" for example.<br><br>


### **Changes in Version 1.3.1**
1.3.1 - Minor tweaks to add correct user rights when logging into fresh system, also to set correct keyboard layout to x11 systems when you log in to the first time.
<br><br>

-Created a table of contents to the start of the script and Interactive Headers that pop up, when next stage of installation starts to help the user with the installation progress. Makes the installation much more clear, when the new header pops and the old "garbage on the screen clears".<br>

###**-Added Block 11: to install a custom hyprland theme from another project of mine "https://GitHub.com/Terra88/hyprland-setup"<br><br>Current keybinds for Hyprland, are:<br>^**
###**-Block 11 will prompt if you install Hyprland and ask, if you want to add my custom theme to it y/N. If you answer yes, additional packages will be installed that the theme requires and .config files will be copied** ###**automatically from my other GitHub project. On a note you should also install the extra AUR packages, which are required for the theme.<br><br>**
###**-it will automatically give new user the rights to that folder. Also wallpaper engine will be added to /home as wallpaper.sh and a wallpaper folder that the engine rotates. hyprlock will have a lock button and a wallpaper**
###**set to it in /home/wallpaper folder called lock.jpg**
<br>
###**-Also Hyprland + GDM works best together. When logging in first time: (remember to click username, then press the gear icon low right and select hyprland before you login first time)<br>**
<br>
###**-windows+Q : exit highlighted window/program.<br>**
###**-windows+Enter(Return): open terminal<br>**
###**-windows+R: open menu(installed programs)<br>**
###**-windows+E: open file manager.<br>**
###**-windows+M: logout to login screen(for power button etc)<br>**



### **Features added to ver. 1.3.6**

-Created interactive guidance throughout the install process, with headlines of what is the current stage of the install process. Also added tips of what options to choose from, headlined prompts for when the program wants you to set passwords etc.

-New Disk partition/filesystem options added:<br>
-Quick partition section has now 3 options to it:<br><br>

- 1)Fat 32: Boot, swap calculated by ram(2 x ram if less than 16GB and 1 x ram if more than 16GB ram) EXT4Root(100GB) and rest 100% goes to /home.<br>
- 2)Fat 32: Boot, swap calculated by ram(2 x ram if less than 16GB and 1 x ram if more than 16GB ram) BTRFS @Root(100GB) and rest 100% goes to @home.<br>
- 3)Fat 32: Boot, swap calculated by ram(2 x ram if less than 16GB and 1 x ram if more than 16GB ram) BTRFS @Root(100GB) and rest 100% goes to EXT4 /home.<br><br>

-This way you get snapshots features if you have BTRFS partitions.<br><br>

-Made minor tweaks to how the user/root information is handled when running chroot & mkinitcpio setup.<br><br>

-Did Error handling, if set passwords don't match or you enter wrong password, you will be informed to set pw or try again + inform about how many times you can retry, so the script doesn't fail to typos along the way. <br><br>

-All and all should be very smooth install process.<br> <br>

-Features i'm currently planning on implementing later: Custom partition scheme - set values manually and filesystem.<br><br>

known bugs: well it's not really a bug, but the unmount process at the start of the script only unmounts LUKS LV's and clears encryptions, if you format with btrfs, you will have to unmount the drive manually or reboot your system to re-format, if you have to run the script again for any reason. Will fix that later.

### **Version 1.3.9 - Release!!!**
<br><br>
- Added More options to the quick partition scheme:<br>
- EXT4 & BTRFS Filesystems currently available<br>
- You can either do Disk format and partitioning: to a 1 big disk(Everything under /root) or 2 Disk Partitions(/Root /Home) separate.<br>
- You can switch Swap On or Off - Value still set to be calculated automatically, via ram.<br>
- You can now manually set Root and Home partition sizes, to suite your needs.<br>
- you can also create a BTRFS(root)+Ext4(home) if you want snapshot support to @root.<br>
<br>
-Did error handling so you should not be able to insert values that float over the current disk size.<br>
-Every option has been tested and should be working correctly.
<br> <br>

### **Version 1.4 - Release!!!**
<br><br>
- I cleaned the script and made more complex & compact scripts to save space and to prevent copying the same code over and over again, for different options, that the install script offers:<br><br>
- New Features available:<br>
- The Script now offers support for UEFI and BIOS systems and formats & partitions to both correctly.<br>
- New menu layout and every install step now has it's own function, so the program starts from the bottom from the "menu" call and continues to main menu and so on, calling the rest of the functions to install arch linux in a clean and correct order.<br>
- Swap is either on or off and user gets prompted to select either way, still calculated by ram on quick part<br>
- User sets manually Root and Home partition sizes, to suite your needs.<br>
- You can format and partition your disk to EXT4 or BTRFS Filesystems.<br>
- You can create either 1 big filesystem, everything under root or /root /home separate. <br>
- you can create a BTRFS(root)+Ext4(home) if you want snapshot support root only.<br><br>
-Every option has been tested and should be working correctly.
<br><br>
-Adding custom partition/format section later, to support more file systems and to suppor more options.
<br><br>
### **Version 1.4.1 - Release!!!**
<br><br>
- Custom partition & format route created.<br>
- Custom format partition route, allows the user to create multiple raw partitions.<br>
- User can set custom partition sizes freely, and use different file systems on different partitions. Swap is totally optional<br>
- Filesystem options are: ext4, btrfs, xfs, f2fs, fat32, swap <br>
- Mount points currently are: /boot / (root) /home swap /data1 /data2 (can be added manually more and will be added manually more in the future)<br>
- all the other features are pretty much the same.<br>
<br><br>

### **Version 1.4.4 - Release!!!**
<br><br>
- Custom partition & format route created - Now working correctly with BIOS AND UEFI - Systems<br>
- Custom format partition route, allows the user to create multiple raw partitions, on single/multiple DISKS<br>
- For example: you can have /boot /root /home on Disk1 and have a Disk 2 formatted and partitioned to have /data 1 /data2 etc. <br><br>
- User can set custom partition sizes freely, and use different file systems on different partitions/disks. Swap is totally optional<br><br>
- Luks/LVM path created: Currently you can create logical volumes and encrypt your disks with it and select multiple disks to create logical volumes to.<br>
-  On a notice, Disks need to have similiar block rate, to avoid errors in creating bigger volumes. Currently option to cut disks rawly in half to create separate pools inside one disk is not available, will be working on it in the future. if you want to create more than 1 encrypted area on 1 disk, you will have to create the partitions beforehand.<br><br>

- Filesystem options are currently followed: ext4, btrfs, xfs, f2fs, fat32, swap <br>
- Mount points currently are: /boot / (root) /home swap /data1 /data2 /datax(only on custom/raw format mode)<br>
- all the other features are pretty much the same as before.<br>
- More features coming out soon.
<br><br>
