#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>

#define REDIS_UID 999
#define REDIS_GID 999

int main(int argc, char **argv) {
    printf("=> [redis-init] Checking vm.overcommit_memory...\n");
    
    FILE *f = fopen("/proc/sys/vm/overcommit_memory", "w");
    if (f) {
        fprintf(f, "1");
        fclose(f);
        printf("=> [redis-init] vm.overcommit_memory set to 1\n");
    }

    printf("=> [redis-init] Dropping privileges to redis (%d:%d)...\n", REDIS_UID, REDIS_GID);
    
    if (setgid(REDIS_GID) != 0) {
        perror("=> [redis-init] Failed setgid");
        return 1;
    }
    if (setuid(REDIS_UID) != 0) {
        perror("=> [redis-init] Failed setuid");
        return 1;
    }

    printf("=> [redis-init] Starting redis-server...\n");
    
    char *redis_bin = "/usr/local/bin/redis-server";
    execv(redis_bin, argv);
    
    perror("=> [redis-init] Failed exec redis-server");
    return 1;
}
