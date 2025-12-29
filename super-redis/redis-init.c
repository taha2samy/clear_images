#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/types.h>

#define REDIS_UID 999
#define REDIS_GID 999

int main(int argc, char **argv) {
    // ---------------------------------------------------------
    // 1. Fix Kernel Settings (Must be root here)
    // ---------------------------------------------------------
    printf("=> [redis-init] Checking vm.overcommit_memory...\n");
    FILE *f = fopen("/proc/sys/vm/overcommit_memory", "w");
    if (f) {
        if (fprintf(f, "1") > 0) {
            printf("=> [redis-init] SUCCESS: vm.overcommit_memory set to 1.\n");
        } else {
            fprintf(stderr, "=> [redis-init] WARNING: Failed to write to /proc/sys/vm/overcommit_memory.\n");
        }
        fclose(f);
    } else {
        fprintf(stderr, "=> [redis-init] WARNING: Cannot open /proc/sys/vm/overcommit_memory (Permission Denied).\n");
    }

    // ---------------------------------------------------------
    // 2. Drop Privileges (Switch to 'redis' user)
    // ---------------------------------------------------------
    printf("=> [redis-init] Dropping privileges to user redis (%d:%d)...\n", REDIS_UID, REDIS_GID);

    // Set Group ID first
    if (setgid(REDIS_GID) != 0) {
        perror("=> [redis-init] FATAL: Failed to set GID");
        return 1;
    }

    // Set User ID second (dropping root permanently)
    if (setuid(REDIS_UID) != 0) {
        perror("=> [redis-init] FATAL: Failed to set UID");
        return 1;
    }

    // ---------------------------------------------------------
    // 3. Launch Redis Server
    // ---------------------------------------------------------
    printf("=> [redis-init] Starting redis-server as unprivileged user...\n");
    
    char *redis_bin = "/usr/local/bin/redis-server";
    
    // We update argv[0] to make the process look nice in ps/top
    argv[0] = "redis-server";

    // Replace the current process image with redis-server
    // This preserves the PID 1 behavior if we are PID 1
    execv(redis_bin, argv);

    // If we get here, execv failed
    perror("=> [redis-init] FATAL: Failed to exec redis-server");
    return 1;
}
