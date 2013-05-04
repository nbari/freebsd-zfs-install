#!/usr/bin/env sh

zpool import -f -o altroot=/mnt tank
zpool destroy -f tank
zpool import -f -o altroot=/mnt bootdir
zpool destroy -f bootdir

zpool labelclear /dev/ada0*

gpart destroy -F ada0
gpart create -s gpt ada0
gpart add -s 128 -t freebsd-boot ada0
gpart add -s 4G -t freebsd-swap ada0
gpart add -s 4G -t freebsd-zfs ada0
gpart add -t freebsd-zfs ada0

gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ada0

mdconfig -a -t malloc -s 8m -u 2
newfs -O2 /dev/md2
mount /dev/md2 /boot/zfs

zpool create bootdir /dev/ada0p3
zpool set bootfs=bootdir bootdir
mkdir -p /boot/zfs/bootdir
zfs set mountpoint=/boot/zfs/bootdir bootdir
zfs mount bootdir

dd if=/dev/random of=/boot/zfs/bootdir/ada0p4.key bs=4096 count=1

geli init -b -B /boot/zfs/bootdir/ada0p4.eli -e AES-XTS -K /boot/zfs/bootdir/ada0p4.key -l 256 -s 4096 /dev/ada0p4
geli attach -k /boot/zfs/bootdir/ada0p4.key /dev/ada0p4

zpool create tank /dev/ada0p4.eli
zfs set mountpoint=/boot/zfs/tank tank
zfs mount tank
zfs unmount bootdir
mkdir /boot/zfs/tank/bootdir
zfs set mountpoint=/boot/zfs/tank/bootdir bootdir
zfs mount bootdir

zfs create tank/usr
zfs create tank/home
zfs create tank/usr/ports
zfs create tank/usr/src
zfs create tank/var
zfs create tank/tmp

cd /boot/zfs/tank

fetch http://192.168.56.1/~florent/base.txz
fetch http://192.168.56.1/~florent/kernel.txz
echo "extract base"
tar xJpf base.txz
echo "extract kernel"
tar xJpf kernel.txz

echo "mv /boot /bootdir/"
echo "ln -sf /bootdir/boot"
echo "mv /bootdir/*.key /bootdir/boot"
echo "mv /bootdir/*.eli /bootdir/boot"
echo "then exit"
chroot /boot/zfs/tank

echo ‘vfs.zfs.prefetch_disable=”1″‘ > /boot/zfs/tank/bootdir/loader.conf
echo ‘vfs.root.mountfrom=”zfs:tank”‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo ‘zfs_load=”YES”‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo ‘aesni_load=”YES”‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo ‘geom_eli_load=”YES”‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo ‘geli_da0p3_keyfile0_load=”YES”‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo ‘geli_da0p3_keyfile0_type=”ada0p4:geli_keyfile0″‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo ‘geli_da0p3_keyfile0_name=”/boot/ada0p4.key”‘ >> /boot/zfs/tank/bootdir/boot/loader.conf
echo 'zfs_enable="YES"' > /boot/zfs/tank/etc/rc.conf
echo 'sshd_enable="YES"' >> /boot/zfs/tank/etc/rc.conf
touch /boot/zfs/tank/etc/fstab

cp /boot/zfs/zpool.cache /boot/zfs/tank/boot/zfs/zpool.cache

cd /

zfs unmount -a || exit 1
zfs set mountpoint=legacy tank
zfs set mountpoint=/tmp tank/tmp
zfs set mountpoint=/usr tank/usr
zfs set mountpoint=/usr/ports tank/usr/ports
zfs set mountpoint=/usr/src tank/usr/src
zfs set mountpoint=/var tank/var
zfs set mountpoint=/home tank/home
