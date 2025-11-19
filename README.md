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


https://github.com/Terra88/ArchXyrif/wiki/%F0%9F%93%98-ArchXyrif-%E2%80%93-Arch-Linux-Semi%E2%80%90Automated-Install-Script#wiki-pages-box
