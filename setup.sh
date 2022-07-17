#!/bin/sh

. create_root_subr.sh

MDSIZE="10g"
ROOTPREFIX="temproot"

UFSMOUNT=$MNT
UFSSIZE="20g"

KERNSRC="/usr/src"
KERNCONF="PERF"

ROOTDST="root.tar"
DNSRESOLVER="8.8.8.8"

setupufs() {

    UFSDISKPATH=$1
    UFSMOUNT=$2

    # Create a memdisk for the root
    newfs $UFSDISKPATH

    # Create a temporary mountpoint
    mount -t ufs $UFSDISKPATH $UFSMOUNT
}

teardownufs(){
    # Destroy the UFS root
    UFSMD=$1
    UFSMOUNT=$2

    umount $UFSMOUNT

    mdconfig -d -u $UFSMD
}

setup_bash()
{
    MNTROOT=$1
    CMD="chsh -s /usr/local/bin/bash"

    run_chroot_cmd $MNTROOT "${CMD}"
}

install_deps()
{
    MNTROOT=$1

    install_package $MNTROOT bash
    install_package $MNTROOT python
    install_package $MNTROOT git
    install_package $MNTROOT vim
}

install_python_deps()
{
    MNTROOT=$1

    # Install these as packages since they're available
    install_package $MNTROOT py38-six
    install_package $MNTROOT py38-boto3
    install_package $MNTROOT py38-minio
    install_package $MNTROOT py38-google
}

config_boot_loader_conf()
{
    cat loader.conf >> $MNTROOT/boot/loader.conf
}

config_etc_rc_conf()
{
    cat rc.conf >> $MNTROOT/etc/rc.conf
}

# Add the necessary Aurora configs in .profile

BSDINSTALL_DISTDIR="/usr/freebsd-dist"
BASE=`fetch_base $BSDINSTALL_DISTDIR`

UFSMD=`mdconfig -a -t malloc -s $MDSIZE`
UFSDISKPATH="/dev/$UFSMD"

UFSMOUNT=`mktemp -d $ROOTPREFIX.XXX`

setupufs $UFSDISKPATH $UFSMOUNT
unpack_base $UFSMOUNT $BASE
mount_pseudofs $UFSMOUNT

configure_dns $UFSMOUNT $DNSRESOLVER
install_deps $UFSMOUNT
install_python_deps $UFSMOUNT

setup_bash $UFSMOUNT

config_boot_loader_conf $UFSMOUNT
config_etc_rc_conf $UFSMOUNT

# Install the kernel
cd $KERNSRC
make -j9 NO_CLEAN=yes KERNCONF=$KERNCONF DESTDIR=$UFSMOUNT kernel 
cd -

# Unmount devfs/procfs to avoid adding garbage to the tarball
umount_pseudofs $UFSMOUNT
pack_base $UFSMOUNT $ROOTDST

teardownufs $UFSMD $UFSMOUNT
rmdir $UFSMOUNT


