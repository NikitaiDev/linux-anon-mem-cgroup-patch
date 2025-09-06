#!/bin/ash

echo "=========================================="
echo "COMPREHENSIVE CGROUP MEMORY TEST"
echo "Kernel: $(uname -r)"
echo "=========================================="

# Function to display test results
print_test_result() {
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
    else
        echo "❌ $2"
        FAILED=1
    fi
}

# Function to check memory usage
check_memory_usage() {
    local expected_min=$1
    local expected_max=$2
    local description=$3
    
    USAGE=$(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes)
    echo "   Current usage: $USAGE bytes"
    
    if [ "$USAGE" -ge "$expected_min" ] && [ "$USAGE" -le "$expected_max" ]; then
        echo "   ✅ Usage within expected range: ${expected_min}-${expected_max} bytes"
        return 0
    else
        echo "   ❌ Usage outside expected range: ${expected_min}-${expected_max} bytes"
        return 1
    fi
}

FAILED=0

# 1. Check initial state
echo "=== 1. INITIAL STATE ==="
INITIAL_USAGE=$(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes)
echo "Initial memory usage: $INITIAL_USAGE bytes"

# 2. Add current process to cgroup
echo "=== 2. ADD PROCESS TO CGROUP ==="
echo "$$" > /sys/fs/cgroup/test/cgroup.procs
print_test_result $? "Process added to cgroup"

# 3. Test 1: Small memory allocation (1MB)
echo "=== 3. TEST 1: 1MB ALLOCATION ==="
echo "Pre-allocation usage: $(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes) bytes"
/test_program 1048576 &  # 1MB
PID1=$!
/bin/sleep 2
check_memory_usage 1000000 1200000 "1MB allocation test"
print_test_result $? "Test 1: 1MB memory allocation"
/bin/sleep 1
kill $PID1 2>/dev/null

# 4. Test 2: Medium memory allocation (5MB)
echo "=== 4. TEST 2: 5MB ALLOCATION ==="
echo "Pre-allocation usage: $(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes) bytes"
/test_program 5242880 &  # 5MB
PID2=$!
/bin/sleep 2
check_memory_usage 5000000 5500000 "5MB allocation test"
print_test_result $? "Test 2: 5MB memory allocation"
/bin/sleep 1
kill $PID2 2>/dev/null

# 5. Test 3: Memory release check
echo "=== 5. TEST 3: MEMORY RELEASE ==="
/bin/sleep 3  # Wait for memory release
POST_RELEASE_USAGE=$(/bin/cat /sys/fs/cgroup/test/memory.usage_in_bytes)
echo "Post-release usage: $POST_RELEASE_USAGE bytes"

if [ "$POST_RELEASE_USAGE" -lt 1000000 ]; then
    echo "✅ Memory properly released after program exit"
else
    echo "❌ Memory not properly released"
    FAILED=1
fi

# 6. Test 4: Memory limit enforcement
echo "=== 6. TEST 4: MEMORY LIMIT ==="
echo "Setting memory limit to 3MB..."
echo "3145728" > /sys/fs/cgroup/test/memory.limit_in_bytes  # 3MB

# Try to allocate more than the limit
echo "Attempting to allocate 5MB (over limit)..."
/test_program 5242880 && {
    echo "❌ Program should have failed with OOM"
    FAILED=1
} || {
    echo "✅ Program correctly failed due to memory limit"
}

# 7. Final results
echo "=========================================="
echo "FINAL TEST RESULT:"
if [ $FAILED -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! Memory accounting works correctly."
    exit 0
else
    echo "💥 SOME TESTS FAILED! Memory accounting has issues."
    exit 1
fi