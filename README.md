# Linux Anonymous Memory Cgroup Accounting Patch (cgroup v1)

## 📖 Overview

This project adds **accounting and limiting of anonymous memory** (heap, stack, `mmap` pages without a file backend) for **Linux memory cgroup v1**. Per the task requirements, **swap accounting is ignored**. The deliverable is a Git patch that introduces interfaces for reading current usage and configuring the limit of anonymous memory.

---

## 🎯 Technical Task

Implement Linux kernel support for **accounting and limiting anonymous memory** per cgroup (excluding swap). The target deliverable is a git patch providing the functionality.

**Key Requirements**

- Add anonymous memory accounting for cgroup v1.
- Implement `anonmem.usage_in_bytes` and `anonmem.limit_in_bytes` interfaces.
- Ignore swap memory accounting.
- Preserve kernel stability and performance.

---

## 🏗️ Architecture

### New/Modified Components

- In `struct mem_cgroup`: `struct page_counter anonmem`.
- Cgroup interfaces:
  - `anonmem.usage_in_bytes` — read current usage.
  - `anonmem.limit_in_bytes` — read/write limit.
- Page charging mechanism: `mem_cgroup_charge_anon_folio()`.
- Integration points:
  - Page fault path: `do_anonymous_page()`.
  - Allocation paths for regular and huge pages.
- Synchronization:
  - `spinlock_t anon_lock` and atomic counter updates.

### Modified Kernel Files

- `mm/memcontrol.c` — core logic.
- `include/linux/memcontrol.h` — structures and declarations.
- `mm/memory.c` — page-fault integration.
- `mm/hugetlb.c` — huge page support.

---

## 🚀 Quick Start

### Prerequisites

```bash
sudo apt-get update
sudo apt-get install -y git docker.io qemu-system-x86 build-essential
```

### 1) Clone and Setup

```bash
git clone https://github.com/yourusername/linux-anon-mem-cgroup-patch.git
cd linux-anon-mem-cgroup-patch
```

### 2) Build the Kernel with the Patch

```bash
# Build the kernel with anonymous memory accounting enabled
sudo ./scripts/build-kernel.sh
```

### 3) Test in QEMU

```bash
# Launch the test environment
sudo ./scripts/run-qemu.sh
```

### 4) Automated Tests

```bash
# Inside the QEMU VM, tests start automatically.
# Manual check:
cat /sys/fs/cgroup/test/anonmem.usage_in_bytes
echo 10000000 > /sys/fs/cgroup/test/anonmem.limit_in_bytes
```

**Verification commands:**
```bash
# Check current usage
cat /sys/fs/cgroup/test/anonmem.usage_in_bytes

# Set limit (10 MiB)
echo 10485760 > /sys/fs/cgroup/test/anonmem.limit_in_bytes

# Confirm applied limit
cat /sys/fs/cgroup/test/anonmem.limit_in_bytes
```

---

## 📁 Project Structure

```text
linux-anon-mem-cgroup-patch/
├── linux-kernel/                 # Kernel sources with the patch applied
├── scripts/
│   ├── build-kernel.sh           # Kernel build script
│   ├── run-qemu.sh               # QEMU runner
│   ├── prepare-config.sh         # .config generation
│   └── test-cgroup.sh            # Automated cgroup tests
├── resources/
│   ├── test_program              # Test binary
│   └── busybox                   # Static busybox
├── output/                       # Built kernel artifacts
├── kernel-config                 # Kernel configuration
├── my_cgroup_patch.patch         # Main implementation patch
├── Dockerfile                    # Build environment
└── README.md
```

---

## 🔧 Technical Details

### Memory Charging

- Added **`mem_cgroup_charge_anon_folio()`** to charge anonymous folios/pages to `mem_cgroup->anonmem`.
- Integrated into **`do_anonymous_page()`** (page-fault paths) to account newly materialized anonymous pages.
- Supports both **regular** and **huge** pages (hugetlb).

### Cgroup Interfaces

- **`anonmem.usage_in_bytes`**
  - Read-only: current amount of accounted anonymous memory in the cgroup.
- **`anonmem.limit_in_bytes`**
  - Read/Write: hard limit for anonymous memory in the cgroup.
  - Input validation and proper error codes on failures.

### Synchronization

- Uses **`spinlock_t anon_lock`** to avoid races on concurrent access.
- Counter updates are atomic with attention to low overhead on hot paths.

### Deliberately Excluded

- **Swap accounting is ignored**: only resident anonymous memory (heap/stack/anonymous `mmap`) is accounted.

### Limit Enforcement Behavior

- When attempting to charge beyond the limit:
  - Allocation is denied for the offending task.
  - Standard cgroup-scoped OOM handling applies in low-memory scenarios.

---

## 📝 Usage Examples

### 1) Basic Accounting Check

```bash
# Create a cgroup
mkdir /sys/fs/cgroup/test

# Read initial usage
cat /sys/fs/cgroup/test/anonmem.usage_in_bytes

# Run a memory-hungry workload
./memory_program &

# Monitor usage
watch -n 1 'cat /sys/fs/cgroup/test/anonmem.usage_in_bytes'
```

### 2) Limit Enforcement

```bash
# Set a 10 MiB limit
echo 10485760 > /sys/fs/cgroup/test/anonmem.limit_in_bytes

# Attach a process to the cgroup
echo $$ > /sys/fs/cgroup/test/cgroup.procs

# Try to exceed the limit — should fail/trigger cgroup-local OOM
./allocate_large_memory
```

---

## ✅ Key Features

- Anonymous memory accounting: **heap, stack, anonymous mmap**.
- Hard limit enforcement with cgroup-local OOM protection.
- **cgroup v1** compatible.
- Designed for **low overhead** on hot paths.

---

## 🧪 Stability & Performance Notes

- The accounting hooks live in hot paths (page fault/allocation); locking and counter updates are minimized.
- Input validation safeguards misconfiguration of limits.
- QEMU-based tests cover basic accounting and enforcement scenarios.

---

## 🔗 Handy Commands (Cheat Sheet)

```bash
# Inspect usage
cat /sys/fs/cgroup/test/anonmem.usage_in_bytes

# Set a limit (bytes)
echo 268435456 > /sys/fs/cgroup/test/anonmem.limit_in_bytes  # 256 MiB

# Attach a PID to the cgroup
echo <PID> > /sys/fs/cgroup/test/cgroup.procs

# Monitor
watch -n 1 'cat /sys/fs/cgroup/test/anonmem.usage_in_bytes'
```

---

## 📦 Repository

```
https://github.com/yourusername/linux-anon-mem-cgroup-patch
```