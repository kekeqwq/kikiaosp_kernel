# kikiaosp_kernel

此仓库只负责生成 KikiAOSP 测试设备的 AArch64 Linux 内核，不包含 Android 系统镜像、QEMU 补丁或 Windows 启动逻辑。Android 设备树与系统构建见 [kikiaosp_test](https://github.com/kekeqwq/kikiaosp_test)，取得镜像、打包与启动见 [KikiEmu](https://github.com/kekeqwq/KikiEmu)。

本分支固定 Linux 7.3-rc6、4 KiB 页、`CONFIG_LOCALVERSION=-4k`；已发布 0.2 使用的 rc5 基线保持不变。配置包含 QEMU `virt` 所需 VirtIO/DRM/Binder/F2FS 和 Android 17 `netd` 使用的 legacy iptables 内建选项。`kernelPatches` 会应用 `virtio-gpu-wait-for-edid-before-hotplug.patch`：显示尺寸变化时同时等待 EDID 与 display-info 响应，再通知 DRM 用户空间，避免 HWC 在旧 EDID 上完成热插拔探测。GPU 分支另加 `drm-crtc-fence-signaled-ops-race.patch`，修正 fence 完成时 `fence->ops` 被清空而 CRTC 命名回调重复检查它所致的 panic；该修正仍需长时实测。源码修订、哈希、内核配置和补丁都由 `flake.nix` 与 `flake.lock` 固定。

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

## 历史主线：Ethernet、扬声器与界面音效

主线内核在 4 KiB、legacy netfilter 和 VirtIO GPU EDID 同步之外，内建：

- `CONFIG_SND_VIRTIO=y`：QEMU `virtio-sound-pci` 的 ALSA 播放设备，card 0/device 0
- `CONFIG_DMA_SHARED_BUFFER=y`、`CONFIG_DMABUF_HEAPS=y`、`CONFIG_DMABUF_HEAPS_SYSTEM=y`：提供 `/dev/dma_heap/system`。Codec2 的 Vorbis 软解从这里分配缓冲区；没有该设备时 PCM 仍能播放，但点按音和铃声试听会返回 `NO_MEMORY`

```bash
nix build
grep -E '^(CONFIG_SND_VIRTIO|CONFIG_DMABUF_HEAPS|CONFIG_DMABUF_HEAPS_SYSTEM)=y$' result/boot/config
sha256sum result/boot/kernel
```

185 上当前主线产物为 35,613,184 字节，SHA-256 `f33ef2371736dfd75122eaaf277223321117b57e572e235b5b35f558aa14db96`，Nix store 输出 `/nix/store/il48832z3s2734ix3fx1xfjfbrkw71s7-kikiaosp-kernel-7.3-rc4`。Windows 客机已确认声卡播放、设置里的点按音，以及铃声选择器试听。

## 历史主线：VirtIO GPU fence 修复与性能验证

GPU 加速分支的 `drm-crtc-fence-signaled-ops-race.patch` 已并入主线，并纳入 `kernelPatches` 的可复现构建。它针对 VirtIO GPU / DRM fence 完成回调中的竞态；仍需继续做长时间压力测试，不能把一次启动或帧率测试当作竞态覆盖证明。

端到端验证使用本内核、AOSP 设备树和 KikiEmu 中记录的测试配置。Android 动画基准预热后连续 30 秒的应用帧回调率为 70.36–110.89 FPS，中位数 80.53 FPS，证明当前 VirGL 渲染路径已实际工作且该窗口内高于 60 FPS。此数字是应用帧回调采样，不等于 Windows DWM/面板实际呈现帧率，也不是内核单独的性能指标。桌面、设置和通知栏的交互仍有明显端到端延迟；当前证据不足以将延迟归因于内核，后续应从整条输入—合成—呈现链路继续定位。

## rc6（未发布）

官方 `v7.3-rc6` 解引用修订为 `a90ee4305c4a5df72c11b31dacfdc76e00fcf78a`，Nix source SRI 为 `sha256-310GZztrJw+mkRFQ3IQ1pvTafElqHVKU0HMcZDk1x2c=`。实际构建冻结修订 `f8020a4c6da14b98b285da2c3c5f2ab96a772486`，保留 rc5 的 flake.lock、4 KiB 配置及两份 GPU 补丁，不做性能优化。

Nix 构建退出 0，Image 35,613,184 字节，SHA256 `38c6ad1d6cffc76af1f4b6ce66ba42db4d8865b0f60b842fd147bef52b3a5b7c`，bundle `/nix/store/zc9rj6inia8d682j73iqq05cxagm2233-kikiaosp-kernel-7.3-rc6`，实际 module release `7.3.0-rc6-4k`。声明配置与最终 dev `.config` 分开核验，后者见 Nix dev 输出的 `lib/modules/7.3.0-rc6-4k/build/.config`。Windows 实例验证证据由 KikiEmu 的本轮工作记录维护；编译成功不代替实例验证或长时 GPU 竞态覆盖。

没有 main 合并、rc6 标签或公开 Release；0.1/0.2 资产不变。
