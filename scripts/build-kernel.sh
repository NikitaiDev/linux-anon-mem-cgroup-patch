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

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# Function to output errors and exit
error_exit() {
    echo "[ERROR] $1" 1>&2
    exit 1
}

# Function to check if file exists
check_file_exists() {
    if [ ! -f "$1" ]; then
        error_exit "File not found: $1. Please ensure it exists."
    fi
}

# Function to check if file is non-empty
is_file_non_empty() {
    if [ -f "$1" ] && [ -s "$1" ]; then
        return 0 # file exists and is not empty
    else
        return 1 # file doesn't exist or is empty
    fi
}

# ==============================================================================
# PRE-FLIGHT CHECKS
# ==============================================================================
echo "[INFO] Running pre-flight checks..."

# Check if Docker is installed and available
if ! command -v docker &> /dev/null; then
    error_exit "Docker is not installed or not in PATH. Please install Docker."
fi

# Check if config file exists
check_file_exists "$KERNEL_CONFIG_SOURCE"

# Check if builder image exists
echo "[INFO] Checking for Docker image $BUILDER_IMAGE..."
if ! sudo docker image inspect "$BUILDER_IMAGE" &> /dev/null; then
    echo "[INFO] Docker image '$BUILDER_IMAGE' not found."
    echo "[INFO] Attempting to build image from Dockerfile..."
    
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
# MAIN LOGIC
# ==============================================================================

# Create temporary directory for build artifacts if it doesn't exist
OUTPUT_DIR="./output"
mkdir -p "$OUTPUT_DIR"

echo "[INFO] Starting container for kernel build version $KERNEL_VERSION..."

# Check if patch exists
if is_file_non_empty "$PATCH_SOURCE"; then
    echo "[INFO] Applying patch: $(basename $PATCH_SOURCE)"
    PATCH_APPLY_CMD="git apply /host/$PATCH_SOURCE"
else
    echo "[INFO] Patch not found or empty. Building vanilla kernel."
    PATCH_APPLY_CMD="echo '[INFO] Skipping patch application'"
fi

# Start container for building
sudo docker run -it --rm \
  --name kernel_builder_container \
  -v "$(pwd):/host:ro" \
  -v "$OUTPUT_DIR:/output" \
  -e KERNEL_VERSION="$KERNEL_VERSION" \
  -e WORKDIR="$WORKDIR" \
  --cpu-shares 1024 \
  --memory "4g" \
  "$BUILDER_IMAGE" /bin/bash -c "
    set -e

    echo '[INFO] Cloning Linux kernel repository (version \$KERNEL_VERSION)...'
    git clone --depth 1 --branch \$KERNEL_VERSION \\
      https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git \$WORKDIR

    cd \$WORKDIR

    # Apply patch (if it exists and is not empty)
    $PATCH_APPLY_CMD

    echo '[INFO] Copying kernel configuration...'
    cp /host/$KERNEL_CONFIG_SOURCE .config

    echo '[INFO] Configuring kernel (olddefconfig)...'
    make olddefconfig

    echo '[INFO] Starting kernel build (bzImage)...'
    make -j\$(nproc) bzImage

    echo '[INFO] Build completed successfully. Copying bzImage to /output...'
    cp arch/x86/boot/bzImage /output/
    chown 1000:1000 /output/bzImage

    echo '[INFO] Done! The built kernel is in the output/ directory'
  "

# Check if container command executed successfully
if [ $? -eq 0 ]; then
    echo "[SUCCESS] Kernel build completed successfully!"
    echo "[INFO] Built kernel (bzImage) is located at: $OUTPUT_DIR/"
else
    error_exit "Kernel build failed with error. Check the output above for details."
fi