ArchXyrif - Semi-Automated & Interactive Install Script, With guided steps, to install Archlinux with. 
<img width="723" height="360" alt="2025-11-08-145308_hyprshot" src="https://github.com/user-attachments/assets/a2f2e2a3-0c51-442c-80fa-5af7de453cd1" />
GNU GENERAL PUBLIC LICENSE Version 3 - Copyright (c) Terra88 - Read LICENCE section for more.<br>
<br>
support BIOS & UEFI, encryption, quick(simplified) & custom partitioning(manual), and system customization.<br>

After partition and format, the installer guides you through, either installing just basic pacstrap & bootloader & skipping rest, or you can choose to select window/login manager from the list and install GPU drivers etc. additional packages as well.

Aim of the Project:

ArchXyrif aims to provide a semi-automated, interactive, and guided installation experience for Arch Linux.
Instead of performing everything manually, ArchXyrif walks the user through each stage of the installation with prompts, menu selections, optional features, and error-handling.

It is designed to:
simplify the Arch installation process
remain fully transparent and interactive
offer both quick-install and advanced paths

You can either use:
-Quick format/partition to:
Give selected drive size to root/home folder and select if swap is on or off. Then select from ext4 or btrfs filesystems.

-Custom format/partition path, select disk manually, create partitions manually, give them mountpoints manually and format the drive or multiple drives to ext4, btrfs, xfs or f2fs.

-Then there is a route for creating lv/Luks drives and give logical volumes mountpoints.

⚠️ Important Warning

This script formats and partitions disks, unmounts, removes disk layouts and encryptions before new installation.
Use with caution.

How to Use ArchXyrif
-------------------
1. Create a Bootable USB

2. Use Balena Etcher or another tool to flash the latest Arch Linux ISO on a USB drive:
https://archlinux.org/download/

3. Change your bootable device priority on USB, launch the Arch Linux Installation media. Make sure you are connecter to the internet.

How to use the actual installer after booting up:
-------------------------------------------
1. loadkeys fi or en etc.
depending your keyboard language/layout. 
2.Install git:
Pacman -Sy git ->
3.git clone:
git clone https://GitHub.com/terra88/archxyrif
4.Open file directory:
-> cd archxyrif
<br>
5.Give user rights to the file:
-> chmod +x ./archxyrif-install.sh
6.Launch the installer:
-> ./archxyrif-install.sh
7. Follow the instructions
--------------------------------------------

More info:
https://github.com/Terra88/ArchXyrif/wiki/%F0%9F%93%98-ArchXyrif-%E2%80%93-Arch-Linux-Semi%E2%80%90Automated-Install-Script#wiki-pages-box
