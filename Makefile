
# allow debug and demo
DEBUG = yes

# set editor
EDITOR = mcedit

# Used mirror
INSTALLURL = https://cdn.openbsd.org/pub/OpenBSD
# use snapshots
RELEASE = snapshots
# or OS version
#RELEASE = 7.8
VER = 78

# look into /usr/share/zoneinfo/
TZ = Europe/Moscow

# encrypt _password_
# use escaped double dollar \$$

# include root settings while install:
ADDROOT = yes
PASSWORD = "\$$2b\$$09\$$WdU3zN9tz4zG6x22LTUjJOk2iiSCSIe8HJxCKQLYKS7n6aEI3Lrr6"
PUBKEY = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCh0ddvGotNVZRAEaggMcQg9DX5NdhzLOM9VrV0+uaSyhTGVNK2LYjDcaPQEVlLCP3qPysd40GEH5g8RE+5KLnseLncMMHhucqW5HKw1qsl4zfnRezEUtadFhbgJDQsJFCxLuKHpAOmhEoCFKaAIp+QJnsyTpSXqfI2k5Wn8HL1hwkNsKWQO/s50eb2KYthgvkIe5VJtScrOIAG57vZis/tvFwN4+OpZ+GM/o6H2I3JRehs0yvJsx/78pvZSF1krZo60rUVzbbkGGklw9nSEDIP48MHGeTbOET/AWprpRQKCpb9ZelEAfDIP6nqJw82dCqh44IlJwfJNxil0A1JcpjmXwJrBgdqIzJ8+W3oZ/1oveDNCWDeZjI3AT84yjfyEvffSfMPHEFBjKLp4vKn3AuYqH41m1VpXD+5QB9Kld7sDmZYdKhlH9Mk4wGXg55JfiVwsrhz8dISnpz0MhTqHWmgfOkIwod77CystSg6T69mRI/PY9qGqOlzL5KrJRZvrU8="

# adduser:
ADDUSER = yes
USER = test
UPASS = "\$$2b\$$09\$$WdU3zN9tz4zG6x22LTUjJOk2iiSCSIe8HJxCKQLYKS7n6aEI3Lrr6"

# add packages:
#ADDPKG = unzip--iconv mc

# uncomment USEFDE to use image encryption
##USEFDE = yes
# !!! WTF? !!! After error:
# !!! WTF? !!! 	umount: /.../vmtest/mnt: Device busy
# !!! WTF? !!! 	*** Error 1 in /.../vmtest (Makefile:nnn 'install')
# !!! WTF? !!! you have to manually 'sync' and 'reboot' host.
# !!! WTF? !!! Then run 'make vmd' and 'make run' to start VM.
.ifdef USEFDE
FDEPASSWORD = password
.endif

# I have read Makefile and set my password and key above.
# Uncomment LETMERUN:
##LETMERUN = yes

help:
	@echo 'Usage:'
	@echo ' make [ help ] - list commands'
	@echo ' make edit - edit Makefile'
.ifdef LETMERUN
	@echo '--- vmd ---'
	@echo ' make vmd - start vmd'
	@echo '--- Image operations ---'
	@echo ' make ftp - get files'
	@echo ' make [NAME=imgname SIZE=imgsize] image'
	@echo ' make [NAME=imgname] [ install | password | adduser | fsck | mount ]'
	@echo ' make [ status | list | delete | umount | uconfig ]'
	@echo '--- qcow2  operations ---'
	@echo ' make [NAME=imgname RAM=size] run - start vm from image'
	@echo ' make [ listq | delq ]'
	@echo ' make [SRC=imgname DST=qcow2name] convert - convert img to qcow2'
.ifdef DEBUG
	@echo ' make [ clones | runc | test] - create qcow2 overlays, start TWO VMs, run demonstration'
.endif
	@echo '--- VM operations ---'
	@echo ' make [VM=name SRC=qcow2name] vmcreate'
	@echo ' make vmlist'
	@echo ' make [VM=name RAM=size] [ vmstart | vmstartc ]'
	@echo ' make vmstatus'
	@echo ' make [VM=name] vmstop'
	@echo ' make [VM=name] ssh'
	@echo ' make [VM=name] console'
	@echo ' make [VM=name RAM=size] vmconf' - create vm.conf file
	@echo '--- Network operations ---'
	@echo ' make [ pfreset | pfrules ]'
	@echo ' make [VM=name PORT=port] vmnat'
	@echo '--- Interface ---'
	@echo ' make tmux - attach to all running VMs'
