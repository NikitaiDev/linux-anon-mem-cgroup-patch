#!/bin/bash
set -e

echo "[INFO] Starting QEMU with built kernel..."

# Check if kernel exists
if [ ! -f "./output/bzImage" ]; then
    echo "[ERROR] Kernel not built. Please run ./scripts/build-kernel.sh first"
    exit 1
fi

# Download static busybox if not exists
if [ ! -f "./resources/busybox" ]; then
    echo "[INFO] Downloading busybox..."
    mkdir -p resources
    wget -O ./resources/busybox https://www.busybox.net/downloads/binaries/1.35.0-x86_64-linux-musl/busybox
    chmod +x ./resources/busybox
fi

# Compile test program using kernel-builder container
sudo docker run --rm -v $(pwd):/host kernel-builder /bin/bash -c "
    cd /host
    ls -a resources
    gcc -static -O2 -o resources/test_program resources/test_program.c
    chmod +x resources/test_program
"

# Create minimal initramfs for debugging
echo "[INFO] Creating initramfs for debugging..."
mkdir -p ./initramfs

# Copy necessary files to initramfs
cp ./resources/busybox ./initramfs/
cp ./resources/test_program ./initramfs/
cp ./scripts/test-cgroup.sh ./initramfs/test-cgroup.sh
cd ./initramfs
chmod +x busybox
chmod +x test_program
chmod +x test-cgroup.sh

# Create directory structure and symlinks
mkdir -p bin sbin usr/bin usr/sbin
ln -s /busybox bin/sh
ln -s /busybox bin/ash
ln -s /busybox bin/mount
ln -s /busybox bin/echo
ln -s /busybox bin/cat
ln -s /busybox bin/ls
ln -s /busybox bin/mkdir
ln -s /busybox bin/uname
ln -s /busybox bin/sleep
cd ..

# Create init script for debugging
cat > ./initramfs/init << 'EOF'
#!/bin/ash

echo "=========================================="
echo "Linux kernel debug shell"
echo "Kernel: $(uname -r)"
echo "=========================================="

# Mount VFS
/bin/mkdir -p /proc
/bin/mkdir -p /sys  
/bin/mkdir -p /tmp
/bin/mkdir -p /dev
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t tmpfs tmpfs /tmp
/bin/mkdir -p /sys/fs/cgroup
/bin/mount -t cgroup cgroup /sys/fs/cgroup -o memory
echo "Starting comprehensive memory test..."


/bin/mkdir /sys/fs/cgroup/test

echo "Basic mounts done. Starting shell..."

if /test-cgroup.sh; then
    echo "✅ ALL TESTS PASSED!"
else
    echo "❌ TESTS FAILED!"
fi
exec /bin/ash
EOF

chmod +x ./initramfs/init

# Create initramfs archive
cd ./initramfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../output/initramfs.cpio.gz
cd ..
rm -rf ./initramfs

# Start QEMU virtual machine
echo "[INFO] Starting QEMU..."
echo "[INFO] To exit QEMU: Ctrl+A, then X"

sudo qemu-system-x86_64 \
    -kernel ./output/bzImage \
    -initrd ./output/initramfs.cpio.gz \
    -nographic \
    -append "console=ttyS0 earlyprintk=serial rdinit=/init" \
    -m 512M \
    --enable-kvm \
    -cpu host \
    -smp 1 \
    -no-reboot