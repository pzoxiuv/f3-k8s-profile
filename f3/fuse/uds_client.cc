#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

// C includes
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <limits.h>

struct download_info {
    int fd;
    char *path;
    char *servers;
    size_t end_byte;
    int *download_done;
};

int setup_conn(const char *uds_path) {
	struct sockaddr_un addr;
	int fd;

	if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		return -errno;
	}

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;

	strncpy(addr.sun_path, uds_path, sizeof(addr.sun_path)-1);

	if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
		return -errno;
	}

    printf("Connected to %s\n", uds_path);

    return fd;
}

int send_fname_done(int fd, char *fname) {
    int ret;
    char buf[PATH_MAX];
    int len = snprintf(buf, sizeof(buf), "%s\n", fname);
    printf("Sending fname %s\n", buf);
    ret = write(fd, buf, len);
    if (ret < 0) {
        perror("write");
        return -1;
    }
    printf("Wrote %d bytes\n", ret);

    return 0;
}

long int download_file(int fd, char *path, char *servers, size_t end_byte) {
    int ret;

	char buf[100];
	bzero(buf, 100);
	//printf("servers: %s path: %s\n", servers, path);
	int len = snprintf(buf, sizeof(buf), "%s,%lu,%s\n", path, end_byte, servers);
	if (len < 0) {
		return -errno;
	}

	ret = write(fd, buf, len);
	if (ret < 0) {
		return -errno;
	} else if (ret < len) {
		fprintf(stderr, "partial write %d %d\n", ret, len);
	}
	//printf("Wrote >>>\n%s\n<<< (%d bytes)\n", buf, ret);

    bzero(buf, sizeof(buf));
    ret = read(fd, buf, sizeof(buf));
    if (ret < 0)
        return -errno;

    //printf("Got buf %s\n", buf);

    // NAK
    if (buf[0] == 'N') {
        printf("Got NAK, buf: %s\n", buf);
        return -1;
    }

    long int new_pos = strtol(buf+2, NULL, 10);
    //printf("ID client read up to %ld\n", new_pos);

	// TODO: check for ACK response
	//printf("read %s (%d bytes)\n", buf, ret);
    
	return new_pos;
}

void *download_file_thread(void *ptr) {
    struct download_info *dl_info = (struct download_info *)ptr;
    long int ret = download_file(dl_info->fd, dl_info->path, dl_info->servers, dl_info->end_byte);
    printf("Downloaded %ld bytes\n", ret);
    *(dl_info->download_done) = 1;

    free(dl_info->path);
    free(dl_info->servers);
    free(dl_info);

    return NULL;
}

#ifdef CLIENT_ONLY
int main(int argc, char **argv) {
	if (argc < 3) {
		printf("usage: %s path servers", argv[0]);
		return 1;
	}

	//download_file(argv[1], argv[2]);
    int fd = setup_conn(argv[1]);
    download_file(fd, argv[2], argv[3], 1000);

    pthread_t thread;
    int done = 0;
    struct download_info *dl_info = (struct download_info *)malloc(sizeof(struct download_info));
    dl_info->fd = fd;
    dl_info->path = strdup(argv[2]);
    dl_info->servers = strdup(argv[3]);
    dl_info->end_byte = 0;
    dl_info->download_done = &done;
    auto ret = pthread_create(&thread, NULL, download_file_thread, (void *)dl_info);
    if (ret < 0) {
        perror("pthread_create?");
    }

    while (!done) {
        sleep(1);
        printf(".");
        fflush(stdout);
    }

    printf("\nDone\n");
	
	return 0;
}
#endif
