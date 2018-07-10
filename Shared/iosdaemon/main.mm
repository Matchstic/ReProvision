//
//  main.m
//  iosdaemon
//
//  Created by Matt Clarke on 05/07/2018.
//  Copyright (c) 2018 Matt Clarke. All rights reserved.
//

#import "RPVDaemonListener.h"

int main(int argc, const char *argv[])
{
    NSLog(@"*** [reprovisiond] :: Loading up daemon.");
    
    // initialize our daemon
    RPVDaemonListener *listener = [[RPVDaemonListener alloc] init];
    
    // start a timer so that the process does not exit.
    NSTimer *timer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                              interval:1 // Slight delay for battery life improvements
                                                target:listener
                                              selector:@selector(timerFireMethod:)
                                              userInfo:nil
                                               repeats:YES];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    [runLoop addTimer:timer forMode:NSDefaultRunLoopMode];
    [runLoop run];
    
    return EXIT_SUCCESS;
}
