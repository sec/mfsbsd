#!/bin/sh
#
set -e

FSIMG=$1
FSPROTO=$2
FSSIZE=$3

FSLABEL="auto"


exit_with() {
	local status="$1"
	shift

	if [ -n "$@" ]; then
		echo
		echo "$@"
	fi

	mdconfig -d -u ${unit}
	rm -f ${FSIMG}.$$

	exit ${status}
}

#Trap the killer signals so that we can exit with a good message.
trap "exit_with 1 'Received signal SIGHUP'" SIGHUP
trap "exit_with 1 'Received signal SIGINT'" SIGINT
trap "exit_with 1 'Received signal SIGTERM'" SIGTERM

if [ ${FSSIZE} -eq 0 -a ${FSLABEL} = "auto" ]; then
	roundup() echo $((($1+$2-1)-($1+$2-1)%$2))
	nf=$(find ${FSPROTO} |wc -l)
	sk=$(du -sk ${FSPROTO} |cut -f1)
	FSSIZE=$(roundup $(($sk*12/10)) 1024)
	IMG_SIZE=$((${FSSIZE}+32))
fi

echo "FSIMG ${FSIMG} FSPROTO ${FSPROTO} FSSIZE ${FSSIZE}"


dd of=${FSIMG} if=/dev/zero count=${IMG_SIZE} bs=1k
dd of=${FSIMG}.$$ if=/dev/zero count=${FSSIZE} bs=1k

export unit=`mdconfig -a -t vnode -f ${FSIMG}`
if [ $? -ne 0 ]; then
  echo "mdconfig failed"
  exit 1
fi

set -x
gpart create -s gpt ${unit}
gpart add -t freebsd-boot -b 34 -l boot -s 512K ${unit}
gpart bootcode -b ${FSPROTO}/boot/pmbr -p ${FSPROTO}/boot/gptboot -i 1 ${unit}
gpart add -t freebsd-ufs -l rootfs ${unit}

time makefs -B little ${FSIMG}.$$ ${FSPROTO}
time dd if=${FSIMG}.$$ of=/dev/${unit}p2 bs=128k

set +x
if [ $? -ne 0 ]; then
  echo "makefs failed"
  exit_with 1
fi

exit_with 0
