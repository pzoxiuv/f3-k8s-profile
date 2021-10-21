#define _GNU_SOURCE

#include <assert.h>
#include <limits.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/time.h>
#include <time.h>

#define BUFFER_SIZE (4 * 1024 * 1024)
#define OHM (1024 * 1024 * 100)
#define MS_OR_S(t) (t > 1000 ? t/1000 : t), (t > 1000 ? "s" : "ms")

#define GETTIME(t) do { if (gettimeofday(&t, NULL) < 0) perror("time"); } while(0);

extern unsigned char rand_bin[];
extern int rand_bin_len;

void get_stat(void) {
    pid_t pid = getpid();
    char stat_path[PATH_MAX];

    snprintf(stat_path, sizeof(stat_path), "/proc/%d/stat", pid);

    int fd = open(stat_path, O_RDONLY);
    char *stat_buf = malloc(500);
    read(fd, stat_buf, 500);

    unsigned long long blocked_io_ticks = 0;
    unsigned long utime = 0, stime = 0;

    long clk_tck = sysconf(_SC_CLK_TCK);

    sscanf(stat_buf, "%*d %*s %*c %*d %*d %*d %*d %*d %*u %*u %*u %*u %*u %lu %lu %*d %*d %*d %*d %*d %*d %*u %*u %*d %*u %*u %*u %*u %*u %*u %*u %*u %*u %*u %*u %*u %*u %*d %*d %*u %*u %llu %*u %*d %*u %*u %*u %*u %*u %*u %*u %*d", &utime, &stime, &blocked_io_ticks);

    float utime_s = (float)utime/clk_tck;
    float stime_s = (float)stime/clk_tck;
    float blocked_io_s = (float)blocked_io_ticks/100;

    printf("writer,%.2f,%.2f,%.2f\n", utime_s, stime_s, blocked_io_s);
    //printf("%s\n", stat_buf);
}

int find_slash(char *s, int start) {
    int i = start;
    for (; i<strlen(s); i++) {
        if (s[i] == '/')
            return i;
    }

    return -1;
}

char *get_sc_name(char *s) {
    char *sc = malloc(strlen(s));
    strcpy(sc, s);
    int start = find_slash(s, 0) + 1;
    start = find_slash(s, start) + 1;
    int end = find_slash(s, start);
    sc[end] = '\0';
    return sc+start;
}

int main(int argc, char **argv) {
	int fd;
    char *sc;
	struct timeval a, b, c, d;
	ssize_t len, total_bytes = 0;
	long unsigned int open_time, write_time, close_time;
	long int target_size, checkpoint;

	if (argc != 3) {
		fprintf(stderr, "usage: %s <file name> <target size>\n", argv[0]);
		goto out;
	}

	fprintf(stdout, "GGG start time %lu\n", (unsigned long)time(NULL));

    sc = get_sc_name(argv[1]);

	target_size = strtol(argv[2], NULL, 10);

    char *buf = malloc(BUFFER_SIZE);
    int i;
    for (i=0; i<(BUFFER_SIZE/rand_bin_len); i++) {
        //printf("%p %p %d %d %d\n", buf, buf+(i*rand_bin_len)+rand_bin_len, rand_bin_len, BUFFER_SIZE/rand_bin_len, i);
        assert((i*rand_bin_len)+rand_bin_len <= BUFFER_SIZE);
        memcpy(buf+(i*rand_bin_len), rand_bin, rand_bin_len);
    }

    GETTIME(a);
	fd = open(argv[1], O_WRONLY | O_TRUNC | O_CREAT, 0777);
	//fd = open(argv[1], O_WRONLY | O_TRUNC | O_CREAT | O_DIRECT, 0777);
	if (fd == -1) {
		perror("open 1");
		goto out;
	}
    GETTIME(b);

	checkpoint = 0;

	while (total_bytes < target_size) {
		//len = write(fd, rand_bin, 512);
		//len = write(fd, rand_bin, rand_bin_len);
        if ((target_size-total_bytes) < BUFFER_SIZE)
            len = write(fd, buf, (target_size-total_bytes));
        else
            len = write(fd, buf, BUFFER_SIZE);
		if (len == -1) {
			perror("write");
			goto out2;
		}
		total_bytes += len;

		if ((total_bytes - checkpoint) > OHM) {
			//printf(".");
			checkpoint = total_bytes;
		}
	}
    //syncfs(fd);
    //sync();
    GETTIME(c);
    printf("\n");

out2:
	close(fd);
    GETTIME(d);

	open_time = ((b.tv_usec - a.tv_usec) / 1000) +
			((b.tv_sec - a.tv_sec) * 1000);
	write_time = ((c.tv_usec - b.tv_usec) / 1000) +
			((c.tv_sec - b.tv_sec) * 1000);
	close_time = ((d.tv_usec - c.tv_usec) / 1000) +
			((d.tv_sec - c.tv_sec) * 1000);

	printf("Open: %lu %s\t", MS_OR_S(open_time));
	printf("Write: %lu %s\t", MS_OR_S(write_time));
	printf("Close: %lu %s\t", MS_OR_S(close_time));
	printf("Total: %lu %s\t", MS_OR_S((close_time + write_time + open_time)));
    printf("Bytes: %ld\n", total_bytes);
    printf("%s,write,%lu,%lu,%lu,%lu,%lu,XXX\n", sc,open_time,write_time,close_time,close_time+write_time+open_time,total_bytes);

    get_stat();

	fprintf(stdout, "RRR end time %lu\n", (unsigned long)time(NULL));

out:
	return 0;
}
