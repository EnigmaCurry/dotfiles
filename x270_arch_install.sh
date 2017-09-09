#!/bin/bash
[[ $0 != "$BASH_SOURCE" ]] && sourced=1 || sourced=0
if [ $sourced == 0 ]; then
    echo "Don't run this script. Source it."
    exit 1
fi

# Make config changes here:
# Hostname
export HOSTNAME=aurelius
# The hard drive device name:
export HDD=nvme0n1
# The EFI partition
export EFI_PART=nvme0n1p1
# The partition to store the encrypted boot:
export CRYPT_BOOT=nvme0n1p2
# The partition to store the encrypted LVM:
export CRYPT_ROOT=nvme0n1p3
# Volume sizes:
export SWAP_SIZE=16G
# Password to encrypt device with.
# Recommended to keep this simple and then change it post-install.
# https://wiki.archlinux.org/index.php/Dm-crypt/Device_encryption#Key_management
export CRYPT_PASS=hunter2
# Root password:
export ROOT_PASS=root
# Time zone
export TIME_ZONE=America/New_York
# Locale
export LOCALE="en_US.UTF-8 UTF-8"
export LANG="en_US.UTF-8"
# Arch mirror:
export ARCH_MIRROR='http://mirror.cs.vt.edu/pub/ArchLinux/$repo/os/$arch'

init() {
    timedatectl set-ntp true
}

block_dev() {
    dd if=/dev/zero of=/dev/$HDD bs=1M count=1
cat <<END | parted /dev/$HDD
mklabel gpt
mkpart ESP fat32 1MiB 513MiB
set 1 boot on
mkpart primary 513MiB 1013MiB
mkpart primary 1013MiB 100%
END
}

luks_dev() {
    echo $CRYPT_PASS | cryptsetup luksFormat /dev/$CRYPT_BOOT
    echo $CRYPT_PASS | cryptsetup open /dev/$CRYPT_BOOT boot
    echo $CRYPT_PASS | cryptsetup luksFormat /dev/$CRYPT_ROOT
    echo $CRYPT_PASS | cryptsetup open /dev/$CRYPT_ROOT lvm
    unset CRYPT_PASS
}

lvm() {
    pvcreate /dev/mapper/lvm
    vgcreate pool /dev/mapper/lvm
    lvcreate -L $SWAP_SIZE pool -n swap
    lvcreate -l 100%FREE pool -n root
    mkswap /dev/mapper/pool-swap
    mkfs.ext4 /dev/mapper/pool-root
    mount /dev/mapper/pool-root /mnt
    swapon /dev/mapper/pool-swap
}

boot_dev() {
    mkfs.ext2 /dev/mapper/boot
    mkdir /mnt/boot
    mount /dev/mapper/boot /mnt/boot

    mkfs.vfat /dev/$EFI_PART
    mkdir /mnt/boot/efi
    mount /dev/$EFI_PART /mnt/boot/efi
}

install() {
    echo "Server = $ARCH_MIRROR" > /etc/pacman.d/mirrorlist
    mkdir -p /mnt/etc/pacman.d
    echo "Server = $ARCH_MIRROR" > /mnt/etc/pacman.d/mirrorlist
    pacman -Sy
    pacstrap /mnt base
    genfstab -U /mnt >> /mnt/etc/fstab
    echo "boot    /dev/$CRYPT_BOOT" >> /etc/crypttab
}

config() {
    cat <<EOF | arch-chroot /mnt
ln -sf /usr/share/zoneinfo/$TIME_ZONE /etc/localtime
hwclock --systohc
echo $LOCALE > /etc/locale.gen
locale-gen
echo "LANG=$LANG" > /etc/locale.conf
echo $HOSTNAME > /etc/hostname
echo "127.0.1.1	$HOSTNAME.localdomain	$HOSTNAME" >> /etc/hosts
pacman -Sy --noconfirm
pacman -S iw wpa_supplicant dialog wifi-menu --noconfirm
echo "root:$ROOT_PASS" | chpasswd

perl -pi -e 's/^HOOKS=[.\w\W]*/HOOKS="base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck"\n/' /etc/mkinitcpio.conf
mkinitcpio -p linux
EOF
}

grub() {
    cat <<EOF | arch-chroot /mnt
pacman -S grub efibootmgr --noconfirm
perl -pi -e 's/GRUB_CMDLINE_LINUX=\"\"//' /etc/default/grub
echo GRUB_CMDLINE_LINUX=\"cryptdevice=$CRYPT_ROOT:lvm root=/dev/mapper/pool-root\" >> /etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=grub --recheck
EOF
}


echo "Installer ready."
echo "Run the following commands in order. Look for errors!"
echo "  init"
echo "  block_dev"
echo "  luks_dev"
echo "  lvm"
echo "  boot_dev"
echo "  install"
echo "  config"
echo "  grub"
echo ""
echo "Don't forget to change your LUKS encryption passphrase later."
