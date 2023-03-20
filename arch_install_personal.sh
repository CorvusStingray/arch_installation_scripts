#!/usr/bin/bash

sed_replace_pattern="s:>:\n>g;s:_::g"

echo "g>n>_>_>+512M>t>1>n>_>_>+8G>t>_>19>n>_>_>_>w" | sed $sed_replace_pattern | fdisk /dev/sda
echo "g>n>_>_>_>w" | sed $sed_replace_pattern

mkfs.fat -F32 -n EFI /dev/sda1
mkswap -L SWAP /dev/sda2
swapon /dev/sda2
mkfs.btrfs -fL ROOT /dev/sda3
mkfs.btrfs -fL HOME /dev/sdb1

mount /dev/sda3 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@var
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@snapshots
umount /dev/sda3
mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@ /dev/sda3 /mnt
mkdir -p /mnt/{boot/efi,var/log,.snapshots,home}
mount /dev/sda1 /mnt/boot/efi
mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@var /dev/sda3 /mnt/var
mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@var_log /dev/sda3 /mnt/var/log
mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@tmp /dev/sda3 /mnt/tmp
mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@snapshots /dev/sda3 /mnt/.snapshots

mount /dev/sdb1 /mnt/home
btrfs su cr /mnt/home/@home
umount /dev/sdb1
mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@home /dev/sdb1 /mnt/home

packages_to_download="
base
base-devel
linux
linux-headers
linux-firmware
grub
grub-btrfs
btrfs-progs
efibootmgr
amd-ucode
networkmanager
networkmanager-openvpn
ppp
wpa_supplicant
bluez
bluez-utils
exfat-utils
zsh
nano
neofetch
python
python-pip
git
"

pacstrap /mnt $packages_to_download
genfstab -U /mnt >> /mnt/etc/fstab

after_chroot_commands="
mkinitcpio -p linux
grub-install /dev/sda --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg
cat /etc/locale.gen | sed \"s:#en_U:en_U:g;s:#ru_R:ru_R:g\" > /etc/locale.gen
locale-gen
echo LANG=en_US.utf-8 > /etc/locale.conf
echo arch > /etc/hostname
cat /etc/sudoers | sed \"85 s:# ::g\" > /etc/sudoers
echo -n \"Enter an username: \"; read username
useradd -mG wheel -g users -s /bin/zsh $username
echo -n \"Let's set passwords...\"
passwd root
passwd $username
exit
"

arch-chroot /mnt bash -c "$after_chroot_commands"

umount -R /mnt
shutdown now