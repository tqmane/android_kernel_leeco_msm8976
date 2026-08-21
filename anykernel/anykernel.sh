### AnyKernel3 Ramdisk Mod Script
## LeEco Le 2 (s2) Docker-enabled kernel

properties() { '
kernel.string=LeEco Le 2 Docker Kernel
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=s2
device.name2=le_s2
device.name3=le_s2_ww
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

# s2 is a legacy non-A/B device. AnyKernel3 resolves the boot by-name node.
BLOCK=boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh;

dump_boot;
write_boot;
