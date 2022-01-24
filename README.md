## Introduction
oom3 allocates all free memory on your system while leaving page cache intact, and continues allocating until the specified amount of memory has been swapped out.

## Why?
* This allows you to swap ahead-of-time, reclaiming memory before it's needed by memory-intensive applications.
* Freed up memory can be immediately used for page cache.
* Many programs don't use 100% of the memory that they have allocated, and swapping these unused pages gives you free memory to work with, at little cost.
* You can set a very low `vm.swappiness` value (or even set it to zero) while still having precisely as much swapped out memory as you want to have.
* You can measure performance & compression ratio of zram (lz4 vs zstd compression) without dropping all of your page cache each time you want to test.

## Building
1. Apply the kernel patch (`0001-swap.mypatch`). After you've patched the kernel, verify that the tunable `/proc/sys/vm/always_reclaim_anon` exists.
2. Compile oom3 using `make`.

## Usage
Run `./oom3.sh [swap target]`

This example swaps out 1 GB of memory (1024 MB): `./oom3.sh 1024`

The swap target parameter is optional and defaults to the `desired_swap_mb` variable.
