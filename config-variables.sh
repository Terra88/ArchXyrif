#!/bin/bash

# server or desktop
install_mode="desktop"

################################################################################
# Default variables
################################################################################

# Colors
W='\e[0m'  # White
R='\e[91m' # Red
G='\e[92m' # Green
B='\e[96m' # Blue
Y='\e[93m' # Yellow

# LVM Configuration
create_home_fs="true"

lv_swap_size="16G"
lv_root_size="128G"
lv_home_size="100%FREE"

# Configuration
keymap="fi"
hostname="hyprland"
timezone="Europe/Helsinki"
locale="en_fi"
username="xyrif"

# Default packages
declare -a default_packages=(
    "blueman"
    "bluez"
    "bluez-utils"
    "dolphin"
    "dolphin-plugins"
    "dunst"
    "git"
    "gdm"
    "grim"
    "grub"
    "htop"
    "hypridle"
    "hyprland"
    "hyprlock"
    "hyprpaper"
    "hyprshot"
    "kitty"
    "nano"
    "network-manager-applet"
    "networkmanager"
    "polkit-kde-agent"
    "qt5-wayland"
    "qt6-wayland"
    "unzip"
    "uwsm"
    "rofi"
    "slurp"
    "vim"
    "wget"
    "wofi"
    "nftables"
    #xdg-desktop-portal-hyprland
)

################################################################################
# Desktop variables
################################################################################

# Gnome favorite apps
# Can be found in /usr/share/applications/
favorite_apps="['kitty', 'firefox']"

# Desktop specific packages
declare -a desktop_packages=(
"archlinux-xdg-menu"
"ark"
"bemenu-wayland"
"breeze"
"brightnessctl"
"btop"
"cliphist"
"cpupower"
"discord"
"discover"
"efibootmgr"
"evtest"
"firefox"
"flatpak"
"gamemode"
"goverlay"
"gst-libav"
"gst-plugin-pipewire"
"gst-plugins-bad"
"gst-plugins-base"
"gst-plugins-good"
"gst-plugins-ugly"
"iwd"
"kate"
"konsole"
"kvantum"
"libpulse"
"linuxconsole"
"lutris"
"mangohud"
"nvtop"
"nwg-displays"
"nwg-look"
"otf-font-awesome"
"pavucontrol"
"pipewire"
"pipewire-alsa"
"pipewire-jack"
"pipewire-pulse"
"qbittorrent"
"qt5ct"
"smartmontools"
"steam"
"sway"
"thermald"
"ttf-hack"
"vlc-plugin-ffmpeg"
"vlc-plugins-all"
"vulkan-radeon"
"waybar"
"wget"
"wine-gecko"
"wine-mono"
"wine-staging"
"winetricks"
"wireless_tools"
"wireplumber"
"wl-clipboard"
"xdg-desktop-portal-wlr"
"xdg-utils"
"xf86-video-amdgpu"
"xf86-video-ati"
"xorg-server"
"xorg-xinit"
"zram-generator"
)

# AUR packages
declare -a aur_packages=(
"hyprland-protocols-git" 
"hyprlang-git"
"hyprlang-git-debug" 
"hyprutils-git" 
"hyprutils-git-debug" 
"hyprwayland-scanner-git" 
"hyprwayland-scanner-git-debug" 
"kvantum-theme-catppuccin-git" 
"obs-studio-git" 
"proton-ge-custom-bin" 
"protonup-qt" 
"python-inputs" 
"python-steam" 
"python-vdf" 
"qt6ct-kde" 
"wlogout" 
"wlrobs-hg" 
"xdg-desktop-portal-hyprland-git" 
"xdg-desktop-portal-hyprland-git-debug"
)
