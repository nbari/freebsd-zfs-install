#!/usr/bin/env tcsh
# Boot in LiveCD mode, login root, cd /tmp, fetch zfs.sh, chmod +x zfs.sh, ./zfs.sh
set ada="ada0"
set swap_space="4G"
#set keymap="us.iso.acc.kbd"
#set keymap="uk.iso.kbd"
set keymap="fr.iso.acc.kbd"
set hostname="freebsd-zfs"
set nameserver="192.168.56.1"

#set url="http://ftp.fr.freebsd.org/pub/FreeBSD/releases/amd64/9.1-RELEASE"
#set url="http://ftp.fr.freebsd.org/pub/FreeBSD/snapshots/amd64/amd64/9.1-STABLE"
#set url="http://192.168.0.23/~florent/freebsd-zfs/9.1-RELEASE"
#set url="http://192.168.0.23/~florent/freebsd-zfs/9.1-STABLE"
#set url="ftp://158.255.96.2/pub/FreeBSD/releases/amd64/amd64/9.2-RC2"
#set sets = (kernel base lib32 src doc)
#set url="http://192.168.56.1:8000/"
set url="http://192.168.56.1:8000/freebsd/91r"
set sets = (kernel base)

#setenv HTTP_PROXY "http://proxy:3128"
set dest="/mnt"
set taropt="xJpf"

zpool import -f -o altroot=$dest tank
zpool destroy -f tank
zpool labelclear /dev/${ada}*

gpart destroy -F $ada
gpart create -s gpt $ada
# Keep freebsd-boot at start of the disk.
gpart add -s 128 -t freebsd-boot -l boot $ada
gpart add -s $swap_space -t freebsd-swap -l swap $ada
gpart add -t freebsd-zfs -l zfs-root $ada

# Zero ZFS sectors
dd if=/dev/zero of=/dev/${ada}p3 count=560 bs=512

# Put bootcode in freebsd-boot partition
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 $ada

# Let start interesting things :)
zpool create -f -m none -o altroot=$dest -o cachefile=/tmp/zpool.cache tank gpt/zfs-root

zfs create -o mountpoint=/ tank/root
zfs create -o mountpoint=/tmp tank/root/tmp
zfs create -o mountpoint=/var tank/root/var
zfs create -o mountpoint=/usr tank/root/usr
zfs create -o mountpoint=/usr/src tank/root/usr/src
zfs create -o mountpoint=/usr/local tank/root/usr/local
zfs create -o mountpoint=/usr/ports tank/root/usr/ports
zfs create -o mountpoint=/home tank/root/home

zpool set bootfs=tank/root tank

cd $dest

mdconfig -a -t malloc -s 1m -u 4
newfs -O 1 /dev/md4
mount /dev/md4 /etc
echo "nameserver $nameserver" > /etc/resolv.conf

foreach set_ ($sets)
	fetch -a $url/$set_.txz
	tar $taropt $set_.txz -C $dest
end

umount /etc

echo zfs_load=\"YES\" > $dest/boot/loader.conf
echo vfs.root.mountfrom=\"zfs:tank/root\" >> $dest/boot/loader.conf
echo zfs_enable=\"YES\" > $dest/etc/rc.conf
echo keymap=\"$keymap\" >> $dest/etc/rc.conf
echo hostname=\"$hostname\" >> $dest/etc/rc.conf
echo sshd_enable=\"YES\" >> $dest/etc/rc.conf
echo "/dev/ada0p2 none swap sw 0 0" > $dest/etc/fstab

cd /

zpool export tank
zpool import -o cachefile=/tmp/zpool.cache -o altroot=$dest tank
cp /tmp/zpool.cache $dest/boot/zfs/

echo You\'ve just been chrooted into your fresh installation.
echo passwd root
echo hostname=\"yourhostname\" in rc.conf and make alias in /etc/hosts.
echo Add users, import conf file from anywhere... do what you want and reboot.
echo Do \"chroot $dest /bin/tcsh\" if you want to go in \;\)
echo Be careful, you are in a C-shell.
chroot $dest /bin/tcsh
done:
	continue
error:
	exit 1
