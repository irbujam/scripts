#!/bin/bash

### Backup fstab
##cp /etc/fstab /etc/fstab.bak

# check if OS/Boot drive
fCheckDiskType_OS_Boot() {
    local _disk=$1
    local _os_drive=$2
    local _ret_val=1

    # Check if any partitions from this drive are mounted as /boot or /
    if mount | grep -q "^/dev/${_disk}.* on /boot" || mount | grep -q "^/dev/${_disk}.* on / "; then
        _ret_val=0  # Found OS/Boot drive
    else
        if [ "/dev/${_disk}" == "${_os_drive}" ]; then
	    _ret_val=0  # Found device mounted on root fielsystem
	else
	    _ret_val=1  # Found Non OS/Boot drive
        fi
    fi
    #
    #echo "_ret_val = ${_ret_val}"
    return ${_ret_val}
}

# Function to add entry to fstab
fAddTo_fstab() {
    local uuid="$1"
    local mount_point="$2"
    local fs_type="$3"

    echo "UUID=${uuid} ${mount_point} ${fs_type} defaults,noatime,nofail 0 0" >> /etc/fstab
}

clear
# get drive info mounted on root filesystem
os_drive=$(df / | tail -1 | awk '{print $1}')
# Get list of unmounted disks
unmounted_disks=$(lsblk -o NAME,MOUNTPOINT | grep '^[^ ]* *$' | awk '{print $1}')

echo '##----------------------------------------------------##' >> /etc/fstab
echo "## >>>>>>>>  Begin : Subspace definitions   <<<<<<<<< ## " >> /etc/fstab
echo '##----------------------------------------------------##' >> /etc/fstab
# process unmounted disk(s)
for disk in $unmounted_disks; do
    # check OS/Boot drive
    if fCheckDiskType_OS_Boot "${disk}" "${os_drive}"; then
       echo "Skipped: /dev/${disk}...Reason: OS/Boot drive"
       echo ""
       continue
    fi

    # Get UUID
    uuid=$(blkid -s UUID -o value /dev/"${disk}")

    if [ -n "$uuid" ]; then
        # get drive size info
	#disk_size=$(lsblk -b --output SIZE -n -d /dev/"${disk}")
	disk_size=$(lsblk --output SIZE -n -d /dev/"${disk}" | xargs)

        # Create a mount point
        mount_point="/mnt/subspace/${disk}"
	mkdir -p "${mount_point}"

        # Assume ext4 filesystem type, change if needed
        #fs_type="ext4"
        fs_type=$(blkid -s TYPE -o value /dev/"${disk}")

        # Add entry to fstab
        fAddTo_fstab "${uuid}" "${mount_point}" "${fs_type}"
	echo "Disk: /dev/${disk}, UUID: ${uuid}, Size: ${disk_size}"
	echo "Action Taken: Added ${uuid} to fstab with mount point ${mount_point}"
	echo ""
    else
        echo "No UUID found for /dev/$disk"
    fi
done

#execute disk(s) mount
mount -av
systemctl daemon-reload

echo '##----------------------------------------------------##' >> /etc/fstab
echo "## >>>>>>>>   End - Subspace definitions    <<<<<<<<< ## " >> /etc/fstab
echo '##----------------------------------------------------##' >> /etc/fstab

echo "Finished...please check /etc/fstab for the new entries."
