#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <limits.h>
#include <fcntl.h>
#include <sys/stat.h>

int main(void) {
    pid_t pid = getpid();
    char stat_path[PATH_MAX];

    snprintf(stat_path, sizeof(stat_path), "/proc/%d/stat", pid);

    int fd = open(stat_path, O_RDONLY);
    char *stat_buf = malloc(500);
    read(fd, stat_buf, 500);

    int dummy;
    unsigned long long blocked_io_ticks;
    unsigned long utime, stime;

    sleep(2);

    sscanf(stat_buf, "%d (%s) %c %d %d %d %d %d %u %lu %lu %lu %lu %lu %lu %ld %ld %ld %ld %ld %ld %llu %lu %ld %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %lu %d %d %u %u %llu %lu %ld %lu %lu %lu %lu %lu %lu %lu %d", &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &utime, &stime, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &blocked_io_ticks, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy, &dummy);

    printf("%lu %lu %llu\n", utime, stime, blocked_io_ticks/100);
    printf("%s\n", stat_buf);

    return 0;
}
