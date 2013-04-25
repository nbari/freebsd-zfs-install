#!/usr/bin/env sh
if [ -e conf-zfs.sh ]; then
	. ./conf-zfs.sh
else
	echo "conf-zfs.sh missing"
	exit 1
fi
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
zfs create -o mountpoint=/tmp tank/tmp
zfs create -o mountpoint=/var tank/var
zfs create -o mountpoint=/usr tank/usr
zfs create -o mountpoint=/usr/src tank/usr/src
zfs create -o mountpoint=/usr/local tank/usr/local
zfs create -o mountpoint=/usr/ports tank/usr/ports
zfs create -o mountpoint=/home tank/home

echo "BOOT SET"
zpool set bootfs=tank/root tank

cd /mnt

echo "TAR"
fetch $url/kernel.txz
fetch $url/base.txz
tar xJpf kernel.txz -C /mnt
tar xJpf base.txz -C /mnt

echo "CONF"
echo 'zfs_load="YES"' > /mnt/boot/loader.conf
echo 'vfs.root.mountfrom="zfs:tank/root"' >> /mnt/boot/loader.conf
echo 'zfs_enable="YES"' > /mnt/etc/rc.conf
echo "hostname=\"$hostname\"" >> /mnt/etc/rc.conf
echo "ifconfig_${ifconfig_if}=\"inet $ifconfig_addr netmask $ifconfig_mask broadcast $ifconfig_brdc\"" >> /mnt/etc/rc.conf
echo "defaultrouter=\"$defaultrouter\"" >> /mnt/etc/rc.conf
echo 'sshd_enable="YES"' >> /mnt/etc/rc.conf
echo '/dev/ada0p2 none swap sw 0 0' > /mnt/etc/fstab

cd /

echo "EXPORT"
zpool export tank
zpool import -o cachefile=/tmp/zpool.cache -o altroot=/mnt tank
cp /tmp/zpool.cache /mnt/boot/zfs/

echo "CHANGE ROOT PASSWORD AND VERIFY INFORMATIONS IN rc.conf, fstab AND loader.conf"
echo "You just have been chrooted into your fresh installation."
chroot /mnt /bin/tcsh
