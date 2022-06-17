## Introduction
oom3 allocates all free memory on your system while leaving page cache intact, and continues allocating until the specified amount of memory has been swapped out.

With this, you can set up a system-wide swap quota on anonymous pages which is enforced on demand.

## Why?
* This allows you to swap ahead-of-time, reclaiming memory before it's needed by memory-intensive applications.
* Freed up memory can be immediately used for page cache.
* Many programs don't use 100% of the memory that they have allocated, and swapping these unused pages gives you free memory to work with, at little cost.
* This can be used with zram writeback (backing_dev) to prepare a specific amount of pages to be compressed, marked as idle, and written back to a real swap device over any time period. This gives you fine control over how many pages actually become idle over time as you swap them out manually.
* You can set a very low `vm.swappiness` value (or even set it to zero) while still having precisely as much swapped out memory as you want to have.
* You can measure performance & compression ratio of zram (lz4 vs zstd compression) without dropping all of your page cache each time you want to test.

## Building
1. Apply the kernel patch for your kernel version (`0001-reclaim-sysctl-*.mypatch`).
2. After you've patched the kernel, verify that the tunable `/proc/sys/vm/always_reclaim_anon` exists.
3. Compile oom3 using `make`.

## Usage
Run `./oom3.sh [swap target]`

This example swaps out 1 GB of memory (1024 MB): `./oom3.sh 1024`

The swap target parameter is optional and defaults to the `desired_swap_mb` variable.

The amount of memory reclaimed from any given application can be limited using memory cgroups (`memory.swap.max`).