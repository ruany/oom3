all:
	gcc -Wall -Wextra -Wconversion -Wsign-conversion -Werror -O3 -s -flto -ffast-math oom3.c -o oom3