#!/bin/bash
set -euo pipefail

## Config ##

# Batch size
thp_size_bytes=$[1024*1024*2]

# Swapping will occur before all free memory is allocated.
# Offset from the number of batches which could (theoretically) fit in free memory.
# Reduce to compensate for memory watermark % and memory fragmentation.
initial_batch_offset=-160
#initial_batch_offset=-140

# Always stop at batch I+N
total_batch_offset=340

# Swap target
desired_swap_mb=960

default_wsf=$(</proc/sys/vm/watermark_scale_factor)
desired_wsf=200

## Run ##

if [ $# -gt 0 ]; then
    desired_swap_mb="$1"
fi

desired_swap_bytes=$[1024*1024*desired_swap_mb]

echo "oom3: Desired swap target: $desired_swap_mb MiB"

# Firstly, sync to get rid of dirty memory which could mess with our calculations
sync

if [ $default_wsf != $desired_wsf ]; then
    echo "$desired_wsf"|sudo tee /proc/sys/vm/watermark_scale_factor >/dev/null
fi

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
        echo "$default_wsf"|sudo tee /proc/sys/vm/watermark_scale_factor >/dev/null
    fi
    date
}

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
echo "oom3: Initial batches of 2MB blocks: $initial_batches"
echo "oom3: Stopping at batch $total_batches"
date

./oom3 "$initial_batches" "$total_batches" &

# timeout after 8 seconds
for ((i=0;i<=160;i++)); do
    if [ $(get_swap_used) -gt $desired_swap_bytes ]; then
        echo "oom3: Swap target reached successfully. Exiting."
        exit
    fi
    sleep 0.05
done
echo "oom3: Timeout"