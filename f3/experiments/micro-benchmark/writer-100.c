#define _GNU_SOURCE

#include <errno.h>
#include <pthread.h>
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

#define NUM_FILES 100
#define FILE_SIZE (1 * 1024)
#define BUFFER_SIZE (4 * 1024 * 1024)
#define OHM (1024 * 1024 * 100)
#define MS_OR_S(t) (t > 1000 ? t/1000 : t), (t > 1000 ? "s" : "ms")

#define GETTIME(t) do { if (gettimeofday(&t, NULL) < 0) perror("time"); } while(0);

extern unsigned char rand_bin[];
extern int rand_bin_len;

struct thread_arg {
    char *dirname;
    int num;
    char **buf;
    long int size;
};

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

void *write_file(void *p) {
    struct thread_arg *ta = (struct thread_arg *)p;
    struct timeval a, b;
    ssize_t len, total_bytes = 0;
    long int target_size = FILE_SIZE;

    //printf("Hello from thread %d %s\n", ta->num, ta->dirname);

    char fname[100];
    sprintf(fname, "%s/%d", ta->dirname, ta->num);

	int fd = open(fname, O_WRONLY | O_TRUNC | O_CREAT, 0777);
	if (fd == -1) {
		perror("open 1");
		goto out;
	}
    GETTIME(a);

	while (total_bytes < target_size) {
        if ((target_size-total_bytes) < BUFFER_SIZE)
            len = write(fd, *ta->buf, target_size-total_bytes);
        else
            len = write(fd, *ta->buf, BUFFER_SIZE);

		if (len == -1) {
			perror("write");
			goto out2;
		}
		total_bytes += len;
	}
    //syncfs(fd);
    //sync();
    GETTIME(b);

out2:
	close(fd);
out:
    return NULL;
}

int main(int argc, char **argv) {
    char *sc;
	struct timeval b, c;
	ssize_t total_bytes = 0;
    long int target_size;
	long unsigned int open_time, write_time, close_time;
    int num_files;

	if (argc != 4) {
		fprintf(stderr, "usage: %s <file name> <target size> <num files>\n", argv[0]);
		goto out;
	}

    sc = get_sc_name(argv[1]);

	target_size = strtol(argv[2], NULL, 10);
	num_files = strtol(argv[3], NULL, 10);

    printf("Num files %d\n", num_files);

    char *buf = malloc(BUFFER_SIZE);
    int i;
    for (i=0; i<(BUFFER_SIZE/rand_bin_len); i++) {
        //printf("%p %p %d %d %d\n", buf, buf+(i*rand_bin_len)+rand_bin_len, rand_bin_len, BUFFER_SIZE/rand_bin_len, i);
        assert((i*rand_bin_len)+rand_bin_len <= BUFFER_SIZE);
        memcpy(buf+(i*rand_bin_len), rand_bin, rand_bin_len);
    }

    if (mkdir(argv[1], 0777) < 0) {
        if (errno == EEXIST) {
            printf("Directory already exists");
        } else {
            perror("mkdir");
            return 0;
        }
    }

    GETTIME(b);
    pthread_t *threads = malloc(sizeof(pthread_t) * num_files);
    for (i=0; i<num_files; i++) {
        struct thread_arg *ta = malloc(sizeof(struct thread_arg));
        ta->dirname = argv[1];
        ta->num = i;
        ta->buf = &buf;
        ta->size = target_size;
        pthread_create(&threads[i], NULL, write_file, ta);
    }

    for (i=0; i<num_files; i++) {
        pthread_join(threads[i], NULL);
    }

    GETTIME(c);
    printf("\n");

    open_time = 0;
    close_time = 0;
	write_time = ((c.tv_usec - b.tv_usec) / 1000) +
			((c.tv_sec - b.tv_sec) * 1000);

	printf("Write: %lu %s\t", MS_OR_S(write_time));
    printf("%s,write,%lu,%lu,%lu,%lu,%lu,XXX\n", sc,open_time,write_time,close_time,close_time+write_time+open_time,total_bytes);

    get_stat();

out:
	return 0;
}
