//
//  AppDelegate.h
//  iamhere
//
//  Created by Jonas De Vuyst on 12/3/14.
//  Copyright (c) 2014 Jonas De Vuyst. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <AVFoundation/AVFoundation.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@property BOOL isScreenOn;

@property BOOL isUserSessionActive;

@property BOOL wasUserActive;

@property (nonatomic, retain) NSDate *awakeUntil;

@property (nonatomic, retain) AVCaptureSession *session;

@property (nonatomic, retain) NSTimer *updateTimer;

@property (assign) IBOutlet NSMenu *trayMenu;

@property (assign) IBOutlet NSMenuItem *miFaceDetection;

@property (assign) IBOutlet NSMenuItem *miNeverSleep;

@property (assign) IBOutlet NSMenuItem *miAwakeUntil;

@property (assign) IBOutlet NSMenuItem *miLoginItem;

@property (assign) IBOutlet NSMenuItem *miQuit;

@property (nonatomic, retain) IBOutlet NSStatusItem *statusItem;

-(IBAction)toggleFaceDetection:(id)sender;

-(IBAction)toggleNeverSleep:(id)sender;

-(IBAction)toggleStayAwakeUntil:(id)sender;

-(IBAction)stayAwakeFor:(id)sender;

-(IBAction)toggleLaunchAtLogin:(id)sender;

- (void)update;

@end
