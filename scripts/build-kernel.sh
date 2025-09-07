#!/bin/bash
set -e # Exit immediately on any error

# ==============================================================================
# Configuration
# ==============================================================================
KERNEL_VERSION="v6.8"               # Kernel version to build
WORKDIR="/linux-kernel"             # Working directory inside the container  
BUILDER_IMAGE="kernel-builder"      # Name of the builder image with build tools
PATCH_SOURCE="my_cgroup_patch.patch" # Local path to your patch
KERNEL_CONFIG_SOURCE="kernel-config" # Local path to kernel configuration (.config)
OUTPUT_DIR="./output"               # Output directory for built kernel

# ==============================================================================
# FUNCTIONS  
# ==============================================================================

error_exit() {
    echo "[ERROR] $1" 1>&2
    exit 1
}

check_file_exists() {
    if [ ! -f "$1" ]; then
        error_exit "File not found: $1. Please ensure it exists."
    fi
}

# ==============================================================================
# PRE-FLIGHT CHECKS
# ==============================================================================
echo "[INFO] Running pre-flight checks..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    error_exit "Docker is not installed or not in PATH. Please install Docker."
fi

# Check if config exists
check_file_exists "$KERNEL_CONFIG_SOURCE"

# Check if kernel source directory exists
if [ ! -d "linux-kernel" ]; then
    echo "[INFO] Kernel source directory not found. Cloning kernel..."
    git clone --depth 1 --branch $KERNEL_VERSION \
        https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \
        linux-kernel
fi

# Check if builder image exists
echo "[INFO] Checking for Docker image $BUILDER_IMAGE..."
if ! sudo docker image inspect "$BUILDER_IMAGE" &> /dev/null; then
    echo "[INFO] Docker image '$BUILDER_IMAGE' not found."
    echo "[INFO] Building image from Dockerfile..."
    
    if [ -f "Dockerfile" ]; then
        sudo docker build -t "$BUILDER_IMAGE" . 
        if [ $? -ne 0 ]; then
            error_exit "Failed to build Docker image. Please check the Dockerfile."
        fi
        echo "[SUCCESS] Image built successfully!"
    else
        error_exit "Dockerfile not found in project root. Please create one."
    fi
fi

echo "[INFO] All pre-flight checks passed successfully."

# ==============================================================================
# MAIN LOGIC - DEVELOPMENT MODE
# ==============================================================================

mkdir -p "$OUTPUT_DIR"

echo "[INFO] Starting development build process..."
echo "[INFO] Kernel sources are available in: ./linux-kernel/"
echo "[INFO] You can edit files there and rebuild using this script"

# Start container with MOUNTED source directory for development
sudo docker run -it --rm \
  --name kernel_dev_container \
  -v "$(pwd)/linux-kernel:$WORKDIR" \
  -v "$(pwd):/host" \
  -v "$(pwd)/$OUTPUT_DIR:/output" \
  --cpu-shares 1024 \
  --memory "8g" \
  "$BUILDER_IMAGE" /bin/bash -c "
    set -e
    
    echo '[INFO] Changing to kernel directory: $WORKDIR'
    cd '$WORKDIR'

    # Apply patch if it exists
    if [ -f '/host/$PATCH_SOURCE' ] && [ -s '/host/$PATCH_SOURCE' ]; then
        echo '[INFO] Applying patch: $PATCH_SOURCE'
        git apply '/host/$PATCH_SOURCE'
    else
        echo '[INFO] No patch to apply. Building vanilla kernel.'
    fi

    echo '[INFO] Copying kernel configuration...'
    cp '/host/$KERNEL_CONFIG_SOURCE' .config

    echo '[INFO] Configuring kernel (olddefconfig)...'
    make olddefconfig

    echo '[INFO] Starting kernel build (bzImage)...'
    echo '[INFO] This may take several minutes...'
    make -j\$(nproc) bzImage

    echo '[INFO] Build completed successfully. Copying bzImage...'
    cp arch/x86/boot/bzImage /output/
    chown 1000:1000 /output/bzImage

    echo '[SUCCESS] Kernel built successfully!'
    echo '[INFO] Output: /output/bzImage'
    echo '[INFO] You can edit source files in /host/linux-kernel/ and run this script again'
  "

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Kernel build completed successfully!"
    echo "[INFO] Built kernel: $OUTPUT_DIR/bzImage"
    echo "[INFO] Source files: ./linux-kernel/"
    echo "[INFO] To test: sudo ./scripts/run-qemu.sh"
else
    error_exit "Kernel build failed. Check the output above for details."
fi