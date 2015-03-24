//
//  AppDelegate.m
//  iamhereLauncher
//
//  Created by Jonas De Vuyst on 29/3/14.
//  Copyright (c) 2014 Jonas De Vuyst. All rights reserved.
//

#import "AppDelegate.h"

#import <ServiceManagement/ServiceManagement.h>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // http://blog.timschroeder.net/2012/07/03/the-launch-at-login-sandbox-project/
    // http://www.delitestudio.com/2011/10/25/start-dockless-apps-at-login-with-app-sandbox-enabled/
    
    // Check if main app is already running; if yes, do nothing and terminate helper app
    BOOL alreadyRunning = NO;
    NSArray *running = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication *app in running) {
        if ([[app bundleIdentifier] isEqualToString:@"jdevuyst.iamhere"]) {
            alreadyRunning = YES;
            //NSLog(@"iamhere is already running");
        }
    }
    
    if (!alreadyRunning) {
        NSString *path = [[NSBundle mainBundle] bundlePath];
        NSArray *p = [path pathComponents];
        NSMutableArray *pathComponents = [NSMutableArray arrayWithArray:p];
        [pathComponents removeLastObject];
        [pathComponents removeLastObject];
        [pathComponents removeLastObject];
        [pathComponents addObject:@"MacOS"];
        [pathComponents addObject:@"iamhere"];
        NSString *newPath = [NSString pathWithComponents:pathComponents];
        BOOL success = [[NSWorkspace sharedWorkspace] launchApplication:newPath];
        
        if(!success) {
            NSLog(@"Couldn't launch main app %@ (helper app path: %@)", newPath, path);
            
            // Remove helper app from log in items
            success = SMLoginItemSetEnabled((__bridge CFStringRef)@"jdevuyst.iamhereLauncher", NO);
            
            if(!success) {
                NSLog(@"Couldn't remove helper app from launch at login item list.");
            }
            
            exit(EXIT_FAILURE);
        }
    }
    
    [NSApp stop:nil];
}

@end
