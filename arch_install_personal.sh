#!/usr/bin/bash

part_() {
    sed_replace_pattern="s:>:\n:g;s:_::g"

    echo "g>n>_>_>+512M>t>1>n>_>_>+16G>t>_>19>n>_>_>_>w" | sed $sed_replace_pattern | fdisk /dev/sda
    echo "g>n>_>_>_>w" | sed $sed_replace_pattern | fdisk /dev/sdb

    mkfs.fat -F32 -n EFI /dev/sda1
    mkswap -L SWAP /dev/sda2
    swapon /dev/sda2
    mkfs.btrfs -fL LINUX /dev/sda3
    mkfs.btrfs -fL GAMES /dev/sdb1
}

mount_() {
    mount /dev/sda3 /mnt

    for subvol in "" var tmp home snapshots; do
        btrfs su cr /mnt/@$subvol
    done

    umount /dev/sda3

    btrfs_mount_options="ssd,noatime,compress=zstd:2,space_cache=v2,discard=async"

    mount -o $btrfs_mount_options,subvol=@ /dev/sda3 /mnt
    mkdir -p /mnt/{boot/efi,var,tmp,home,.snapshots}
    mount /dev/sda1 /mnt/boot/efi

    for subvol in var tmp home; do
        mount -o $btrfs_mount_options,subvol=@$subvol /dev/sda3 /mnt/$subvol
    done

    mount -o $btrfs_mount_options,subvol=@snapshots /dev/sda3 /mnt/.snapshots
}

install_() {
    packages_to_install="
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
    gdm_packages="
        file-roller
        gdm
        gnome-calendar
        gnome-clocks
        gnome-console
        gnome-control-center
        gnome-disk-utility
        gnome-keyring
        gnome-logs
        gnome-menus
        gnome-session
        gnome-settings-daemon
        gnome-shell
        gnome-shell-extensions
        gnome-system-monitor
        nautilus
        sushi
        xdg-user-dirs-gtk
        nvidia
        nvidia-utils
        lib32-nvidia-utils
        vulkan-icd-loader
        lib32-vulkan-icd-loader
        nvidia-settings
    "

    if [ -n "$1" ]; then
        packages_to_install="$packages_to_install $gdm_packages"
    fi

    sed -i "93,94 s:#::g" /etc/pacman.conf

    pacstrap /mnt $(echo $packages_to_install)
}

after_chroot_install_() {
    hostname=$1
    admin_username=$2
    admin_password=$3
    root_password=$4

    games_directory="/home/$admin_username/Games"

    after_chroot_commands="
        mkinitcpio -p linux;
        grub-install /dev/sda --efi-directory=/boot/efi;
        grub-mkconfig -o /boot/grub/grub.cfg;

        sed -i \"s:#en_U:en_U:g;s:#ru_R:ru_R:g\" /etc/locale.gen;
        locale-gen;
        echo LANG=en_US.utf-8 > /etc/locale.conf;

        echo $hostname > /etc/hostname;
        sed -i \"85 s:# ::g\" /etc/sudoers;
        useradd -mG wheel -g users -s /bin/zsh $admin_username;
        echo -e \"$admin_password\n$admin_password\" | passwd $admin_username;
        echo -e \"$root_password\n$root_password\" | passwd root;

        mkdir $games_directory;
        mount /dev/sdb1 $games_directory;
        btrfs su cr $games_directory/@games;
        umount /dev/sdb1;
        mount -o ssd,noatime,compress=zstd:2,space_cache=v2,discard=async,subvol=@games /dev/sdb1 $games_directory;
        chown $admin_username $games_directory;
        systemctl enable NetworkManager;
        systemctl enable gdm 2> /dev/null
    "

    arch-chroot /mnt bash -c "$(echo $after_chroot_commands)"
    
    genfstab -U /mnt >> /mnt/etc/fstab
    umount -R /mnt
    reboot now
}

main_() {
    if ping -c 1 google.com > /dev/null 2>&1; then
        part_ &&
        mount_ &&
        install_ $5 &&
        after_chroot_install_ $1 $2 $3 $4
    else
        echo "Please, check your internet connection"
    fi
}

main_ $@
