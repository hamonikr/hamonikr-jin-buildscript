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


# hamonikr.conf 리셋(reset hamonikr.conf)
echo "work_path:$WORK_PATH" > $CONF
echo "down_url:$DOWN_URL" >> $CONF
echo "input_iso:$CDIMAGENAME" >> $CONF
echo "output_iso:$IMAGE_NAME" >> $CONF


echo "####install & file setting####"
start_time=$(date +%F\ \%T)
echo "[$start_time] Starting"

# 언어 변환(language change)
DEFAULT_LANG=$LANG
export LANG=en_US.UTF-8
export LC_ALL=C


# git --version  >/dev/null 2>&1 || { echo >&2 "Please install git - apt install git "; exit 1; }
xorriso -version  >/dev/null 2>&1 || { sudo apt-get install xorriso -y; }


# 베이스 OS 파일이 있는지 확인(file check)
if [ ! -f $CDIMAGENAME ]
then
        echo "#### found $CDIMAGENAME - start download"
        wget $DOWN_URL
fi

cd $WORK_PATH


# 파일이 없어 에러 발생 - 에러 방지용 폴더 생성
# 폴더 구성이 완료되면 해당 코드 삭제 필요
mkdir -p resource/deb/install_after
mkdir -p resource/edit
mkdir -p resource/extract-cd/casper/initrd-tmp


# 이전 작업폴더가 있을경우 삭제후 재생성
sudo rm -rf custom-img
mkdir -p $WORK_PATH/custom-img/mnt
cd custom-img


sudo mount -o loop $WORK_PATH/$CDIMAGENAME mnt
sudo rsync --exclude=/casper/filesystem.squashfs -a mnt/ extract-cd
sudo dd if=$WORK_PATH/$CDIMAGENAME bs=512 count=1 of=extract-cd/isolinux/isohdpfx.bin
sudo unsquashfs mnt/casper/filesystem.squashfs
sudo mv squashfs-root edit
sudo umount mnt


# 리소스 복사
sudo cp -r $WORK_PATH/resource/* $WORK_PATH/custom-img/
sudo cp -r $WORK_PATH/script $WORK_PATH/custom-img/edit/
#sudo mv $WORK_PATH/custom-img/deb $WORK_PATH/custom-img/edit/


echo "###### chroot start ######"
# chroot 사용하기 전 설정 (Prepare and chroot)
sudo cp /etc/resolv.conf edit/etc/
sudo mount --bind /dev/ edit/dev

# sudo chroot edit /bin/bash는 외부에서 내부에 있는 쉘을 사용할 수 있게 해준다.
cat << EOF | sudo chroot edit /bin/bash

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts

# "To avoid locale issues and in order to import GPG keys..."
export RUNLEVEL=1
export LANGUAGE="ko_KR:ko"
export LC_CTYPE="ko_KR.UTF-8"
export LC_MESSAGES="ko_KR.UTF-8"
export LC_ALL="ko_KR.UTF-8"
export LC_TIME="ko_KR.UTF-8"
export LC_MONETARY="ko_KR.UTF-8"
export LC_ADDRESS="ko_KR.UTF-8"
export LC_TELEPHONE="ko_KR.UTF-8"
export LC_NAME="ko_KR.UTF-8"
export LC_MEASUREMENT="ko_KR.UTF-8"
export LC_IDENTIFICATION="ko_KR.UTF-8"
export LC_NUMERIC="ko_KR.UTF-8"
export LC_PAPER="ko_KR.UTF-8"
export LANG="ko_KR.UTF-8"
export HOME=/root
export LC_ALL=C

locale-gen ko_KR.UTF-8 && \
update-locale LANG=ko_KR.UTF-8 LANGUAGE=ko_KR.UTF-8 LC_ALL=ko_KR.UTF-8

ln -fs /usr/share/zoneinfo/Asia/Seoul /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
timedatectl set-local-rtc 1 --adjust-system-clock

dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl


$(
echo 'echo "###### program install start ######"'
echo "sh /script/original/02_system-install"
echo "sh /script/original/03_package-install"
echo "sh /script/original/04_package-delete"
echo "sh /script/original/05_clean"
echo 'echo "###### program install end ######"'
)

#Clean up
sudo rm -rf /tmp/* ~/.bash_history
sudo rm /var/lib/dbus/machine-id
sudo rm /sbin/initctl
sudo dpkg-divert --rename --remove /sbin/initctl

# "now umount (unmount) special filesystems and exit chroot"

sudo mount /proc > /dev/null 2>&1 || umount -lf /proc
sudo umount /sys
sudo umount /dev/pts
EOF

sudo umount edit/dev

echo "vmlinuz-5.4.0-xx-generic 커널 casper에 복사"
sudo cp $WORK_PATH/custom-img/edit/boot/vmlinuz-* $WORK_PATH/custom-img/extract-cd/casper/vmlinuz
sudo cp $WORK_PATH/custom-img/edit/boot/initrd.img-* $WORK_PATH/custom-img/extract-cd/casper/initrd.lz

echo "커널 변경후 casper 작업"
#sudo sh $WORK_PATH/script/original/01_casper


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
sed -i '7,$d' MD5SUMS
find -type f -print0 | sudo xargs -0 md5sum | grep -v isolinux/boot.cat | sudo tee -a MD5SUMS

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
