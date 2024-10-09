NAME = vmtest

# encrypt _password_
# use escaped double dollar \$$
PASSWORD = "\$$2b\$$08\$$YJWlxUbhzxR6jBJBJzbiH.BK.NkW6EgbXBE3HhW63wS6ICnIr8Iae"


all:
	@echo 'Usage:'
	@echo ' make [ edit | status ] - edit Makefile, show image|vm status'
	@echo ' make [ image | convert | mount | fsck | umount | uconfig ]'
	@echo ' make [ ftp | install ] - get files, install vm'
	@echo ' make password - set root password'
	@echo ' make [ vmd | run | stop ] - start vmd, start|stop vm'

status:
	mount
	vnconfig -l
	vmctl status

edit:
	mcedit Makefile

ftp:
	@#sysupgrade -skn
	@#rm -rf base7*.tgz
	@#cp /home/_sysupgrade/base7*.tgz .
	@#cp /home/_sysupgrade/bsd .
	@#cp /home/_sysupgrade/bsd.rd .
	ftp -T https://cdn.openbsd.org/pub/OpenBSD/snapshots/amd64/base76.tgz
	ftp -T https://cdn.openbsd.org/pub/OpenBSD/snapshots/amd64/bsd
	ftp -T https://cdn.openbsd.org/pub/OpenBSD/snapshots/amd64/bsd.rd

image:
	vmctl create -s 1.5G ${NAME}.img
	vnconfig ${NAME}.img >vnd
	fdisk -iy $$(<vnd)
	#vi disklabel.auto
	disklabel -T disklabel.auto -F etc/fstab -w -A $$(<vnd)
	newfs $$(<vnd)a
	sync
	vnconfig -u $$(<vnd)
	rm vnd

install:
	mkdir -p mnt
	vnconfig ${NAME}.img >vnd
	mount -w /dev/$$(<vnd)a mnt
	rm -rf mnt/etc
	tar -C mnt -xzf base7*.tgz
	tar -C mnt -xzf mnt/var/sysmerge/etc.tgz
	@#mc
	cp bsd mnt/
	cp bsd.rd mnt/
	cp etc/* mnt/etc/
	@#cd mnt/etc && rm localtime && ln -s /usr/share/zoneinfo/Europe/Moscow localtime
	echo ${NAME}.my.domain > mnt/etc/myname
	echo https://cdn.openbsd.org/pub/OpenBSD > mnt/etc/installurl
	ln -fs /usr/share/zoneinfo/Europe/Moscow mnt/etc/localtime
	installboot -v -r mnt/ $$(<vnd)
	cd mnt/dev && sh MAKEDEV all
	rm -rf mnt/usr/share/relink/kernel/
	chmod 1777 mnt/tmp
	chroot mnt/ usermod -p ${PASSWORD} root
	head -n 1 mnt/etc/master.passwd
	chroot mnt/ pkg_add -D snap unzip--iconv mc
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt

password:
	mkdir -p mnt
	vnconfig ${NAME}.img >vnd
	mount -w /dev/$$(<vnd)a mnt
	chroot mnt/ usermod -p ${PASSWORD} root
	head -n 1 mnt/etc/master.passwd
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt

convert:
	vmctl create -i ${NAME}.qcow2 ${NAME}.img

fsck:
	vnconfig ${NAME}.img >vnd
	fsck -fy /dev/$$(<vnd)a
	sync
	vnconfig -u $$(<vnd)
	rm vnd

mount:
	mkdir -p mnt
	vnconfig ${NAME}.img >vnd
	mount -w /dev/$$(<vnd)a mnt
	mc mnt
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt
umount:
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt
uconfig:
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt

mountrd:
	gzcat bsd.rd > bsdrd
	rdsetroot -dx bsdrd ramdisk
	mkdir -p mnt
	vnconfig ramdisk >vnd
	mount -w /dev/$$(<vnd)a mnt
	mc mnt
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	#rdsetroot bsdrd ramdisk
	#gzip bsdrd -o bsd.rd
	#chmod 666 bsd.rd
	rm -rf mnt ramdisk

vmd:
	rcctl -f start vmd
	sysctl net.inet.ip.forwarding=1
	echo "pass out on egress from 100.64.0.0/10 to any nat-to (egress)" | pfctl -f-

run:
	@echo ====================
	@echo  Login: root
	@echo  Your password hash: ${PASSWORD}
	@echo  Exit: ~.
	@echo ====================
	@##vmctl start -c -m 64M -L -d ${NAME}.img "${NAME}"
	vmctl start -c -m 256M -L -d ${NAME}.img "${NAME}"

stop:
	vmctl stop "${NAME}"
