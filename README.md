# kikiaosp_kernel

此仓库只负责生成 KikiAOSP 测试设备的 AArch64 Linux 内核，不包含 Android 系统镜像、QEMU 补丁或 Windows 启动逻辑。Android 设备树与系统构建见 [kikiaosp_test](https://github.com/kekeqwq/kikiaosp_test)，取得镜像、打包与启动见 [KikiEmu](https://github.com/kekeqwq/KikiEmu)。

当前功能基线为 Linux 7.3-rc4、4 KiB 页、`CONFIG_LOCALVERSION=-4k`，包含 QEMU `virt` 所需 VirtIO/DRM/Binder/F2FS 和 Android 17 `netd` 使用的 legacy iptables 内建选项。`kernelPatches` 还会应用 `virtio-gpu-wait-for-edid-before-hotplug.patch`：显示尺寸变化时同时等待 EDID 与 display-info 响应，再通知 DRM 用户空间，避免 HWC 在旧 EDID 上完成热插拔探测。源码修订、哈希、内核配置和补丁都由 `flake.nix` 与 `flake.lock` 固定。

在 x86_64 Linux 构建机上安装 Nix 并启用 flakes 后运行：

```bash
git clone https://github.com/kekeqwq/kikiaosp_kernel.git
cd kikiaosp_kernel
nix build
ls -lh result/boot/kernel result/boot/config result/boot/vmlinux
sha256sum result/boot/kernel
```

已在 185 开发机从当前 flake 构建出的内核 SHA-256 是 `e7ede20ab411b628f59f5345a7fa5da1155cd2a0a40dad45247f9498cacca06b`，大小 35,613,184 字节；对应 Nix store 输出为 `/nix/store/anly2w980z9w00f8vdq8vm8gls31ph7l-kikiaosp-kernel-7.3-rc4`。`nix build --no-link --print-out-paths .` 已再次命中该输出。它与 KikiAOSP/QEMU 主线共同实测了 864×1728、2784×1876 和 2374×1530 的动态切换。构建前后检查 `CONFIG_ARM64_4K_PAGES=y`、legacy netfilter 选项与客机 `uname -a`；如升级 Linux，应另开分支并重新验证 Windows 图形基线。

此 flake 的默认产物在 `result/boot/kernel`，Windows 打包仓库的收集脚本会从构建机取得它。`result/` 是本地 Nix 构建链接，不应提交 Git。

## Ethernet 与扬声器功能分支

`feature/network-audio-20260926` 在原有 4 KiB、netfilter 和 VirtIO GPU 配置上增加内建 `CONFIG_SND_VIRTIO=y`。这是 QEMU `virtio-sound-pci` 的 ALSA 播放设备，预期为 card 0/device 0；声音还需要配套 Android 设备树和 Windows QEMU 的 DirectSound 参数。

```bash
nix build .#default --out-link result-network-audio -L
grep '^CONFIG_SND_VIRTIO=y$' result-network-audio/boot/config
sha256sum result-network-audio/boot/kernel
```

构建配置显示选项开启不等于客机已识别声卡；需在 Windows 启动匹配镜像后核对 `/proc/asound/cards` 与 `/dev/snd/pcmC0D0p`，再播放实际 PCM 验证。

185 上该功能分支的 Nix 构建已完成：`result-network-audio/boot/kernel` 为 35,613,184 字节，SHA-256 `bbbf873b85fef920faa49e566c0f356c83817e88e51fb210c05aa21fb3fe406d`；`System.map` 含 `virtio_snd` 的内建 initcall。Windows 客机声卡与播放仍待实测。
