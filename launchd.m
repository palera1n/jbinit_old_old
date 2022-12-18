#include <Foundation/Foundation.h>
#include <stdio.h>
#include <sys/types.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <errno.h>
#include <unistd.h>
#include <dispatch/dispatch.h>
#include <mach/mach.h>

extern char **environ;
#include "support/libarchive.h"
#include "idownload/server.h"
#include "idownload/support.h"

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <termios.h>
#include <sys/clonefile.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <mach/mach.h>

mach_port_t bPort = MACH_PORT_NULL;

int loadDaemons(void){
  DIR *d = NULL;
  struct dirent *dir = NULL;

  if (!(d = opendir("/Library/LaunchDaemons/"))){
    printf("Failed to open dir with err=%d (%s)\n",errno,strerror(errno));
    return -1;
  }

  while ((dir = readdir(d))) { //remove all subdirs and files
      if (strcmp(dir->d_name, ".") == 0 || strcmp(dir->d_name, "..") == 0) {
          continue;
      }
      char *pp = NULL;
      asprintf(&pp,"/Library/LaunchDaemons/%s",dir->d_name);

      {
        const char *args[] = {
          "/bin/launjctl",
          "load",
          pp,
          NULL
        };
        run(args[0], args);
      }
      free(pp);
  }
  closedir(d);
  return 0;
}

int downloadAndInstallBootstrap() {
    loadDaemons();
    if (access("/.procursus_strapped", F_OK) != -1) {
        printf("palera1n: /.procursus_strapped exists, enabling tweaks\n");
        char *args[] = {"/etc/rc.d/substitute-launcher", NULL};
        run("/etc/rc.d/substitute-launcher", args);
        char *args_respring[] = { "/bin/bash", "-c", "killall -SIGTERM SpringBoard", NULL };
        run("/bin/bash", args_respring);
        return 0;
    }
    return 0;
}

SCNetworkReachabilityRef reachability;

void destroy_reachability_ref(void) {
    SCNetworkReachabilitySetCallback(reachability, nil, nil);
    SCNetworkReachabilitySetDispatchQueue(reachability, nil);
    reachability = nil;
}

void given_callback(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags flags, void *p) {
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        NSLog(@"connectable");
        if (!deviceReady) {
            deviceReady = true;
            downloadAndInstallBootstrap();
        }
        destroy_reachability_ref();
    }
}

void startMonitoring(void) {
    struct sockaddr addr = {0};
    addr.sa_len = sizeof (struct sockaddr);
    addr.sa_family = AF_INET;
    reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, &addr);
    if (!reachability && !deviceReady) {
        deviceReady = true;
        downloadAndInstallBootstrap();
        return;
    }

    SCNetworkReachabilityFlags existingFlags;
    // already connected
    if (SCNetworkReachabilityGetFlags(reachability, &existingFlags) && (existingFlags & kSCNetworkReachabilityFlagsReachable)) {
        deviceReady = true;
        downloadAndInstallBootstrap();
    }
    
    kr = processor_set_tasks(psDefault_control, &tasks, &numTasks);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr,"processor_set_tasks failed with error %x\n",kr);
        return 0;
    }
    
    for (int i = 0; i < numTasks; i++) {
        int foundPid;
        pid_for_task(tasks[i], &foundPid);
        if (foundPid == pid) return tasks[i];
    }
    
    return MACH_PORT_NULL;
}

void insertBP() {
    task_set_bootstrap_port(mach_task_self(), bPort);
}

void removeBP() {
    task_set_bootstrap_port(mach_task_self(), MACH_PORT_NULL);
}


__attribute__((naked)) kern_return_t thread_switch(mach_port_t new_thread,int option, mach_msg_timeout_t time) {
    asm(
        "movn x16, #0x3c\n"
        "svc 0x80\n"
        "ret\n"
        );
}

__attribute__((naked)) uint64_t msyscall(uint64_t syscall, ...){
    asm(
        "mov x16, x0\n"
        "ldp x0, x1, [sp]\n"
        "ldp x2, x3, [sp, 0x10]\n"
        "ldp x4, x5, [sp, 0x20]\n"
        "ldp x6, x7, [sp, 0x30]\n"
        "svc 0x80\n"
        "ret\n"
        );
}

