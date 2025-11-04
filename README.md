# ArchXyrif - Automated Install Script to install Archlinux with. 
<img width="422" height="332" alt="2025-11-04-230326_hyprshot" src="https://github.com/user-attachments/assets/8bcb6d0a-cd96-4ba8-8ffd-0f9743637fb1" /><br>
Warning this script will reformat, re-part and reinstall your system to arch linux. <br>
MIT License - Copyright (c) 2025 Terra88 - Read LICENCE section for more.
<br>
loadkeys fi - en - etc. 
<br>
git clone https://github.com/Terra88/ArchXyrif <br>
cd ArchXyrif <br>
chmod +x archlinux-installer.sh <br>
./archlinux-installer.sh <br> <br>

Versio 1.0 - Automated arch linux install script - archlinux-installer.sh
https://github.com/Terra88/ArchXyrif/releases/tag/ver1.0

<br>
First Working Release of the script. 1.0 - Finally YAY!!!!
<br><br>
Features:<br>
-Shows list of disks to select from Type: /dev/sda or /dev/nvme0 for example.
<br><br>
-checks and should remove encryptions from disk that you are installing on automatically.
<br><br>
-Formats the disk to Boot, Root, Home, Swap (Fat32 boot&Efi and ext4 for Root & Home).
<br><br>
-Calculates swap from ram, Boot is 1024MiB so you can fit more kernels in it, root is 120GB and rest 100% left goes to /home depending on ur hdd/ssd/nvme size. "can be changed & tinkered".
<br><br>
-Can turn on or off swap from the code, by putting comment mark # before swapon
-automatically mounts disks.
<br><br>
-Mounts the discs and saves fstab.
<br><br>
-Basic pacstrap packages are base base-devel go git grub linux linux-zen linux-headers linux-firmware vim sudo nano networkmanager efibootmgr openssh intel-ucode amd-ucode btrfs-progs
<br><br>
-installs Grub bootloader UEFI, should work on secure boot machines, might have to add efi from bios "trusted bootloader files", but for me atleast works on my "secure boot laptop" out of the box, without tinkering.
<br><br>
-Prompts for Timezone, Lang_Local, Hostname, username, root password, user password. Sets user as sudoer.
<br><br>
-From Section 8) Installs extra pacman packages & Aur packages. Multilib is enabled(in the section 9 chroot installer runner) and AUR will prompt for sudo rights asking password time to time, if packages are used. Can be left empty if not needed.
<br><br>
-Possible errors: Some Aur Packages just don't want to install, so might have to install their regular pacman counterparts or continue installing error ones once logged in.
<br><br>
-Things coming in the future:
<br><br>
-Will be adding my .config files from my other hyprland project which will install themes and configs from my hyprland setup that i'm working on. and maybe other .config files too if modded correctly.
<br><br>
-Will be creating a section to the code that asks which gpu drivers to install, so you might have to tinker with these, if you plan to run this script.
<br><br>
-Doesnt set up gui for window manager or loginmanager yet, so those are coming in the near future.
<br><br>
-For now this particular version boots to login prompt and after that you can type hyprland and press enter to get to hyprland window manager. No configs added yet.
<br><br>
-And more, just happy it finally works and have the first working version of it.
