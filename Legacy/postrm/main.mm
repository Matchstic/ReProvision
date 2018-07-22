#import <Foundation/Foundation.h>
#include <spawn.h>

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

void reloadInstalld() {
    
    static const char *plist = "/System/Library/LaunchDaemons/com.apple.mobile.installd.plist";
    
    const char *args1[] = {"/bin/launchctl", "unload", plist, NULL};
    int val = run_system(args1);
    
    if (val != 0) {
        xlog(@"ERROR: Failed to unload installd; a reboot will be required.");
    }
    
    const char *args2[] = {"/bin/launchctl", "load", plist, NULL};
    val = run_system(args2);
    
    if (val != 0) {
        xlog(@"ERROR: Failed to load installd; a reboot will be required.");
    }
    
    xlog(@"installd reloaded.");
}

int main(int argc, char **argv, char **envp) {
    
    @autoreleasepool {
        BOOL shouldRemove = !strncmp(argv[1], "remove", 6);
        
        if (shouldRemove)
            reloadInstalld();
    }
    
    return 0;
}
