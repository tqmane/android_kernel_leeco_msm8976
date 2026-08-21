# Docker/container support for LeEco Le 2 (s2)

This branch keeps `arch/arm64/configs/lineage_s2_defconfig` as the canonical
LineageOS base config and layers `arch/arm64/configs/lineage_s2_docker.config`
on top for the dedicated Docker build.

## Build with GitHub Actions

After this change is on the default branch:

1. Open **Actions**.
2. Select **Build Docker kernel (s2)**.
3. Choose **Run workflow**.
4. Download the produced artifact.

The artifact contains:

- a flashable `LeEco-Le2-s2-DockerKernel-*-AnyKernel3.zip`;
- raw `Image.gz` and `Image.gz-dtb`;
- the final generated `kernel.config`;
- every DTB produced by the enabled s2 configuration (including `s2.dtb`);
- SHA-256 manifests.

The workflow is intentionally `workflow_dispatch` only. It does not run on
pushes or pull requests.

## Docker-related kernel configuration

The Docker config fragment enables the namespace, cgroup v1, veth/bridge,
netfilter/NAT, IPVS, IPC and seccomp functionality required for a practical
Docker/runc environment on this Linux 3.10 kernel.

The workflow verifies that every requested option survives Kconfig dependency
resolution before compiling.

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
`/sys`, `/dev`, `/dev/pts` and the needed cgroup v1 controllers inside the
chroot. Networking also needs IPv4 forwarding and the usual bridge/NAT setup.

The AnyKernel3 ZIP only replaces the kernel while preserving the existing boot
ramdisk. Device checks are limited to the LineageOS s2 aliases: `s2`, `le_s2`
and `le_s2_ww`.
