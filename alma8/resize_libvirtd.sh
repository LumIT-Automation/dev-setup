#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <vm name> <delta>"
    echo "delta example: +10G" 
    exit 0
fi

vmName=$(virsh list | grep "_${1}" | awk '{print $2}')
resizeDiff="$2"

if ! echo "$2" | grep -Eq '^[0-9]+$'; then
    echo "Arg $2 should be an integer (it means the amount of Gb to increase the disk)."
    exit 1
fi


diskImage=$(virsh qemu-monitor-command ${vmName} info block --hmp | grep drive-virtio-disk0 | awk '{print $3}')

if [ -z "$diskImage" ]; then
    echo "Cannot modify disk image|image not found"
    exit 1
fi


oldDiskSize=$(virsh qemu-monitor-command ${vmName} info block -v --hmp| grep -A2 "$diskImage" | grep 'virtual size' | awk -F':' '{print $2}' | sed -r -e 's/\s+([0-9]+)\s+GiB.*/\1/')

newDiskSize=`echo $(( $oldDiskSize + $resizeDiff ))`

virsh qemu-monitor-command $vmName block_resize drive-virtio-disk0 ${newDiskSize}G --hmp

