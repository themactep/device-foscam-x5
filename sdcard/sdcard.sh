#!/bin/bash
#
# Create SD card
# for converting Foscam X5 / Acculenz R5 / Assark X3E camere to OpenIPC firmware
#
# 2023 Paul Philippov, paul@themactep.com
#

show_help_and_exit() {
    echo "Usage: $0 -d <SD card device>"
    if [ "$EUID" -eq 0 ]; then
        echo -n "Detected devices: "
        fdisk -x | grep -B1 'SD/MMC' | head -1 | awk '{print $2}' | sed 's/://'
    fi
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    show_help_and_exit
fi

# command line arguments
while getopts d: flag; do
    case ${flag} in
        d) card_device=${OPTARG} ;;
    esac
done

[ -z "$card_device" ] && show_help_and_exit

if [ ! -e "$card_device" ]; then
    echo "Device $card_device not found."
    exit 2
fi

while mount | grep $card_device > /dev/null; do
    umount $(mount | grep $card_device | awk '{print $1}')
done

read -p "All existing information on the card will be lost! Proceed? [Y/N]: " ret
if [ "$ret" != "Y" ]; then
    echo "Aborting!"
    exit 99
fi

echo
while [ -z "$wlanssid" ]; do
    read -p "Enter Wireless network SSID: " wlanssid
done
while [ -z "$wlanpass" ]; do
    read -p "Enter Wireless network password: " wlanpass
done
echo

echo "Creating a 64MB FAT32 partition on the SD card."
parted -s ${card_device} mklabel msdos mkpart primary fat32 1MB 64MB && \
    sleep 3 && \
    mkfs.vfat ${card_device}1 > /dev/null
if [ $? -ne 0 ]; then
    echo "Cannot create a partition."
    exit 3
fi

sdmount=$(mktemp -d)

echo "Mounting the partition to ${sdmount}."
if ! mkdir -p $sdmount; then
    echo "Cannot create ${sdmount}."
    exit 4
fi

if ! mount ${card_device}1 $sdmount; then
    echo "Cannot mount ${card_device}1 to ${sdmount}."
    exit 5
fi

echo "Copying files."
cp -r $(dirname $0)/files/* ${sdmount}/

echo "Creating installation script."
echo "#!/bin/sh

fw_setenv wlandev \"rtl8188fu-ssc337de-foscam\"
fw_setenv wlanssid \"${wlanssid}\"
fw_setenv wlanpass \"${wlanpass}\"
" > ${sdmount}/autostart.sh

echo "Unmounting the SD partition."
sync
umount $sdmount
eject $card_device

echo "
Card #2 created successfully.
The card is unmounted. You can safely remove it from the slot.

Powered off the camera, place the SD card into the camera.
Power the camera on and wait at least four minutes.
Shortly after, an OpenIPC camera should appear on your wireless network.
"

exit 0
