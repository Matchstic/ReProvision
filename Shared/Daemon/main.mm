//
//  main.m
//  iosdaemon
//
//  Created by Matt Clarke on 05/07/2018.
//  Copyright (c) 2018 Matt Clarke. All rights reserved.
//

#import "RPVDaemonListener.h"

@interface NSXPCListener (Private)
- (id)initWithMachServiceName:(NSString*)arg1;
@end

int main(int argc, const char *argv[])
{
    NSLog(@"*** [reprovisiond] :: Loading up daemon.");
    
    // initialize our daemon
    RPVDaemonListener *daemon = [[RPVDaemonListener alloc] init];
    [daemon initialiseListener];
    
    // Bypass compiler prohibited errors
    Class NSXPCListenerClass = NSClassFromString(@"NSXPCListener");
    
    NSXPCListener *listener = [[NSXPCListenerClass alloc] initWithMachServiceName:@"com.matchstic.reprovisiond"];
    listener.delegate = daemon;
    [listener resume];
    
    // Run the run loop forever.
    [[NSRunLoop currentRunLoop] run];
    
    return EXIT_SUCCESS;
}
