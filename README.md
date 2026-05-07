<div align="center">

```
██╗  ██╗ █████╗ ██╗     ███████╗    ██╗   ██╗███╗   ███╗
██║ ██╔╝██╔══██╗██║     ██╔════╝    ██║   ██║████╗ ████║
█████╔╝ ███████║██║     █████╗      ██║   ██║██╔████╔██║
██╔═██╗ ██╔══██║██║     ██╔══╝      ╚██╗ ██╔╝██║╚██╔╝██║
██║  ██╗██║  ██║███████╗███████╗     ╚████╔╝ ██║ ╚═╝ ██║
╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝     ╚═══╝  ╚═╝     ╚═╝
```

**NixOS · nixos-unstable · x86_64 · KVM/QEMU · Waydroid**

![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat-square&logo=nixos&logoColor=white)
![Platform](https://img.shields.io/badge/platform-x86__64-lightgrey?style=flat-square)
![Kernel](https://img.shields.io/badge/kernel-zen-black?style=flat-square)
![Waydroid](https://img.shields.io/badge/waydroid-enabled-3DDC84?style=flat-square&logo=android&logoColor=white)

</div>

---

A minimal NixOS VM image with Waydroid support, running on the Zen kernel with KVM acceleration. Built for QEMU with `virtio-vga-gl` and OpenGL passthrough.

**Specs:** 6 GB RAM · 8 cores · 20 GB disk · Pipewire · zram swap · SSH on `:2222`

---

## Download

```
https://pub-786f3caa6e0c467d81af67b260388ae9.r2.dev/kale-vm.qcow2.zst
```

---

## Run

### Linux

```bash
# Extract
zstd -d kale-vm.qcow2.zst

# Run
qemu-system-x86_64 \
  -enable-kvm \
  -m 6144 \
  -smp 8 \
  -drive file=kale-vm.qcow2,format=qcow2 \
  -device virtio-vga-gl,xres=1920,yres=1080 \
  -display gtk,gl=on \
  -device virtio-serial-pci \
  -cpu host \
  -machine type=q35,accel=kvm \
  -device virtio-balloon \
  -nic user,hostfwd=tcp::2222-:22
```

### Windows

1. Install [7-Zip with Zstandard](https://github.com/mcmilk/7-Zip-zstd/releases) — required to extract `.zst` files
2. Right-click `kale-vm.qcow2.zst` → **7-Zip → Extract here**
3. Run with QEMU for Windows:

```bat
qemu-system-x86_64.exe ^
  -m 6144 -smp 8 ^
  -drive file=kale-vm.qcow2,format=qcow2 ^
  -device virtio-vga-gl,xres=1920,yres=1080 ^
  -display gtk,gl=on ^
  -cpu host -machine type=q35,accel=whpx ^
  -nic user,hostfwd=tcp::2222-:22
```

> Replace `accel=whpx` with `accel=hax` or remove the flag if you hit errors.

---

## Build from source (Nix)

```bash
git clone <this-repo>
cd <this-repo>

# Build the VM image
nix build .#nixosConfigurations.kale-vm.config.system.build.vm

# Run it
./result/bin/run-kale-vm-vm
```

---

## SSH access

```bash
ssh -p 2222 kale-vm@localhost
# password: 123
```

---

## Default credentials

| Field    | Value      |
|----------|------------|
| User     | `kale-vm`  |
| Password | `123`      |
| Sudo     | passwordless |

---

<div align="center">
<sub>built with ❄️ nix · timezone UTC</sub>
</div>
