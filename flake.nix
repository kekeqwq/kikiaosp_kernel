{
  description = "Minimal Linux 7.3 Mainline Kernel for KikiEmu on Microsoft Surface Pro 11 (ARM64)";

  inputs = {
    nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/refs/heads/nixos-unstable.tar.gz";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        crossSystem = {
          config = "aarch64-unknown-linux-gnu";
        };
      };
      nativePkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation rec {
        pname = "linux-android-hyperv";
        # Phase A baseline: Hyper-V/WHPX has only been verified with a 4 KiB
        # guest. 16 KiB remains a separate experiment, never a release gate.
        version = "7.3.0-rc3-kikiemu-4k";

        src = ./linux-7.3-rc3-src;

        nativeBuildInputs = with nativePkgs; [
          stdenv.cc
          bc
          bison
          flex
          openssl
          libelf
          elfutils
          zlib
          perl
          python3
          gmp
          mpfr
          libmpc
          kmod
          pkg-config
        ];

        # Defconfig preparation
        configurePhase = ''
          chmod -R +w .
          chmod -R +w arch/arm64/configs
          export ARCH=arm64
          # Diagnostic Android bring-up: force SELinux permissive and bypass
          # init SID/access failures. This is not a production security mode.
          if [ -f /home/keke/Repos/build_test/patch_selinux_full.py.disabled ]; then
            python3 /home/keke/Repos/build_test/patch_selinux_full.py.disabled .
          fi

          export CROSS_COMPILE=aarch64-unknown-linux-gnu-
          export HOSTCC=${nativePkgs.stdenv.cc}/bin/gcc
          export HOSTCFLAGS="-I${nativePkgs.elfutils.dev}/include -I${nativePkgs.openssl.dev}/include -I${nativePkgs.libelf}/include -I${nativePkgs.zlib.dev}/include"
          export HOSTLDFLAGS="-L${nativePkgs.elfutils.out}/lib -L${nativePkgs.openssl.out}/lib -L${nativePkgs.libelf}/lib -L${nativePkgs.zlib.out}/lib"

          echo "Applying base Android GKI defconfig..."
          cat ${./gki_defconfig} > arch/arm64/configs/kikiemu_defconfig
          chmod +w arch/arm64/configs/kikiemu_defconfig

          # Append 4KB baseline, APEX Device-Mapper, VirtIO and Hyper-V configs.
          cat >> arch/arm64/configs/kikiemu_defconfig << 'DEFCFG'
# KikiEmu Snapdragon X Elite 4K Page Table (verified WHPX baseline)
CONFIG_ARM64_4K_PAGES=y
CONFIG_ARM64_16K_PAGES=n
CONFIG_ARM64_64K_PAGES=n
CONFIG_LOCALVERSION="-4k"
CONFIG_ARM64_VA_BITS_48=y
CONFIG_ARM64_PA_BITS_48=y

# Hyper-V ARM64 presents VMBus, SCSI and the synthetic COM device through
# ACPI tables.  Keep ACPI built in for LinuxKernelDirect guest enumeration.
CONFIG_ACPI=y
CONFIG_ACPI_GENERIC_GSI=y
CONFIG_ACPI_PROCESSOR=y
CONFIG_ACPI_HOTPLUG_CPU=y

# SELinux Development / Permissive
CONFIG_SECURITY_SELINUX_DEVELOP=y

# VirtIO devices
CONFIG_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BLK=y
CONFIG_VIRTIO_NET=y
CONFIG_VIRTIO_BALLOON=y
CONFIG_VIRTIO_INPUT=y
CONFIG_VIRTIO_MMIO=y
CONFIG_VIRTIO_CONSOLE=y
CONFIG_HW_RANDOM_VIRTIO=y
CONFIG_VIRTIO_VSOCKETS=y
CONFIG_HYPERV_VSOCKETS=y

# Devtmpfs (Mandatory for initramfs /dev population)
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_TMPFS_XATTR=y

# Device Mapper for Android APEX
CONFIG_MD=y
CONFIG_BLK_DEV_DM=y
CONFIG_DM_VERITY=y
CONFIG_DM_VERITY_AVB=y
CONFIG_DM_BOW=y
CONFIG_DM_USER=y

# Microsoft Hyper-V VMBus & Synthetic Hardware Driver Suite
CONFIG_HYPERVISOR_GUEST=y
CONFIG_HYPERV=y
CONFIG_HYPERV_TIMER=y
CONFIG_HYPERV_UTILS=y
CONFIG_HYPERV_BALLOON=y
CONFIG_HYPERV_STORAGE=y
CONFIG_HYPERV_NET=y
CONFIG_HYPERV_KEYBOARD=y
CONFIG_HID_HYPERV_MOUSE=y
CONFIG_DRM_HYPERV=y
CONFIG_FB_HYPERV=y
CONFIG_PCI_HYPERV=y
CONFIG_PCI_HYPERV_INTERFACE=y

# SCSI Disks (Hyper-V SCSI Virtual Hard Disks)
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_SCSI_SCAN_ASYNC=y

# Serial Ports, Earlycon and Console
CONFIG_SERIAL_EARLYCON=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SERIAL_8250_NR_UARTS=8
CONFIG_SERIAL_8250_RUNTIME_UARTS=4
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
CONFIG_PRINTK=y
CONFIG_PRINTK_TIME=y

# Android IPC & Foundation
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
CONFIG_ASHMEM=n
CONFIG_MEMFD_CREATE=y

# Filesystems
CONFIG_EROFS_FS=y
CONFIG_EROFS_FS_ZIP=y
CONFIG_EROFS_FS_ZIP_LZMA=y
CONFIG_F2FS_FS=y
CONFIG_EXT4_FS=y
CONFIG_OVERLAY_FS=y
CONFIG_SQUASHFS=y

# DRM Graphics & VirtIO-GPU
CONFIG_DRM=y
CONFIG_DRM_VIRTIO_GPU=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_FB_SIMPLE=y
CONFIG_SYSVIPC=y

# Complete Ramdisk Decompressors (Essential for Android initramfs)
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_RD_BZIP2=y
CONFIG_RD_LZMA=y
CONFIG_RD_XZ=y
CONFIG_RD_LZO=y
CONFIG_RD_LZ4=y
CONFIG_RD_ZSTD=y
DEFCFG

          make kikiemu_defconfig
          # Required options are encoded in kikiemu_defconfig. Do not invoke
          # scripts/config: its /usr/bin/env shebang is unavailable here.
          make olddefconfig
        '';

        buildPhase = ''
          # Build the module tree together with the kernel. Android's first
          # stage init validates module ABI, so an Image alone can never be a
          # safe replacement for a Cuttlefish vendor_dlkm module set.
          make -j$(nproc) Image vmlinux modules
        '';

        installPhase = ''
          mkdir -p $out/boot
          cp arch/arm64/boot/Image $out/boot/kernel
          cp vmlinux $out/boot/vmlinux
          cp System.map $out/boot/System.map
          cp .config $out/boot/config
          make INSTALL_MOD_PATH=$out/modules modules_install
          # modules_install adds build/source links back to this ephemeral
          # derivation directory. They are not needed at runtime and make the
          # Nix output invalid once the build tree disappears.
          rm -f $out/modules/lib/modules/*/build $out/modules/lib/modules/*/source
          echo "Build complete: $out/boot/kernel"
        '';

        dontStrip = true;
      };
    };
}
