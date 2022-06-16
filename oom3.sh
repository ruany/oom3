#!/bin/bash
set -euo pipefail

## Config ##

# Batch size 2M
thp_size_bytes=$[2<<20]

# Swapping will occur before all free memory is allocated.
# Offset from the number of batches which could (theoretically) fit in free memory.
# Reduce to compensate for memory fragmentation.
initial_batch_offset=$[-4*46]

# Always stop at batch I+N
total_batch_offset=180

# Swap target
desired_swap_mb=1024

# Watermark scale factor
default_wsf=$(</proc/sys/vm/watermark_scale_factor)
desired_wsf=220

## Run ##

get_swap_used() {
    swap_total=$(awk '/^SwapTotal/ {print $2*1024}' /proc/meminfo)
    swap_free=$(awk '/^SwapFree/ {print $2*1024}' /proc/meminfo)
    swap_used=$[swap_total-swap_free]
    echo "$swap_used"
}

finalize() {
    echo "oom3: Done."
    kill -9 $(jobs -p) ||:
    echo 0 | sudo tee /proc/sys/vm/always_reclaim_anon >/dev/null
    if [ $default_wsf != $desired_wsf ]; then
        echo "$default_wsf" | sudo tee /proc/sys/vm/watermark_scale_factor >/dev/null
    fi
    date
}

if [ $# -gt 0 ]; then
    desired_swap_mb="$1"
fi

desired_swap_bytes=$[1024*1024*desired_swap_mb]

echo "oom3: Desired swap target: $desired_swap_mb MiB"

if [ $default_wsf != $desired_wsf ]; then
    echo "$desired_wsf" | sudo tee /proc/sys/vm/watermark_scale_factor >/dev/null
fi

if [ $(get_swap_used) -gt $desired_swap_bytes ]; then
    # Do nothing if swap level is already sufficient
    echo "oom3: Swap target already reached."
    exit
fi

trap finalize EXIT

# Calculate the amount of batches necessary to finish as quickly as possible without overflowing
free_bytes=$(awk '/^MemFree/ {print $2*1024}' /proc/meminfo)
initial_batches=$[free_bytes/thp_size_bytes]
initial_batches=$[initial_batches+initial_batch_offset]
total_batches=$[initial_batches+total_batch_offset]

echo 1 | sudo tee /proc/sys/vm/always_reclaim_anon

echo "oom3: Swapping begins."
echo "oom3: Initial batches of $[thp_size_bytes>>20]MB blocks: $initial_batches"
echo "oom3: Stopping at batch $total_batches"
date

./oom3 "$initial_batches" "$total_batches" &

# timeout after 9 seconds
for ((i=0;i<=225;i++)); do
    if [ $(get_swap_used) -gt $desired_swap_bytes ]; then
        echo "oom3: Swap target reached successfully. Exiting."
        exit
    fi
    sleep 0.04
done
echo "oom3: Timeout"