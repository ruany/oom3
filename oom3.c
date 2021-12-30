#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <inttypes.h>
#include <fcntl.h>
#include <limits.h>
#include <string.h>
#include <sys/mman.h>

#define likely(x)       __builtin_expect(!!(x), 1)
#define unlikely(x)     __builtin_expect(!!(x), 0)

const unsigned int size = (1024*1024*2); // 2MB (THP aligned)
const unsigned int batch = 25; // Amount of allocations to print and delay between
const unsigned int delay_factor = 50; // Additional delay * ((completed batches - initial batches)/batch size) in ms. Increase if too much memory gets swapped out. Decrease if not quick enough.

/**
* This marks our process as the highest possible candidate for the OOM killer
* The C equivalent of: echo 1000 >/proc/$$/oom_score_adj
*/
void oom_advise() {
    int pid = getpid();
    char path[32];
    sprintf(path, "/proc/%d/oom_score_adj", pid);
    FILE* fd = fopen(path, "w");
    if (unlikely(!fd)) {
        perror("fopen"); exit(EXIT_FAILURE);
    }
    fputs("1000", fd);
    fclose(fd);
}

int main(int argc, char** argv) {
    oom_advise();

    long unsigned int init_batches = 2000;
    long unsigned int stop_at_batch = 3000;
    if (argc >= 2) init_batches = strtoul(argv[1],NULL,0);
    if (argc >= 3) stop_at_batch = strtoul(argv[2],NULL,0);

    for(unsigned int i=0;likely(i < stop_at_batch);i++) {
        void* addr = mmap(NULL, size, PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, 0, 0);
        if (unlikely(!addr)) {
            perror("mmap() failed"); return EXIT_FAILURE;
        }
        if (unlikely(madvise(addr, size, MADV_SEQUENTIAL|MADV_HUGEPAGE) != 0)) { // Enable THP. I assume that memset is sequential.
            perror("madvise() failed"); return EXIT_FAILURE;
        }
        memset(addr, 0, size);
        if ((i%batch) == 0) {
            if (i >= init_batches) {
                printf("Page %d allocated and zeroed\n", i);
                unsigned int delay = (unsigned int)(1000*(delay_factor*((i-init_batches)/batch)));
                usleep(delay);
            }
        }
    }
    return EXIT_SUCCESS;
}
