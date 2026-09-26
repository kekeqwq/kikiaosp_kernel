{
  description = "KikiAOSP ARM64 Linux kernel 7.3-rc4";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        crossSystem = { config = "aarch64-unknown-linux-gnu"; };
      };
      lib = pkgs.lib;

      kikiConfig = with lib.kernel; {
        ARM64_4K_PAGES = yes; ARM64_16K_PAGES = no; ARM64_64K_PAGES = no;
        LOCALVERSION = "\"-4k\""; ARM64_VA_BITS_48 = yes; ARM64_PA_BITS_48 = yes;
        ACPI = yes; ACPI_GENERIC_GSI = yes; ACPI_PROCESSOR = yes; ACPI_HOTPLUG_CPU = yes;
        SECURITY_SELINUX_DEVELOP = yes;
        VIRTIO = yes; VIRTIO_PCI = yes; VIRTIO_BLK = yes; VIRTIO_NET = yes;
        VIRTIO_BALLOON = yes; VIRTIO_INPUT = yes; VIRTIO_MMIO = yes;
        VIRTIO_CONSOLE = yes; HW_RANDOM_VIRTIO = yes; VIRTIO_VSOCKETS = yes;
        # QEMU virtio-sound exposes the single playback PCM used by the
        # upstream AIDL primary audio HAL (ALSA card 0, device 0).
        SND = yes; SND_PCM = yes; SND_VIRTIO = yes;
        HYPERV_VSOCKETS = yes;
        DEVTMPFS = yes; DEVTMPFS_MOUNT = yes; TMPFS = yes; TMPFS_POSIX_ACL = yes; TMPFS_XATTR = yes;
        MD = yes; BLK_DEV_DM = yes; DM_VERITY = yes; DM_VERITY_AVB = yes; DM_BOW = yes; DM_USER = yes;
        HYPERVISOR_GUEST = yes; HYPERV = yes; HYPERV_TIMER = yes; HYPERV_UTILS = yes;
        HYPERV_BALLOON = yes; HYPERV_STORAGE = yes; HYPERV_NET = yes; HYPERV_KEYBOARD = yes;
        HID_HYPERV_MOUSE = yes; DRM_HYPERV = yes; FB_HYPERV = yes; PCI_HYPERV = yes;
        PCI_HYPERV_INTERFACE = yes;
        SCSI = yes; BLK_DEV_SD = yes; SCSI_SCAN_ASYNC = yes;
        SERIAL_EARLYCON = yes; SERIAL_8250 = yes; SERIAL_8250_CONSOLE = yes;
        SERIAL_8250_NR_UARTS = 8; SERIAL_8250_RUNTIME_UARTS = 4;
        SERIAL_AMBA_PL011 = yes; SERIAL_AMBA_PL011_CONSOLE = yes; PRINTK = yes; PRINTK_TIME = yes;
        ANDROID_BINDER_IPC = yes; ANDROID_BINDERFS = yes;
        ANDROID_BINDER_DEVICES = "\"binder,hwbinder,vndbinder\"";
        ASHMEM = no; MEMFD_CREATE = yes;
        # Android 17 netd still uses iptables-legacy. Linux 7.3 split its
        # legacy IPv4/IPv6 evaluators from the old IP*_NF_IPTABLES symbols.
        # Build the tables in so netd can initialize before module loading.
        NETFILTER_XTABLES_LEGACY = yes;
        IP_NF_IPTABLES_LEGACY = yes;
        IP6_NF_IPTABLES_LEGACY = yes;
        NF_NAT = yes;
        IP_NF_FILTER = yes;
        IP_NF_MANGLE = yes;
        IP_NF_RAW = yes;
        IP_NF_NAT = yes;
        IP_NF_TARGET_REJECT = yes;
        IP_NF_TARGET_MASQUERADE = yes;
        IP_NF_TARGET_REDIRECT = yes;
        IP6_NF_FILTER = yes;
        IP6_NF_MANGLE = yes;
        IP6_NF_RAW = yes;
        IP6_NF_TARGET_REJECT = yes;
        EROFS_FS = yes; EROFS_FS_ZIP = yes; EROFS_FS_ZIP_LZMA = yes;
        F2FS_FS = yes; EXT4_FS = yes; OVERLAY_FS = yes; SQUASHFS = yes;
        DRM = yes; DRM_VIRTIO_GPU = yes; DRM_FBDEV_EMULATION = yes;
        DRM_SIMPLEDRM = yes; FB_SIMPLE = yes; SYSVIPC = yes;
        BLK_DEV_INITRD = yes; RD_GZIP = yes; RD_BZIP2 = yes; RD_LZMA = yes;
        RD_XZ = yes; RD_LZO = yes; RD_LZ4 = yes; RD_ZSTD = yes;
      };

      renderOption = name: value:
        let rendered =
          if value == lib.kernel.yes then "y"
          else if value == lib.kernel.no then "n"
          else if value == lib.kernel.module then "m"
          else toString value;
        in "CONFIG_${name}=${rendered}";

      configfile = pkgs.writeText "kikiaosp-7.3-rc4.config" (
        builtins.readFile ./gki_defconfig
        + "\n# KikiAOSP declarative overrides\n"
        + lib.concatStringsSep "\n" (lib.mapAttrsToList renderOption kikiConfig)
        + "\n"
      );

      kernel = pkgs.linuxManualConfig {
        version = "7.3.0-rc4-kikiaosp";
        modDirVersion = "7.3.0-rc4-4k";
        src = pkgs.fetchFromGitHub {
          owner = "torvalds";
          repo = "linux";
          rev = "dec005ae90a2946656a090f37bf1cfbd22f08e57";
          hash = "sha256-+Sn0tYDuDDEujGigwoUu02dtpXGNxuJmeAY03RE/TS8=";
        };
        inherit configfile;
        allowImportFromDerivation = true;
        kernelPatches = [
          {
            name = "virtio-gpu-wait-for-edid-before-hotplug";
            patch = ./patches/virtio-gpu-wait-for-edid-before-hotplug.patch;
          }
        ];
      };

      # Preserve the artifact layout consumed by the existing KikiAOSP/QEMU
      # scripts while reusing linuxManualConfig's separate outputs.
      kernelBundle = pkgs.runCommand "kikiaosp-kernel-7.3-rc4" { } ''
        mkdir -p $out/boot $out/modules
        cp ${kernel}/Image $out/boot/kernel
        cp ${kernel}/System.map $out/boot/System.map
        cp ${kernel.dev}/vmlinux $out/boot/vmlinux
        cp ${configfile} $out/boot/config
        cp -a ${kernel}/dtbs $out/dtbs
        cp -a ${kernel.modules}/lib $out/modules/
      '';
    in { packages.${system}.default = kernelBundle; };
}
