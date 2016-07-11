#!/bin/bash

print_help () {
    echo "Usage: $0 "'$XEN_CFG_FILE $SRV_DEST'
    exit
}


if [[ -z ${2} ]]; then
    print_help
fi

set -u

XEN_CFG_FILE=${1}

SRV_DEST=${2}

VG='rootvg'

SSH_CMD="ssh ${SRV_DEST}"

# Return value of a "key = 'value'" line
get_x () {
    grep -E "^${1}" ${XEN_CFG_FILE} | sed -r "s/[a-z]* *= *'(.*)'/\1/"
}

get_lv_size () {
    lvdisplay ${1} | awk '/Size/ { print $3$4 }'
}

get_disk () {
    grep -E "phy.*disk" ${XEN_CFG_FILE} | sed -r "s/.*phy:(.*),.*,.*,$/\1/"
}

get_fs_type () {
    blkid ${1} -o value -s TYPE
}

create_lv_on_remote_srv () {
    ${SSH_CMD} lvdisplay ${REMOTE_DISK}
    if [[ $? -ne 0 ]]; then
        ${SSH_CMD} lvcreate -n ${NAME}-disk -L ${LV_SIZE} ${VG}
        ${SSH_CMD} lvcreate -n ${NAME}-swap -L 512M ${VG}
        ${SSH_CMD} mkfs.${FS_TYPE} /dev/${VG}/${NAME}-disk
        ${SSH_CMD} mkswap  /dev/${VG}/${NAME}-swap
    else
        echo "LV already exists skipping..."
    fi
}

mount_lv_on_remote_srv () {
    ${SSH_CMD} mkdir -p ${MOUNT_POINT}
    ${SSH_CMD} mount ${REMOTE_DISK} ${MOUNT_POINT}
}

mount_lv_on_local_srv () {
    mkdir -p ${MOUNT_POINT}
    mount -o ro ${DISK} ${MOUNT_POINT}
}

sync_data () {
    rsync -avuh ${XEN_CFG_FILE} ${SRV_DEST}:/etc/xen/
    rsync -avuh ${KERNEL}       ${SRV_DEST}:/boot/
    rsync -avuh ${RAMDISK}      ${SRV_DEST}:/boot/
    rsync -avuh ${MOUNT_POINT}/ ${SRV_DEST}:${MOUNT_POINT}
}

umount_lv_on_remote_srv () {
    ${SSH_CMD} umount ${MOUNT_POINT}
    ${SSH_CMD} rmdir ${MOUNT_POINT}
}

umount_lv_on_local_srv () {
    umount ${MOUNT_POINT}
    rmdir ${MOUNT_POINT}
}

NAME=$(get_x name)
KERNEL=$(get_x kernel)
RAMDISK=$(get_x ramdisk)

DISK=$(get_disk)
FS_TYPE=$(get_fs_type ${DISK})

LV_SIZE=$(get_lv_size ${DISK})

REMOTE_DISK="/dev/${VG}/${NAME}-disk"
MOUNT_POINT="/mnt/${NAME}"

create_lv_on_remote_srv

mount_lv_on_remote_srv
mount_lv_on_local_srv

sync_data

umount_lv_on_remote_srv
umount_lv_on_local_srv


