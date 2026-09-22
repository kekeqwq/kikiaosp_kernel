# kikiaosp_kernel

Reproducible ARM64 Linux kernel baseline for KikiAOSP. The build is intentionally a 4 KiB page-size baseline for the current WHPX/Windows ARM path.

Clone with the Linux source submodule and build:

    git clone --recurse-submodules https://github.com/kekeqwq/kikiaosp_kernel.git
    cd kikiaosp_kernel
    nix build

The flake pins nixpkgs through lake.lock, uses Linux 7.3-rc3, generates kikiemu_defconfig, and emits esult/boot/kernel, esult/boot/vmlinux, esult/boot/config, and modules.
