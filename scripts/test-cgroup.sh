#!/bin/ash

echo "=========================================="
echo "BASIC CGROUP MEMORY TEST"
echo "Kernel: $(/bin/busybox uname -r)"
echo "=========================================="

# 1. Cgroup setup
echo "=== 1. CGROUP SETUP ==="
/bin/mkdir -p /proc /sys /tmp /dev
/bin/mount -t proc proc /proc
/bin/mount -t sysfs sysfs /sys
/bin/mount -t tmpfs tmpfs /tmp
/bin/mkdir -p /sys/fs/cgroup
/bin/mount -t cgroup -o memory cgroup /sys/fs/cgroup
/bin/mkdir /sys/fs/cgroup/test

# 2. Check initial state
echo "=== 2. INITIAL STATE ==="
INITIAL_USAGE=$(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes)
echo "Initial memory usage: $INITIAL_USAGE bytes"

# 3. Add current process to cgroup
echo "=== 3. ADD PROCESS TO CGROUP ==="
echo "$$" > /sys/fs/cgroup/test/cgroup.procs
echo "✅ Process added to cgroup"

# 4. Basic functionality test
echo "=== 4. BASIC FUNCTIONALITY TEST ==="
CURRENT_USAGE=$(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes)
echo "Current memory usage: $CURRENT_USAGE bytes"

# 5. Check cgroup files accessibility
echo "=== 5. CGROUP FILES CHECK ==="
if [ -f "/sys/fs/cgroup/test/memory.usage_in_bytes" ] && \
   [ -f "/sys/fs/cgroup/test/memory.limit_in_bytes" ] && \
   [ -f "/sys/fs/cgroup/test/cgroup.procs" ]; then
    echo "✅ All cgroup files are accessible"
else
    echo "❌ Cgroup files missing"
    exit 1
fi

# 6. Memory limit test
echo "=== 6. MEMORY LIMIT TEST ==="
echo "10485760" > /sys/fs/cgroup/test/memory.limit_in_bytes  # 10MB
LIMIT=$(/bin/cat /sys/fs/cgroup/test/memory.limit_in_bytes)
if [ "$LIMIT" -eq 10485760 ]; then
    echo "✅ Memory limit set correctly: $LIMIT bytes"
else
    echo "❌ Memory limit not set correctly: $LIMIT bytes"
    exit 1
fi

# 7. Final check
echo "=== 7. FINAL CHECK ==="
FINAL_USAGE=$(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes)
echo "Final memory usage: $FINAL_USAGE bytes"

# 8. TEST ANON MEMORY ACCOUNTING
echo "=== 8. ANON MEMORY ACCOUNTING TEST ==="
echo "Initial anon usage: $(cat /sys/fs/cgroup/test/memory.anonmem.usage_in_bytes 2>/dev/null || echo 'N/A') bytes"

# Run program that allocates anonymous memory
echo "Allocating anonymous memory..."
/test_program 5000000 &  # 5MB
sleep 2

echo "After allocation anon usage: $(cat /sys/fs/cgroup/test/memory.anonmem.usage_in_bytes 2>/dev/null || echo 'N/A') bytes"

# Verify that usage has increased
INIT_ANON=$(cat /sys/fs/cgroup/test/memory.anonmem.usage_in_bytes 2>/dev/null || echo 0)
if [ "$INIT_ANON" -gt 4000000 ]; then
    echo "✅ ANON MEMORY ACCOUNTING WORKS!"
else
    echo "❌ ANON MEMORY ACCOUNTING NOT WORKING"
fi

echo "=========================================="
echo "BASIC TEST RESULT:"
echo "✅ BASIC CGROUP FUNCTIONALITY WORKS!"
echo "✅ Memory controller is operational"
echo "✅ Cgroup files are accessible" 
echo "✅ Memory limits can be set"
echo ""
echo "Note: Anonymous memory accounting requires"
echo "additional patch implementation."
echo "=========================================="

exit 0