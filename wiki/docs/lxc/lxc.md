# Proxmox LXC Container Setup

This guide explains how to prepare a Proxmox VE LXC container to run DockServer with Docker support, hardware GPU passthrough, and external storage.

---

## 📋 Recommended Proxmox LXC Configuration

When creating a new LXC container in the Proxmox web interface:

### 1. General Settings
- **Hostname**: Choose a container hostname (e.g. `dockserver`).
- **Unprivileged Container**: **UNCHECK** this box. A **privileged container** is required for Docker mount propagation (`mount --make-shared`), nested container isolation, and GPU device nodes.
- **Password**: Set a root password for SSH/console access.

### 2. Template
- Choose the **Ubuntu 24.04**, **Ubuntu 22.04**, or **Debian 12** standard template.

### 3. Root Disk
- Allocate at least **20 GB** (50 GB–500 GB recommended to allow ample room for Docker images, application configs, and transcode scratch space).

### 4. CPU & Memory
- **CPU**: 2 to 6 cores depending on your server CPU and expected transcoding load.
- **Memory & Swap**: 4096 MB to 8192 MB Memory, with matching Swap.

### 5. Network
- **Firewall**: Uncheck to prevent Proxmox host firewall interference with Docker bridge networks.
- **IPv4 / IPv6**: Set to DHCP or configure a static IP and gateway.

### 6. Container Options & Features (Before Booting)
Before starting the container for the first time, navigate to the container's **Options** > **Features** tab and enable:
- [x] **Nesting** (`nesting=1`) — *Required for Docker-in-LXC*
- [x] **keyctl** (`keyctl=1`) — *Required for modern systemd and Docker authentication*
- [x] **FUSE** — *Required if using Rclone or cloud storage mounts*
- [x] **CIFS / NFS** — *Required if mounting network shares directly*

---

## ⚡ Mount Propagation (`mount --make-shared /`)

Docker containers (especially reverse proxies and mounters) require shared mount propagation on the root filesystem.

DockServer handles this automatically! During pre-installation (`dockserver -i`), DockServer detects if it is running inside an LXC environment and automatically installs a systemd unit:
```
/etc/systemd/system/lxc-make-shared.service
```
This unit runs `mount --make-shared /` before `docker.service` on every system boot, completely preventing mount race conditions.

---

## 🎮 GPU Passthrough (Hardware Transcoding for Plex / Jellyfin)

To pass an Intel or AMD GPU from the Proxmox host into the container:

1. On the Proxmox host terminal, inspect the GPU render devices:
   ```bash
   ls -la /dev/dri
   ```
   Typically:
   - `/dev/dri/card0` has major:minor numbers `226:0`
   - `/dev/dri/renderD128` has major:minor numbers `226:128`

2. Edit the container's configuration file on the Proxmox host (replace `100` with your container ID):
   ```bash
   nano /etc/pve/lxc/100.conf
   ```

3. Add the following cgroup2 and autodev rules to the bottom of the file:
   ```conf
   lxc.cgroup2.devices.allow: c 226:0 rwm
   lxc.cgroup2.devices.allow: c 226:128 rwm
   lxc.cgroup2.devices.allow: c 29:0 rwm
   lxc.autodev: 1
   lxc.hook.autodev: sh -c "mkdir -p ${LXC_ROOTFS_MOUNT}/dev/dri && mknod -m 666 ${LXC_ROOTFS_MOUNT}/dev/dri/card0 c 226 0 && mknod -m 666 ${LXC_ROOTFS_MOUNT}/dev/dri/renderD128 c 226 128"
   ```

4. Reboot the container from the Proxmox host:
   ```bash
   pct reboot 100
   ```

5. Verify GPU access inside the container:
   ```bash
   ls -la /dev/dri
   ```
   Both `card0` and `renderD128` will be present. When you run DockServer's GPU setup (`dockserver -i` > GPU Setup), all required VA-API drivers and user groups (`video`, `render`) will be configured automatically.

---

## 🗄️ Mounting External Host Disks or NFS / SMB Shares

If your Proxmox host has storage pools or mounted NFS/SMB shares that you want to expose to DockServer containers:

1. Open the container configuration file on the Proxmox host:
   ```bash
   nano /etc/pve/lxc/100.conf
   ```

2. Add mount point lines (`mp0`, `mp1`, etc.) mapping host paths to container paths:
   ```conf
   mp0: /mnt/pve/Media,mp=/mnt/Media
   mp1: /mnt/pve/Pictures,mp=/mnt/Pictures
   mp2: /mnt/pve/Music,mp=/mnt/Music
   ```

3. Save the file and restart the container. The storage will be directly accessible inside the LXC container under `/mnt/Media`, `/mnt/Pictures`, etc.

---

## 🛡️ AppArmor Handling

In some older Proxmox setups, AppArmor may block nested Docker container operations or password hashing in Authelia. If you encounter permission denials inside the LXC container:

```bash
# Stop and disable AppArmor inside the container
sudo systemctl stop apparmor
sudo systemctl disable apparmor
sudo apt remove --assume-yes --purge apparmor
```

Your LXC container is now fully prepared to run DockServer!
