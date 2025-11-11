# Unmount any leftovers
umount -Rf /mnt || true
umount -Rf /mnt/boot* || true

# Turn off swap (if active)
swapoff -a || true

# Stop background services that auto-probe disks
systemctl stop udisks2.service || true
systemctl stop lvm2-monitor.service || true

# Deactivate any existing LVM/crypt volumes
vgchange -an || true
for m in /dev/mapper/*; do
  t=$(readlink -f "$m" 2>/dev/null || true)
  if [[ "$t" == /dev/sda* ]]; then cryptsetup luksClose "$(basename "$m")" || true; fi
done

# Clear partition signatures and tables
wipefs -a /dev/sda

# Force kernel to re-read partition table
for i in {1..6}; do
  partprobe /dev/sda || true
  partx -u /dev/sda || true
  blockdev --rereadpt /dev/sda || true
  udevadm settle || true
  sleep 1
done
