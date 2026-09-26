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

动态分辨率验证时的内核 SHA-256 是 `e7ede20ab411b628f59f5345a7fa5da1155cd2a0a40dad45247f9498cacca06b`，大小 35,613,184 字节，Nix store 为 `/nix/store/anly2w980z9w00f8vdq8vm8gls31ph7l-kikiaosp-kernel-7.3-rc4`。它与当时的系统镜像实测了 864×1728、2784×1876 和 2374×1530 的动态切换。当前主线保留该 EDID 补丁、4 KiB 页和 legacy netfilter，并加入 virtio-sound 与 dma-buf system heap；产物见下一节。升级 Linux 时应另开分支，并重新验证 Windows 图形基线。

此 flake 的默认产物在 `result/boot/kernel`，Windows 打包仓库的收集脚本会从构建机取得它。`result/` 是本地 Nix 构建链接，不应提交 Git。

## 主线：Ethernet、扬声器与界面音效

主线内核在 4 KiB、legacy netfilter 和 VirtIO GPU EDID 同步之外，内建：

- `CONFIG_SND_VIRTIO=y`：QEMU `virtio-sound-pci` 的 ALSA 播放设备，card 0/device 0
- `CONFIG_DMA_SHARED_BUFFER=y`、`CONFIG_DMABUF_HEAPS=y`、`CONFIG_DMABUF_HEAPS_SYSTEM=y`：提供 `/dev/dma_heap/system`。Codec2 的 Vorbis 软解从这里分配缓冲区；没有该设备时 PCM 仍能播放，但点按音和铃声试听会返回 `NO_MEMORY`

```bash
nix build
grep -E '^(CONFIG_SND_VIRTIO|CONFIG_DMABUF_HEAPS|CONFIG_DMABUF_HEAPS_SYSTEM)=y$' result/boot/config
sha256sum result/boot/kernel
```

185 上当前主线产物为 35,613,184 字节，SHA-256 `f33ef2371736dfd75122eaaf277223321117b57e572e235b5b35f558aa14db96`，Nix store 输出 `/nix/store/il48832z3s2734ix3fx1xfjfbrkw71s7-kikiaosp-kernel-7.3-rc4`。Windows 客机已确认声卡播放、设置里的点按音，以及铃声选择器试听。
