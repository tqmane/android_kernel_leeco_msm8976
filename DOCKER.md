# Docker/container support for LeEco Le 2 (s2)

This branch keeps `arch/arm64/configs/lineage_s2_defconfig` as the canonical
LineageOS base config and layers `arch/arm64/configs/lineage_s2_docker.config`
on top for the dedicated Docker build.

## Android 11 boot-safe profile

The default Docker fragment intentionally keeps `CONFIG_CPUSETS` and the
`CONFIG_MEMCG*` family disabled.

Enabling those controllers in this old 3.10 tree exposes two dormant/incomplete
Android backports: a duplicate memory-cgroup `allow_attach` implementation and
a cpuset hotplug path that references a `cpus_requested` field that is not
implemented by the rest of this tree. A previous build-time source-rewrite
workaround made that configuration compile, but the resulting kernel failed to
boot LineageOS 18.1 correctly on the device. The plain `lineage_s2_defconfig`
build boots, so the default Docker profile now avoids those unsafe source paths
instead of rewriting kernel sources during CI.

This means the first boot-safe Docker profile does **not** provide Docker memory
limits, swap limits, or cpuset-based CPU pinning. Core namespaces, the devices
and freezer cgroup-v1 controllers, veth/bridge, netfilter/NAT, IPVS, IPC,
seccomp, blkio/accounting controls and related container networking support
remain enabled. CPUSET/MEMCG should only be restored after proper source
backports are implemented and tested on hardware.

## Build with GitHub Actions

After this change is on the selected branch:

1. Open **Actions**.
2. Select **Build Docker kernel (s2)**.
3. Choose **Run workflow** and select the branch to test.
4. Download the produced artifact.

The artifact contains:

- a flashable `LeEco-Le2-s2-DockerKernel-*-AnyKernel3.zip`;
- raw `Image.gz` and `Image.gz-dtb`;
- the final generated `kernel.config`;
- every DTB produced by the enabled s2 configuration (including `s2.dtb`);
- SHA-256 manifests.

The workflow is intentionally `workflow_dispatch` only. It does not run on
pushes or pull requests.

The workflow also verifies both enabled options and the boot-safety options
that are explicitly required to remain disabled after Kconfig dependency
resolution.

## Storage driver note

This tree does not provide OverlayFS, so `overlay2` is not available without a
separate filesystem backport. Start with Docker's `vfs` storage driver in the
Linux chroot, for example:

```json
{
  "storage-driver": "vfs"
}
```

`vfs` is slower and uses more storage than `overlay2`, but it avoids adding a
large filesystem backport to the device kernel.

## Android/chroot note

Kernel support alone does not mount cgroup controllers for a Linux chroot.
Before starting `dockerd`, the Android/root-side setup must expose `/proc`,
`/sys`, `/dev`, `/dev/pts` and the available cgroup v1 controllers inside the
chroot. Networking also needs IPv4 forwarding and the usual bridge/NAT setup.

The AnyKernel3 ZIP only replaces the kernel while preserving the existing boot
ramdisk. Device checks are limited to the LineageOS s2 aliases: `s2`, `le_s2`
and `le_s2_ww`.
