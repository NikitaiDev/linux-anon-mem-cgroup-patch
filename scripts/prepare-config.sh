#!/bin/bash
set -e

# Temporary directory for config setup
CONFIG_DIR="./config-temp"
mkdir -p $CONFIG_DIR
cd $CONFIG_DIR

echo "[INFO] Downloading base config for x86_64..."
# Download kernel sources only to get the standard config
git clone --depth 1 --branch v6.8 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux

echo "[INFO] Copying base config..."
cp arch/x86/configs/x86_64_defconfig .config

echo "[INFO] Configuring for QEMU and cgroup support..."
# Now we're in the kernel source directory where we can run make
make olddefconfig

echo "[INFO] Adding required options..."
# Create a file with our additional configuration options
cat > ../my_custom_options << 'EOF'
CONFIG_CGROUPS=y
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=n
CONFIG_MEMCG_KMEM=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CGROUP_PERF=y
CONFIG_CGROUP_BPF=y
CONFIG_VT=y
CONFIG_TTY=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_HW_RANDOM_VIRTIO=y
CONFIG_VIRTIO_PCI=y
CONFIG_VIRTIO_BLK=y
CONFIG_NET_9P=y
CONFIG_NET_9P_VIRTIO=y
CONFIG_9P_FS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_BLK_DEV_INITRD=y
EOF

echo "[INFO] Merging configs..."
# Merge base config with our custom options
scripts/kconfig/merge_config.sh -m .config ../my_custom_options
make olddefconfig

echo "[INFO] Minimizing config for faster build..."
# Disable debugging and drivers not needed for virtual machine
scripts/config --disable DEBUG_INFO
scripts/config --disable DEBUG_KERNEL
scripts/config --disable DRM
scripts/config --disable SOUND
scripts/config --disable WIRELESS
scripts/config --disable NETWORKING

make olddefconfig

echo "[INFO] Copying final config to project root..."
cp .config ../../kernel-config
cd ../..
rm -rf $CONFIG_DIR

echo "[SUCCESS] kernel-config successfully generated and ready for build."