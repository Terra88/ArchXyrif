# ArchXyrif - Automated Install Script to install Archlinux with. Currently UEFI Support only.
<br><img width="753" height="304" alt="2025-11-06-093828_hyprshot" src="https://github.com/user-attachments/assets/8ee9e28f-35ad-4ae5-8ec7-be9d7a58f4aa" />

Warning this script will reformat, re-part and reinstall your system to arch linux. <br>
GNU GENERAL PUBLIC LICENSE Version 3License - Copyright (c) Terra88 - Read LICENCE section for more.<br>
<br>
Aim of the project:<br> 
Is to create a semi-automated script, that will help you install Arch Linux, semi automatically. The program will guide you through the installation and stop with prompts step by step.<br>
<br>1)Partition 2) Installing bare minimum build with pacstrap 3) Ask for user/host informations and set user/root pw set systemctl service on for network manager on etc.
<br>
Optional: [y/n] options: 4) Guides you through GPU driver/Window manager/Login manager setup with simple "example: (1.Intel,2.Nvidia,3.AMD,4.All drivers,5.Skip) options" 5) asks if you want to install extra Pacman or AUR packages y/n and finishes the install.
<br><br>
HOW TO USE: Create a USB Boot Stick with Balena Etcher & Iso file from: https://archlinux.org/download/ <br>
Set USB Boot to 1st priority from startup menu f2/del and Restart to Boot Archlinux Bootable installer ISO(USB Media)<br>
Make sure you have internet connection turned on.<br>
Type:<br>
loadkeys fi or en etc. depending your keyboard language/layout.
<br>
git clone https://github.com/Terra88/ArchXyrif <br>
cd ArchXyrif <br>
chmod +x archxyrif-installer.sh <br>
./archxyrif-installer.sh <br> <br>

Presenting you Version 1.3 - right after 1.0, due to adding a lot more features and fixes to the first release. So i claim the right to add a couple numbers.
<br><br>
1.0 - Version Feature Recall

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

Ver1.0: Had issues with installing AUR PKG's
### **So Changes in Version 1.3**
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

<br>
1.3.1 - Minor tweaks to add correct user rights when logging into fresh system, also to set correct keyboard layout to x11 systems when you log in to the first time.<br><br>
-Added Block 11: to install a custom hyprland theme from another project of mine "https://GitHub.com/Terra88/hyprland-setup"<br><br>
-Block 11 will prompt if you install Hyprland and ask, if you want to add my custom theme to it y/N. If you answer yes, additional packages will be installed that the theme requires and .config files will be copied automatically from my other GitHub project.<br><br>
-it will automatically give new user the rights to that folder. Also wallpaper engine will be added to /home as wallpaper.sh and a wallpaper folder that the engine rotates. hyprlock will have a lock button and a wallpaper set to it in /home/wallpaper folder called lock.jpg
<br>
