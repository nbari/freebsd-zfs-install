#!/usr/bin/env sh
if [ -e conf-zfs.sh ]; then
	. ./conf-zfs.sh
else
	echo "conf-zfs.sh missing"
	exit 1
fi
echo "ZFS RELATED"
kldload opensolaris
kldload zfs

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
# if crypt -> ada0p3 will be unencrypted boot and ada0p4 encrypted root
if [ "$1" = "--crypt" ]; then
	gpart add -t freebsd-zfs -l zfs-boot $ada
fi
# In all cases, create the ZFS root volume to take left disk space
gpart add -t freebsd-zfs -l zfs-root $ada

echo "DD ZERO"
# Zero ZFS sectors
dd if=/dev/zero of=/dev/${ada}p3 count=560 bs=512
if [ "$1" = "--crypt" ]; then
	dd if=/dev/zero of=/dev/${ada}p4 count=560 bs=512
fi

echo "BOOTCODE"
# Put bootcode in freebsd-boot partition
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $ada



# Let start interesting things :)

if [ "$1" = "--crypt" ]; then
	kldload geom_eli

	zpool create -f -m none -o altroot=/mnt zboot gpt/zfs-boot

	mkdir -p /mnt/boot
	zfs set mountpoint=/boot zboot
	zfs mount zboot
	# Create geli key, which will be used to encrypt disk
	dd if=/dev/random of=/mnt/boot/${ada}p4.key bs=4096 count=1
	# Initialize disk with geli. /dev/*.eli entries are unlocked disks
	geli init -b -K /mnt/boot/${ada}p4.key -l 256 -s 4096 -e AES-XTS /dev/${ada}p4
	geli attach -k /mnt/boot/${ada}p4.key /dev/${ada}p4

	zpool create -f -m none -o altroot=/mnt tank /dev/${ada}p4.eli
else
	echo "ZPOOL TANK"
	zpool create -f -m none -o altroot=/mnt -o cachefile=/tmp/zpool.cache tank gpt/zfs-root
fi

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
if [ "$1" = "--crypt" ]; then
	zpool set bootfs=zboot zboot
else
	zpool set bootfs=tank/root tank
fi

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
echo 'sshd_enable="YES"' >> /mnt/etc/rc.conf
echo '/dev/ada0p2 none swap sw 0 0' > /mnt/etc/fstab

if [ "$1" = "--crypt" ];then
	echo 'geom_eli_load="YES"' >> /mnt/boot/loader.conf
	echo "geli_devices=\"${ada}p4\"" >> /mnt/etc/rc.conf
	echo "geli_${ada}p4_keyfile0_load=\"YES\"" >> /mnt/bool/loader.conf
	echo "geli_${ada}p4_keyfile0_type=\"${ada}p4:geli_keyfile0\"" >> /mnt/bool/loader.conf
	echo "geli_${ada}p4_keyfile0_name=\"/boot/${ada}p4.key\"" >> /mnt/boot/loader.conf
fi

cd /

echo "EXPORT"
zpool export tank
zpool import -o cachefile=/tmp/zpool.cache -o altroot=/mnt tank
cp /tmp/zpool.cache /mnt/boot/zfs/

echo "CHANGE ROOT PASSWORD AND VERIFY INFORMATIONS IN rc.conf, fstab AND loader.conf"
echo "You just have been chrooted into your fresh installation."
chroot /mnt /bin/tcsh