.else
	@echo ''
	@echo 'You have to set configuration variables on top of Makefile.'
	@echo 'And review disklabel.auto template file.'
.endif

.ifndef EDITOR
EDITOR = vi
.endif

edit:
	${EDITOR} Makefile

.ifdef LETMERUN

ftp:
	@#sysupgrade -skn
	@#rm -rf base7*.tgz
	@#cp /home/_sysupgrade/base7*.tgz .
	@#cp /home/_sysupgrade/bsd .
	@#cp /home/_sysupgrade/bsd.rd .
	ftp -T ${INSTALLURL}/${RELEASE}/amd64/base${VER}.tgz
	ftp -T ${INSTALLURL}/${RELEASE}/amd64/bsd
	ftp -T ${INSTALLURL}/${RELEASE}/amd64/bsd.rd

.ifndef NAME
NAME = vmtest
.endif

.ifndef SIZE
SIZE = 1.5G
.endif

image:
	mkdir -p i
	vmctl create -s ${SIZE} i/${NAME}.img
	vnconfig i/${NAME}.img >vnd
	@cat vnd
	fdisk -iy $$(<vnd)
	#vi disklabel.auto
.ifndef USEFDE
	disklabel -T disklabel.auto -F etc/fstab -w -A $$(<vnd)
	cat etc/fstab
	newfs $$(<vnd)a
	sync
.else
	echo 'RAID *' | disklabel -wAT- $$(<vnd)
	@echo !!! Create new disk with password !!!
	@echo bioctl -c C -l $$(<vnd)a softraid0
	@echo ${FDEPASSWORD} | bioctl -s -C force -c C -l $$(<vnd)a softraid0
	bioctl softraid0 | sed -n 's/^softraid0.*\(sd[0-9]*\).*/\1/p' | tail -n 1 >vndx
	@cat vndx
	dd if=/dev/zero of=/dev/r$$(<vndx)c bs=1m count=1
	fdisk -iy $$(<vndx)
	disklabel -T disklabel.auto -F etc/fstab -w -A $$(<vndx)
	cat etc/fstab
	newfs $$(<vndx)a
	sync
	bioctl -d $$(<vndx)
.endif
	vnconfig -u $$(<vnd)
	rm vnd*

install:
	mkdir -p mnt
	vnconfig i/${NAME}.img >vnd
	@cat vnd
.ifndef USEFDE
	mount -w /dev/$$(<vnd)a mnt
.else
	@echo !!! Mount disk with password !!!
	@echo bioctl -c C -l $$(<vnd)a softraid0
	@echo ${FDEPASSWORD} | bioctl -s -c C -l $$(<vnd)a softraid0
	@#bioctl -c C -l $$(<vnd)a softraid0
	bioctl softraid0 | sed -n 's/^softraid0.*\(sd[0-9]*\).*/\1/p' | tail -n 1 >vndx
	@cat vndx
	mount -w -o sync /dev/$$(<vndx)a mnt
