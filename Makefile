NAME = vmtest

# encrypt _password_
# use escaped double dollar \$$

# root:
PASSWORD = "\$$2b\$$09\$$WdU3zN9tz4zG6x22LTUjJOk2iiSCSIe8HJxCKQLYKS7n6aEI3Lrr6"
PUBKEY = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCh0ddvGotNVZRAEaggMcQg9DX5NdhzLOM9VrV0+uaSyhTGVNK2LYjDcaPQEVlLCP3qPysd40GEH5g8RE+5KLnseLncMMHhucqW5HKw1qsl4zfnRezEUtadFhbgJDQsJFCxLuKHpAOmhEoCFKaAIp+QJnsyTpSXqfI2k5Wn8HL1hwkNsKWQO/s50eb2KYthgvkIe5VJtScrOIAG57vZis/tvFwN4+OpZ+GM/o6H2I3JRehs0yvJsx/78pvZSF1krZo60rUVzbbkGGklw9nSEDIP48MHGeTbOET/AWprpRQKCpb9ZelEAfDIP6nqJw82dCqh44IlJwfJNxil0A1JcpjmXwJrBgdqIzJ8+W3oZ/1oveDNCWDeZjI3AT84yjfyEvffSfMPHEFBjKLp4vKn3AuYqH41m1VpXD+5QB9Kld7sDmZYdKhlH9Mk4wGXg55JfiVwsrhz8dISnpz0MhTqHWmgfOkIwod77CystSg6T69mRI/PY9qGqOlzL5KrJRZvrU8="

# adduser:
USER = test
UPASS = "\$$2b\$$09\$$WdU3zN9tz4zG6x22LTUjJOk2iiSCSIe8HJxCKQLYKS7n6aEI3Lrr6"


all:
	@echo 'Usage:'
	@echo ' make [ edit | status ] - edit Makefile, show image|vm status'
	@echo ' make [ delete | image | mount | fsck | umount | uconfig ] - image file operations'
	@echo ' make [ ftp | install ] - get files, install vm'
	@echo ' make password - set root password'
	@echo ' make adduser - add user and doas.conf'
	@echo ' make [ vmd | run | stop ] - start vmd, start|stop vm'
	@echo ' make [ delq | convert | runq ] - convert img to qcow2, start vm'

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
	@#head -n 1 mnt/etc/master.passwd
	fgrep -i root < mnt/etc/master.passwd
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
	@#head -n 1 mnt/etc/master.passwd
	fgrep -i root < mnt/etc/master.passwd
	echo ${PUBKEY} >> mnt/root/.ssh/authorized_keys
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt

adduser:
	mkdir -p mnt
	vnconfig ${NAME}.img >vnd
	mount -w /dev/$$(<vnd)a mnt
	rm -rf mnt/home/${USER}
	chroot mnt/ adduser -batch ${USER} users ${USER} ${UPASS} -q -noconfig
	fgrep -i ${USER} < mnt/etc/master.passwd
	chroot mnt/ usermod -G wheel ${USER}
	echo "permit keepenv persist :wheel" > mnt/etc/doas.conf
	chmod 600 mnt/etc/doas.conf
	chmod u+s mnt/usr/bin/doas
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt

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

delete:
	rm ${NAME}.img

delq:
	rm ${NAME}.qcow2

convert:
	vmctl create -i ${NAME}.img ${NAME}.qcow2

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

runq:
	@echo ====================
	@echo  Login: root
	@echo  Your password hash: ${PASSWORD}
	@echo  Exit: ~.
	@echo ====================
	vmctl start -c -m 256M -L -d ${NAME}.qcow2 "${NAME}"

stop:
	vmctl stop "${NAME}"