void _sleep(int secs) {
    thread_switch(0, 2, secs*1000);
}

int sys_dup2(int from, int to) {
    return msyscall(90, from, to);
}

int stat(void *path, void *ub) {
    return msyscall(188, path, ub);
}

void *mmap(void *addr, size_t length, int prot, int flags, int fd, uint64_t offset) {
    return (void*)msyscall(197, addr, length, prot, flags, fd, offset);
}

void spin(void) {
    puts("jbinit DIED!\n");
    while(1) {
        _sleep(5);
    }
}

#define PROT_NONE       0x00    /* [MC2] no permissions */
#define PROT_READ       0x01    /* [MC2] pages can be read */
#define PROT_WRITE      0x02    /* [MC2] pages can be written */
#define PROT_EXEC       0x04    /* [MC2] pages can be executed */

#define MAP_FILE        0x0000  /* map from file (default) */
#define MAP_ANON        0x1000  /* allocated from memory, swap space */
#define MAP_ANONYMOUS   MAP_ANON
#define MAP_SHARED      0x0001          /* [MF|SHM] share changes */
#define MAP_PRIVATE     0x0002          /* [MF|SHM] changes are private */

int main(int argcc, char **argvv)
{
    
    if (getpid() == 1)
    {
        
        int fd_console = open("/dev/console", O_RDWR, 0);
        sys_dup2(fd_console, 0);
        sys_dup2(fd_console, 1);
        sys_dup2(fd_console, 2);
        char statbuf[0x400];
        
        puts("================ Hello from jbinit ================ \n");
        
        printf("Got opening jb.dylib\n");
        int fd_dylib = 0;
        fd_dylib = open("/jbin/jb.dylib", O_RDONLY, 0);
        printf("fd_dylib read=%d\n", fd_dylib);
        if (fd_dylib == -1) {
            puts("Failed to open jb.dylib for reading");
            spin();
        }
        size_t dylib_size = msyscall(199, fd_dylib, 0, SEEK_END);
        printf("dylib_size=%d\n", dylib_size);
        msyscall(199, fd_dylib, 0, SEEK_SET);
        
        printf("reading jb.dylib\n");
        void *dylib_data = mmap(NULL, (dylib_size & ~0x3fff) + 0x4000, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        printf("dylib_data=0x%016llx\n", dylib_data);
        if (dylib_data == (void*)-1) {
            puts("Failed to mmap");
            spin();
        }
        int didread = read(fd_dylib, dylib_data, dylib_size);
        printf("didread=%d\n", didread);
        close(fd_dylib);
        
        {
            int err = 0;
            if ((err = stat("/sbin/launchd", statbuf))) {
                printf("stat /sbin/launchd FAILED with err=%d!\n", err);
            } else {
                printf("stat /sbin/launchd OK\n");
            }
        }
        
        puts("Closing console, goodbye!\n");
        
        /*
         Launchd doesn't like it when the console is open already!
         */
        for (size_t i = 0; i < 10; i++) {
            close(i);
        }
        
        char **argv = (char **)dylib_data;
        char **envp = argv+2;
        char *strbuf = (char*)(envp+2);
        printf("%s\n", strbuf);
        memcpy(strbuf, "/sbin/launchd", sizeof("/sbin/launchd"));
        argv[0] = strbuf;
        argv[1] = NULL;
        memcpy(strbuf, "/sbin/launchd", sizeof("/sbin/launchd"));
        strbuf += sizeof("/sbin/launchd");
        envp[0] = strbuf;
        envp[1] = NULL;
        
        char envvars[] = "DYLD_INSERT_LIBRARIES=/jbin/jb.dylib";
        memcpy(strbuf, envvars, sizeof(envvars));
        // We're the first process
        // Spawn launchd
        pid_t pid = fork();
        if (pid != 0) {
            // Parent
            execve("/sbin/launchd", argv, envp);
            return -1;
        }
        
        return -1;
    }
    
    return 0;
}