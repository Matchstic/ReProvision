#import <Foundation/Foundation.h>
#include <spawn.h>
#include <string.h>

void xlog(NSString *string) {
    printf("%s\n", [string UTF8String]);
}

static int run_system(const char *args[]) {
    pid_t pid;
    int stat;
    posix_spawn(&pid, args[0], NULL, NULL, (char **) args, NULL);
    waitpid(pid, &stat, 0);
    return stat;
}

void removeApplication() {
    // First, clear if already existing.
    
    xlog(@"Removing files...");
    
    [[NSFileManager defaultManager] removeItemAtPath:@"/Applications/Extender.app" error:nil];

    xlog(@"Proceeding to reload uicache.");
    
    const char *args1[] = {"/usr/bin/uicache", "-c", NULL};
    int val = run_system(args1);
    if (val != 0) {
        xlog(@"ERROR: Failed to reload uicache!");
    } else {
        xlog(@"Removed Cydia Extender.");
    }
}

int main(int argc, char **argv, char **envp) {
    
    @autoreleasepool {
        // When we are called, we should remove the application. However, this may occur on both
        // an uninstall and an upgrade. So, we should handle that appropriately.
        
        BOOL shouldRemove = !strncmp(argv[1], "remove", 6);
        
        if (shouldRemove) {
            removeApplication();
        }
        
    }
    
	return 0;
}
