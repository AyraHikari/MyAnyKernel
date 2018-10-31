# AnyKernel2 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() {
kernel.string=Yuka Kernel
do.devicecheck=1
do.modules=1
do.cleanup=1
do.cleanuponabort=1
do.system=1
do.initd=1
do.force_encryption=0
do.f2fs_patch=1
do.rem_encryption=0
do.osversion=1
device.name1=land
} # end properties

# shell variables
block=/dev/block/mmcblk0p21;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. /tmp/anykernel/tools/ak2-core.sh;


## AnyKernel file attributes
# set permissions for included ramdisk files
chmod -R 755 $ramdisk
chmod +x $ramdisk/sbin/spa


## AnyKernel install
dump_boot;

# begin ramdisk changes

# fstab.qcom
if [ -e fstab.qcom ]; then
	fstab=fstab.qcom;
elif [ -e /system/vendor/etc/fstab.qcom ]; then
	fstab=/system/vendor/etc/fstab.qcom;
elif [ -e /system/etc/fstab.qcom ]; then
	fstab=/system/etc/fstab.qcom;
fi;

if [ "$(file_getprop $script do.f2fs_patch)" == 1 ]; then
	if [ $(mount | grep f2fs | wc -l) -gt "0" ] &&
	   [ $(cat $fstab | grep f2fs | wc -l) -eq "0" ]; then
		ui_print " "; ui_print "Found fstab: $fstab";
		ui_print "- Adding f2fs support to fstab...";

		insert_line $fstab "data        f2fs" before "data        ext4" "/dev/block/bootdevice/by-name/userdata     /data        f2fs    nosuid,nodev,noatime,inline_xattr,data_flush      wait,check,encryptable=footer,formattable,length=-16384";
		insert_line $fstab "cache        f2fs" after "data        ext4" "/dev/block/bootdevice/by-name/cache     /cache        f2fs    nosuid,nodev,noatime,inline_xattr,flush_merge,data_flush wait,formattable,check";

		if [ $(cat $fstab | grep f2fs | wc -l) -eq "0" ]; then
			ui_print "- Failed to add f2fs support!";
			exit 1;
		fi;
	elif [ $(mount | grep f2fs | wc -l) -gt "0" ] &&
	     [ $(cat $fstab | grep f2fs | wc -l) -gt "0" ]; then
		ui_print " "; ui_print "Found fstab: $fstab";
		ui_print "- F2FS supported!";
	fi;
fi; #f2fs_patch

if [ $(cat $fstab | grep forceencypt | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Force encryption is enabled";
	if [ "$(file_getprop $script do.rem_encryption)" == 0 ]; then
		ui_print "- Force encryption removal is off!";
	else
		ui_print "- Force encryption removal is on!";
	fi;
elif [ $(cat $fstab | grep encryptable | wc -l) -gt "0" ]; then
	ui_print " "; ui_print "Force encryption is not enabled";
	if [ "$(file_getprop $script do.force_encryption)" == 0 ]; then
		ui_print "- Force encryption is off!";
	else
		ui_print "- Force encryption is on!";
	fi;
fi;

if [ "$(file_getprop $script do.rem_encryption)" == 1 ] &&
   [ $(cat $fstab | grep forceencypt | wc -l) -gt "0" ]; then
	sed -i 's/forceencrypt/encryptable/g' $fstab
	if [ $(cat $fstab | grep forceencrypt | wc -l) -eq "0" ]; then
		ui_print "- Removed force encryption flag!";
	else
		ui_print "- Failed to remove force encryption!";
		exit 1;
	fi;
elif [ "$(file_getprop $script do.force_encryption)" == 1 ] &&
     [ $(cat $fstab | grep encryptable | wc -l) -gt "0" ]; then
	sed -i 's/encryptable/forceencrypt/g' $fstab
	if [ $(cat $fstab | grep encryptable | wc -l) -eq "0" ]; then
		ui_print "- Added force encryption flag!";
	else
		ui_print "- Failed to add force encryption!";
		exit 1;
	fi;
fi;

decompressed_image=/tmp/anykernel/kernel/Image
compressed_image=$decompressed_image.gz
# Hexpatch the kernel if Magisk is installed ('skip_initramfs' -> 'want_initramfs')
if [ -d $ramdisk/.backup ]; then
	ui_print " "; ui_print "Magisk detected! Patching kernel so reflashing Magisk is not necessary...";
	$bin/magiskboot --decompress $compressed_image $decompressed_image;
	$bin/magiskboot --hexpatch $decompressed_image 736B69705F696E697472616D6673 77616E745F696E697472616D6673;
	$bin/magiskboot --compress=gz $decompressed_image $compressed_image;
	$bin/magiskboot --dtb-patch /tmp/anykernel/treble*/*;
fi;

# init.rc
backup_file init.rc;
grep "import /init.spectrum.rc" init.rc >/dev/null || sed -i '1,/.*import.*/s/.*import.*/import \/init.spectrum.rc\n&/' init.rc
# end ramdisk changes

write_boot;

## end install

# Add empty profile locations
if [ ! -d /data/media/Spectrum ]; then
	ui_print " "; ui_print "Creating /data/media/0/Spectrum...";
	mkdir /data/media/0/Spectrum;
fi
if [ ! -d /data/media/Spectrum/profiles ]; then
	mkdir /data/media/0/Spectrum/profiles;
fi
if [ ! -d /data/media/Spectrum/profiles/*.profile ]; then
	ui_print " "; ui_print "Creating empty profile files...";
	touch /data/media/0/Spectrum/profiles/balance.profile;
	touch /data/media/0/Spectrum/profiles/performance.profile;
	touch /data/media/0/Spectrum/profiles/battery.profile;
	touch /data/media/0/Spectrum/profiles/gaming.profile;
fi
