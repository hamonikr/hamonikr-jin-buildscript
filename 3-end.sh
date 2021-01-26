#!/bin/bash
#
# Date 2020.10.05
# 목적 : HamoniKR 4.0-jin-beta iso Build
# input : linuxmint-20-cinnamon-64bit.iso
# output : hamonikr-jin-4.0-beta-amd64.iso

###### 절대경로(realpath) ######
WORK_PATH="$(dirname $(realpath -s $0))"

###### iso 정보(iso info) ######
CONF="$WORK_PATH/conf/hamonikr.conf"
DOWN_URL=$(cat $CONF | grep down_url | awk -F 'down_url:' '{print $2}')
CDIMAGENAME=$(cat $CONF | grep input_iso | awk -F 'input_iso:' '{print $2}')
IMAGE_NAME=$(cat $CONF | grep output_iso | awk -F 'output_iso:' '{print $2}')


cd $WORK_PATH/custom-img

###### build iso ######
#Regenerate the manifest
sudo chmod +w extract-cd/casper/filesystem.manifest
sudo chroot edit dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee extract-cd/casper/filesystem.manifest
sudo cp extract-cd/casper/filesystem.manifest extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' extract-cd/casper/filesystem.manifest-desktop
sudo sed -i '/casper/d' extract-cd/casper/filesystem.manifest-desktop


#Compress the filesystem
# Delete any existing squashfs - normally nothing to delete/rm.
sudo rm -fr extract-cd/casper/filesystem.squashfs
sudo mksquashfs edit extract-cd/casper/filesystem.squashfs -b 1048576
#sudo mksquashfs edit extract-cd/casper/filesystem.squashfs -b 1048576 -e edit/boot


#"Update the filesystem.size file, which is needed by the installer"
printf $(sudo du -sx --block-size=1 edit | cut -f1) | sudo tee extract-cd/casper/filesystem.size

echo #"Chnage old MD5SUMS and calculate new MD5SUMS"
cd extract-cd
sudo rm -f md5sum.txt 2>&1
find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee md5sum.txt >/dev/null 2>&1

# MD5SUMS 7줄 이후 삭제
sudo sed -i '7,$d' MD5SUMS
cat md5sum.txt >> MD5SUMS

#"Create the ISO image"
#manpage for genisoimage http://manpages.ubuntu.com/manpages/trusty/man1/genisoimage.1.html
#original
#sudo genisoimage -D -r -V "$IMAGE_NAME" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o ../$IMAGE_NAME.iso .

#from EFI Q&A: https://askubuntu.com/questions/457528/how-do-i-create-an-efi-bootable-iso-of-a-customized-version-of-ubuntu
#sudo mkisofs -U -A "Custom1604" -V "Custom1604" -volset "Custom1604" -J -joliet-long -r -v -T -o ../Custom1604.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot .

# From https://linuxconfig.org/legacy-bios-uefi-and-secureboot-ready-ubuntu-live-image-customization
# THIS WORKS for creating a .iso that can boot a PC from USB after dd to the USB drive, and as a file referenced as the boot image for a VM (e.g. VirtualBox)
sudo xorriso -volid HamoniKR -volset_id HamoniKR -as mkisofs -isohybrid-mbr isolinux/isohdpfx.bin -c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -isohybrid-gpt-basdat -o $WORK_PATH/custom-img/$IMAGE_NAME .

# Not necessary, but you can check that a bootable partition is visible to fdisk.
# If no bootable partiction is visible to fdisk, my experience is that the ISO will not boot from USB.
# If so, we should be good to go.
sudo fdisk -lu $WORK_PATH/custom-img/$IMAGE_NAME


echo "#### finish time ####"
echo "[$start_time] Start Time "
echo "[$(date +%F\ \%T)] end Time "


# language change
export LANG=$DEFAULT_LANG


# Extract the CD .iso contents
#echo "####Mounting the .iso as 'mnt' in the local directory. Password-up, please.####"
#sudo mount -o loop $WORK_PATH/custom-img/edit/mnt
