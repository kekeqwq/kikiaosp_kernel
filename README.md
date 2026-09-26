# kikiaosp_kernel

此仓库只负责生成 KikiAOSP 测试设备的 AArch64 Linux 内核，不包含 Android 系统镜像、QEMU 补丁或 Windows 启动逻辑。Android 设备树与系统构建见 [kikiaosp_test](https://github.com/kekeqwq/kikiaosp_test)，取得镜像、打包与启动见 [KikiEmu](https://github.com/kekeqwq/KikiEmu)。

当前稳定基线为 Linux 7.3-rc4、4 KiB 页、`CONFIG_LOCALVERSION=-4k`，包含 QEMU `virt` 所需 VirtIO/DRM/Binder/F2FS 和 Android 17 `netd` 使用的 legacy iptables 内建选项。源码修订、哈希和内核配置由 `flake.nix` 与 `flake.lock` 固定。

在 x86_64 Linux 构建机上安装 Nix 并启用 flakes 后运行：

```bash
git clone https://github.com/kekeqwq/kikiaosp_kernel.git
cd kikiaosp_kernel
nix build
ls -lh result/boot/kernel result/boot/config result/boot/vmlinux
sha256sum result/boot/kernel
```

已在 185 开发机从当前 flake 构建出的内核 SHA-256 是 `289e12b89f54b143e253e3aaa4411ffc6f681ad5dfbdd2fd73f0e217629d0d45`，大小 35,613,184 字节。`nix build --no-link --print-out-paths .` 与该已测试 Nix store 输出一致。构建前后检查 `CONFIG_ARM64_4K_PAGES=y`、legacy netfilter 选项与客机 `uname -a`；如升级 Linux，应另开分支并重新验证 Windows 图形基线。

此 flake 的默认产物在 `result/boot/kernel`，Windows 打包仓库的收集脚本会从构建机取得它。`result/` 是本地 Nix 构建链接，不应提交 Git。
