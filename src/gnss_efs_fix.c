#define _GNU_SOURCE

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define DIAG_SUBSYS_CMD 75
#define DIAG_SUBSYS_FS 19
#define EFS_HELLO 0
#define EFS_OPEN 2
#define EFS_CLOSE 3
#define EFS_READ 4
#define EFS_WRITE 5
#define DIAG_PORT 43555
#define MAX_FRAME 8192

static const char *paths[] = {
    "/nv/item_files/gps/cgps/me/gnss_config",
    "/nv/item_files/gps/cgps/me/gnss_config_Subscription01",
};

static int sock_fd = -1;
static pid_t router_pid = -1;

static void put_u16(uint8_t *p, uint16_t value) {
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
}

static void put_u32(uint8_t *p, uint32_t value) {
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
}

static uint16_t get_u16(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t get_u32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint16_t crc_x25(const uint8_t *data, size_t len) {
    uint16_t crc = 0xffff;
    for (size_t i = 0; i < len; ++i) {
        crc ^= data[i];
        for (int bit = 0; bit < 8; ++bit)
            crc = (crc & 1) ? (uint16_t)((crc >> 1) ^ 0x8408) : (uint16_t)(crc >> 1);
    }
    return (uint16_t)(crc ^ 0xffff);
}

static int write_all(int fd, const void *buf, size_t len) {
    const uint8_t *p = (const uint8_t *)buf;
    while (len) {
        ssize_t n = write(fd, p, len);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        p += n;
        len -= (size_t)n;
    }
    return 0;
}

static int send_frame(const uint8_t *payload, size_t len) {
    uint8_t raw[MAX_FRAME], frame[MAX_FRAME * 2];
    if (len + 2 > sizeof(raw)) return -1;
    memcpy(raw, payload, len);
    put_u16(raw + len, crc_x25(payload, len));
    len += 2;

    size_t out = 0;
    for (size_t i = 0; i < len; ++i) {
        if (raw[i] == 0x7d || raw[i] == 0x7e) {
            frame[out++] = 0x7d;
            frame[out++] = raw[i] ^ 0x20;
        } else {
            frame[out++] = raw[i];
        }
    }
    frame[out++] = 0x7e;
    return write_all(sock_fd, frame, out);
}

static int read_frame(uint8_t *payload, size_t cap, size_t *payload_len) {
    uint8_t encoded[MAX_FRAME * 2];
    size_t used = 0;
    for (;;) {
        uint8_t byte;
        ssize_t n = read(sock_fd, &byte, 1);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        if (byte == 0x7e) break;
        if (used >= sizeof(encoded)) return -1;
        encoded[used++] = byte;
    }

    size_t out = 0;
    for (size_t i = 0; i < used; ++i) {
        uint8_t byte = encoded[i];
        if (byte == 0x7d) {
            if (++i >= used) return -1;
            byte = encoded[i] ^ 0x20;
        }
        if (out >= cap) return -1;
        payload[out++] = byte;
    }
    if (out < 3) return -1;
    uint16_t got = get_u16(payload + out - 2);
    if (got != crc_x25(payload, out - 2)) return -2;
    *payload_len = out - 2;
    return 0;
}

static int transact(uint16_t command, const uint8_t *body, size_t body_len,
                    uint8_t *response, size_t response_cap, size_t *response_len) {
    uint8_t request[MAX_FRAME];
    if (body_len + 4 > sizeof(request)) return -1;
    request[0] = DIAG_SUBSYS_CMD;
    request[1] = DIAG_SUBSYS_FS;
    put_u16(request + 2, command);
    if (body_len) memcpy(request + 4, body, body_len);
    if (send_frame(request, body_len + 4)) return -1;

    for (int attempts = 0; attempts < 100; ++attempts) {
        size_t len = 0;
        int rc = read_frame(response, response_cap, &len);
        if (rc == -2) continue;
        if (rc) return -1;
        if (len >= 4 && response[0] == DIAG_SUBSYS_CMD &&
            response[1] == DIAG_SUBSYS_FS && get_u16(response + 2) == command) {
            *response_len = len;
            return 0;
        }
    }
    return -1;
}

static int efs_hello(void) {
    uint8_t body[40], response[MAX_FRAME];
    size_t response_len;
    for (int i = 0; i < 6; ++i) put_u32(body + i * 4, 0x100000);
    put_u32(body + 24, 1);
    put_u32(body + 28, 1);
    put_u32(body + 32, 1);
    put_u32(body + 36, 0xffffffff);
    return transact(EFS_HELLO, body, sizeof(body), response, sizeof(response), &response_len);
}

static int efs_open(const char *path, uint32_t flags, int32_t *remote_fd) {
    uint8_t body[MAX_FRAME], response[MAX_FRAME];
    size_t path_len = strlen(path) + 1, response_len;
    if (path_len + 8 > sizeof(body)) return -1;
    put_u32(body, flags);
    put_u32(body + 4, 0);
    memcpy(body + 8, path, path_len);
    if (transact(EFS_OPEN, body, path_len + 8, response, sizeof(response), &response_len)) return -1;
    if (response_len < 12 || get_u32(response + 8) != 0) return -1;
    *remote_fd = (int32_t)get_u32(response + 4);
    return 0;
}

static int efs_close(int32_t remote_fd) {
    uint8_t body[4], response[MAX_FRAME];
    size_t response_len;
    put_u32(body, (uint32_t)remote_fd);
    if (transact(EFS_CLOSE, body, sizeof(body), response, sizeof(response), &response_len)) return -1;
    return (response_len >= 8 && get_u32(response + 4) == 0) ? 0 : -1;
}

static int efs_read4(const char *path, uint8_t value[4]) {
    int32_t fd;
    uint8_t body[12], response[MAX_FRAME];
    size_t response_len;
    if (efs_open(path, 0, &fd)) return -1;
    put_u32(body, (uint32_t)fd);
    put_u32(body + 4, 4);
    put_u32(body + 8, 0);
    int rc = transact(EFS_READ, body, sizeof(body), response, sizeof(response), &response_len);
    if (!rc) {
        if (response_len != 24 || get_u32(response + 12) != 4 || get_u32(response + 16) != 0)
            rc = -1;
        else
            memcpy(value, response + 20, 4);
    }
    if (efs_close(fd)) rc = -1;
    return rc;
}

static int efs_write4(const char *path, const uint8_t value[4]) {
    int32_t fd;
    uint8_t body[12], response[MAX_FRAME];
    size_t response_len;
    if (efs_open(path, 1, &fd)) return -1;
    put_u32(body, (uint32_t)fd);
    put_u32(body + 4, 0);
    memcpy(body + 8, value, 4);
    int rc = transact(EFS_WRITE, body, sizeof(body), response, sizeof(response), &response_len);
    if (!rc && (response_len < 20 || get_u32(response + 12) != 4 || get_u32(response + 16) != 0)) rc = -1;
    if (efs_close(fd)) rc = -1;
    return rc;
}

static void cleanup(void) {
    if (sock_fd >= 0) close(sock_fd);
    sock_fd = -1;
    if (router_pid > 0) {
        int reaped = 0;
        kill(router_pid, SIGTERM);
        for (int i = 0; i < 20; ++i) {
            if (waitpid(router_pid, NULL, WNOHANG) == router_pid) {
                reaped = 1;
                break;
            }
            usleep(50000);
        }
        if (!reaped) {
            kill(router_pid, SIGKILL);
            waitpid(router_pid, NULL, 0);
        }
    }
    router_pid = -1;
}

static int connect_diag_socket(void) {
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener < 0) return -1;
    int yes = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in address = {0};
    address.sin_family = AF_INET;
    address.sin_port = htons(DIAG_PORT);
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(listener, (struct sockaddr *)&address, sizeof(address)) || listen(listener, 1)) {
        close(listener);
        return -1;
    }

    router_pid = fork();
    if (router_pid == 0) {
        execl("/vendor/bin/diag_socket_log", "diag_socket_log", "-a", "127.0.0.1",
              "-p", "43555", "-r", "3", (char *)NULL);
        _exit(127);
    }
    if (router_pid < 0) {
        close(listener);
        return -1;
    }

    fd_set set;
    FD_ZERO(&set);
    FD_SET(listener, &set);
    struct timeval timeout = {.tv_sec = 8, .tv_usec = 0};
    int ready = select(listener + 1, &set, NULL, NULL, &timeout);
    if (ready <= 0) {
        close(listener);
        cleanup();
        return -1;
    }
    sock_fd = accept(listener, NULL, NULL);
    close(listener);
    if (sock_fd < 0) {
        cleanup();
        return -1;
    }
    timeout.tv_sec = 4;
    setsockopt(sock_fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(sock_fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
    return 0;
}

static int process(int mode) {
    const uint8_t eu[4] = {0x05, 0x59, 0x00, 0x00};
    const uint8_t na[4] = {0x05, 0x49, 0x00, 0x00};
    const uint8_t *wanted = mode == 2 ? na : eu;
    int mismatches = 0;

    if (connect_diag_socket()) {
        fprintf(stderr, "ERROR: diag_socket_log connection failed\n");
        return 10;
    }
    if (efs_hello()) {
        fprintf(stderr, "ERROR: EFS handshake failed\n");
        cleanup();
        return 11;
    }

    for (size_t i = 0; i < sizeof(paths) / sizeof(paths[0]); ++i) {
        uint8_t current[4], verified[4];
        if (efs_read4(paths[i], current)) {
            if (i == 1) {
                printf("OPTIONAL_MISSING: %s\n", paths[i]);
                continue;
            }
            fprintf(stderr, "ERROR: cannot read %s\n", paths[i]);
            cleanup();
            return 12;
        }
        printf("%s = %02x %02x %02x %02x\n", paths[i], current[0], current[1], current[2], current[3]);
        if (!memcmp(current, wanted, 4)) continue;
        ++mismatches;
        if (mode == 0) continue;
        if (memcmp(current, eu, 4) && memcmp(current, na, 4)) {
            fprintf(stderr, "REFUSED: unexpected value at %s\n", paths[i]);
            cleanup();
            return 13;
        }
        if (efs_write4(paths[i], wanted) || efs_read4(paths[i], verified) || memcmp(verified, wanted, 4)) {
            fprintf(stderr, "ERROR: verified write failed at %s\n", paths[i]);
            cleanup();
            return 14;
        }
        printf("REPAIRED: %s -> %02x %02x %02x %02x\n", paths[i], wanted[0], wanted[1], wanted[2], wanted[3]);
    }

    cleanup();
    if (mode == 0 && mismatches) return 2;
    return 0;
}

int main(int argc, char **argv) {
    int mode = 0;
    if (argc == 2 && !strcmp(argv[1], "--repair")) mode = 1;
    else if (argc == 2 && !strcmp(argv[1], "--set-na")) mode = 2;
    else if (!(argc == 2 && !strcmp(argv[1], "--check"))) {
        fprintf(stderr, "usage: %s --check|--repair|--set-na\n", argv[0]);
        return 64;
    }
    signal(SIGPIPE, SIG_IGN);
    atexit(cleanup);
    return process(mode);
}
