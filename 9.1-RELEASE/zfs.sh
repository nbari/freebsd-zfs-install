#!/usr/bin/env sh
ada="ada0"
swap_space="4G"
url="ftp://ftp.free.fr/mirrors/ftp.freebsd.org/releases/amd64/9.1-RELEASE"
echo "ZFS RELATED"
kldload opensolaris 2> /dev/null
kldload zfs 2> /dev/null

zpool import -f -o altroot=/mnt tank
zpool destroy -f tank
zpool import -f -o altroot=/mnt zboot
zpool destroy -f zboot

zpool labelclear /dev/${ada}*

echo "GPART"
gpart destroy -F $ada
echo "create"
gpart create -s gpt $ada
echo "add"
gpart add -s 128 -t freebsd-boot -l boot $ada
gpart add -s $swap_space -t freebsd-swap -l swap $ada
gpart add -t freebsd-zfs -l zfs-root $ada

echo "DD ZERO"
# Zero ZFS sectors
dd if=/dev/zero of=/dev/${ada}p3 count=560 bs=512

echo "BOOTCODE"
# Put bootcode in freebsd-boot partition
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $ada

# Let start interesting things :)
echo "ZPOOL TANK"
zpool create -f -m none -o altroot=/mnt -o cachefile=/tmp/zpool.cache tank gpt/zfs-root

echo "ZFS CREATE"
zfs create -o mountpoint=/ tank/root
zfs create -o mountpoint=/tmp tank/root/tmp
zfs create -o mountpoint=/var tank/root/var
zfs create -o mountpoint=/usr tank/root/usr
zfs create -o mountpoint=/usr/src tank/root/usr/src
zfs create -o mountpoint=/usr/local tank/root/usr/local
zfs create -o mountpoint=/usr/ports tank/root/usr/ports
zfs create -o mountpoint=/home tank/root/home

echo "BOOT SET"
zpool set bootfs=tank/root tank

cd /mnt

echo "TAR"
fetch $url/kernel.txz
fetch $url/base.txz
fetch $url/src.txz
fetch $url/lib32.txz
tar xJpf kernel.txz -C /mnt
tar xJpf base.txz -C /mnt
tar xJpf src.txz -C /mnt
tar xJpf lib32.txz -C /mnt

echo "CONF"
echo 'zfs_load="YES"' > /mnt/boot/loader.conf
echo 'vfs.root.mountfrom="zfs:tank/root"' >> /mnt/boot/loader.conf
echo 'zfs_enable="YES"' > /mnt/etc/rc.conf
echo 'sshd_enable="YES"' >> /mnt/etc/rc.conf
echo '/dev/ada0p2 none swap sw 0 0' > /mnt/etc/fstab

cd /

echo "EXPORT"
zpool export tank
zpool import -o cachefile=/tmp/zpool.cache -o altroot=/mnt tank
cp /tmp/zpool.cache /mnt/boot/zfs/

echo "You just have been chrooted into your fresh installation."
echo "passwd root
hostname=\"yourhostname\" in rc.conf and make alias in /etc/hosts.
Add users, import conf file from anywhere... do what you want and reboot."
chroot /mnt /bin/tcsh