.endif
	rm -rf mnt/etc
	@echo !!!! WAIT !!!!
	tar -C mnt -xzphf base7*.tgz
	tar -C mnt -xzphf mnt/var/sysmerge/etc.tgz
	@#mc
	cp bsd mnt/
	cp bsd.rd mnt/
	cp etc/* mnt/etc/
	@#cd mnt/etc && rm localtime && ln -s /usr/share/zoneinfo/${TZ} localtime
	echo ${NAME}.my.domain > mnt/etc/myname
	echo https://cdn.openbsd.org/pub/OpenBSD > mnt/etc/installurl
	ln -fs /usr/share/zoneinfo/${TZ} mnt/etc/localtime
	cd mnt/dev && sh MAKEDEV all
.ifndef USEFDE
	@##installboot -v -r mnt/ $$(<vnd)
	chroot mnt/ installboot -v -r / $$(<vnd)
.else
	##installboot -v -r mnt/ $$(<vndx)
	chroot mnt/ installboot -v -r / $$(<vndx)
.endif
	rm -rf mnt/usr/share/relink/kernel/
	@##chmod 1777 mnt/tmp
.ifdef ADDROOT
	chroot mnt/ usermod -p ${PASSWORD} root
	fgrep -i root < mnt/etc/master.passwd
	echo ${PUBKEY} >> mnt/root/.ssh/authorized_keys
.endif
.ifdef ADDUSER
	rm -rf mnt/home/${USER}
	chroot mnt/ adduser -batch ${USER} users ${USER} ${UPASS} -q -noconfig
	fgrep -i ${USER} < mnt/etc/master.passwd
	chroot mnt/ usermod -G wheel ${USER}
	echo "permit keepenv persist :wheel" > mnt/etc/doas.conf
	chmod 600 mnt/etc/doas.conf
.endif
.ifdef ADDPKG
	chroot mnt/ pkg_add -D snap ${ADDPKG}
.endif
	sync && sync && sync
.ifdef USEFDE
	@echo !!! WTF? !!! After error:
	@echo !!! WTF? !!! 	umount: /.../vmtest/mnt: Device busy
	@echo !!! WTF? !!! 	*** Error 1 in /.../vmtest (Makefile:nnn 'install')
	@echo !!! WTF? !!! you have to manually 'sync' and 'reboot' host.
	@echo !!! WTF? !!! Then run 'make vmd' and 'make run' to start VM.
.endif
	#umount -f mnt
	umount mnt
.ifdef USEFDE
	bioctl -d $$(<vndx)
.endif
	vnconfig -u $$(<vnd)
	rm vnd*
	rm -rf mnt

password:
	mkdir -p mnt
	vnconfig i/${NAME}.img >vnd
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
	vnconfig i/${NAME}.img >vnd
	mount -w /dev/$$(<vnd)a mnt
	rm -rf mnt/home/${USER}
	chroot mnt/ adduser -batch ${USER} users ${USER} ${UPASS} -q -noconfig
	fgrep -i ${USER} < mnt/etc/master.passwd
	chroot mnt/ usermod -G wheel ${USER}
	echo "permit keepenv persist :wheel" > mnt/etc/doas.conf
	chmod 600 mnt/etc/doas.conf
	##chmod u+s mnt/usr/bin/doas
	sync
	umount mnt
	vnconfig -u $$(<vnd)
	rm vnd
	rm -rf mnt

fsck:
	vnconfig i/${NAME}.img >vnd
	fsck -fy /dev/$$(<vnd)a
	sync
	vnconfig -u $$(<vnd)
	rm vnd

mount:
	mkdir -p mnt
	vnconfig i/${NAME}.img >vnd
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
	mkdir -p mntrd
	vnconfig ramdisk >vndrd
	mount -w /dev/$$(<vndrd)a mntrd
	mc mntrd
	umount mntrd
	vnconfig -u $$(<vndrd)
	rm vndrd
	#rdsetroot bsdrd ramdisk
	#gzip bsdrd -o bsd.rd
	#chmod 666 bsd.rd
	rm -rf mntrd ramdisk

status:
	@echo Mount points:
	@mount
	@echo Attached Volumes:
	@vnconfig -l

list:
	ls i/*.img

delete:
	rm i/*.img

.ifndef SRC
SRC = ${NAME}
.endif

.ifndef DST
DST = ${NAME}
.endif

convert:
	mkdir -p q
	vmctl create -i i/${SRC}.img q/${DST}.qcow2

listq:
	ls q/*.qcow2

delq:
	rm q/*.qcow2

.ifndef VM
VM = ${SRC}
.endif

vmcreate:
	cd q && vmctl create -b ${SRC}.qcow2 ${VM}0.qcow2

vmlist:
	cd q && ls *.qcow2 | sed -e "/^vmtest.qcow2$$/d;s/.qcow2//"

vmd:
	rcctl -f start vmd
	sysctl net.inet.ip.forwarding=1
	make pfreset
##	echo "pass out on egress from 100.64.0.0/10 to any nat-to (egress)" | pfctl -f-

run:
	@#echo ====================
	@#echo  Login: root
	@#echo  Your password hash: ${PASSWORD}
	@#echo  Exit: ~.
	@#echo ====================
	@##vmctl start -c -m 64M -L -d i/${NAME}.img "${NAME}"
	vmctl start -c -m 256M -L -d i/${NAME}.img "${NAME}"

.ifndef RAM
RAM = 256M
.endif

vmstart:
	cd q && vmctl start -m ${RAM} -L -d ${VM}.qcow2 "${VM}"

vmstartc:
	cd q && vmctl start -c -m ${RAM} -L -d ${VM}.qcow2 "${VM}"

console:
	vmctl console ${VM}

vmstop:
	vmctl stop "${VM}"

vmstatus:
	@echo Running VMs:
	@vmctl status
	@# | fgrep -iv pid | tr -s '[:blank:]' '\t' | cut -f 2,10
	@echo IP addresses:
	@ifconfig tap | awk 'BEGIN{d[3]="not_vm"}; /description/ {split($$2, d, "-")} ; \
	/inet/ {split($$2, a, ".") ; print d[3], a[1]"."a[2]"."a[3]"."a[4]+1, d[2] ; d[3]="not_vm" }'

ssh:
.ifndef VM
	@echo Run: make VM=name ssh
.else
	ssh -o "StrictHostKeyChecking off" $$(ifconfig tap | \
	awk 'BEGIN{d[3]="not_vm"}; /description/ {split($$2, d, "-")} ; \
	/inet/ {split($$2, a, ".") ; print d[3], a[1]"."a[2]"."a[3]"."a[4]+1, d[2] ; d[3]="not_vm" }' | \
	fgrep if0 | fgrep ${VM} | tr -s '[:blank:]' '\t' | cut -f 2)
.endif

tmux:
	tmux \
	new-session -s vmtest -n master 'sh' \; \
	$$(for vn in $$(vmctl status | fgrep -iv pid | tr -s '[:blank:]' '\t' | cut -f 10); \
	do echo "; new-window -n $${vn} vmctl console $${vn} "; done;) \; \
	new-window -n help 'echo "console: <Enter>~. to close\ntmux: C-b\n\
	0..9 =Select windows 0 to 9\n\
	n =Change to the next window.\n\
	p =Change to the previous window.\n\
	d = detach session\n\
	Then \"tmux attach\" to return.\n" ; sh'

pfrules:
	pfctl -s rules

.ifndef VM
VM = vmtest
.endif

pfreset:
	echo "pass out on egress from 100.64.0.0/10 to any nat-to (egress)" | pfctl -f-

.ifndef PORT
PORT = 22
.endif

vmnat:
	pfctl -s rules > pftmp
	cat pftmp
	ifconfig tap | awk 'BEGIN{d[3]="not_vm"}; /description/ {split($$2, d, "-")} ; \
	/inet/ {split($$2, a, ".") ; print d[3], a[1]"."a[2]"."a[3]"."a[4]+1, d[2] ; d[3]="not_vm" }' | \
	fgrep if0 | fgrep ${VM} | tr -s '[:blank:]' '\t' | cut -f 2 > ${VM}ip
	cat ${VM}ip
	vmctl status | fgrep -i ${VM} | tr -s '[:blank:]' '\t' | cut -f 2 > ${VM}id
	cat ${VM}id
	echo 1024*$$(<${VM}id)+${PORT} | bc > ${VM}port
	@echo PORT= $$(<${VM}port)
	echo "pass in on egress proto tcp from any to any port $$(<${VM}port) \
	rdr-to $$(<${VM}ip) port ${PORT} " >> pftmp
	cat pftmp
	cat pftmp | pfctl -f-

vmconf:
	@echo "vm \"${VM}\" {\n\tdisable\n\tmemory ${RAM}\n\tdisk \"${.CURDIR}/q/${VM}.qcow2\"\n\tlocal interface\n\towner ${USER}\n}" > ${VM}.conf
	cat ${VM}.conf
	@echo "add 'include \"${.CURDIR}/${VM}.conf\"' to /etc/vm.conf and restart vmd"
	@echo "Then run 'vmctl start|stop [-c] ${VM}'"

.ifdef DEBUG

tlist:
	@echo Targets available:
	@grep -e "^[[:alnum:]]*:" Makefile | sort | tr -s ':\n' ' '
	@echo ''
##	@grep -e "^[[:alnum:]]*:" Makefile | sort

clones:
	cd q && vmctl create -b ${NAME}.qcow2 ${NAME}1.qcow2
	cd q && vmctl create -b ${NAME}.qcow2 ${NAME}2.qcow2

#runq:
#	cd q && vmctl start -c -m 256M -L -d ${NAME}0.qcow2 "${NAME}"

runc:
	tmux \
	new-session  'sh' \; \
	split-window 'cd q && vmctl start -c -m 256M -L -d ${NAME}1.qcow2 "${NAME}1"' \; \
	split-window -h 'cd q && vmctl start -c -m 256M -L -d ${NAME}2.qcow2 "${NAME}2"'

test:
	-make delete
	-make delq
	-make ftp
	make vmd
	make image
	make install
	make convert
	make clones
	make runc

.endif

# LETMERUN end
.endif
