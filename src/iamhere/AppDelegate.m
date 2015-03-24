//
//  AppDelegate.m
//  iamhere
//
//  Created by Jonas De Vuyst on 12/3/14.
//  Copyright (c) 2014 Jonas De Vuyst. All rights reserved.
//

// http://iphoneincubator.com/blog/debugging/the-evolution-of-a-replacement-for-nslog

#define ASSERT_MAIN_THREAD NSCAssert(NSThread.isMainThread, @"expected main thread.");

#define DEBUG 1

#ifdef DEBUG

#define DLog NSLog

#else

#define DLog(...)
#undef assert
#define assert(...)

#endif

#import "AppDelegate.h"

#import <IOKit/ps/IOPowerSources.h>
#import <ServiceManagement/ServiceManagement.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

const NSTimeInterval IDEAL_DURATION = 4, TOLERANCE = 1, RETRY_INTERVAL = 60 - IDEAL_DURATION;

void pmDidChange(void *context) {
    DLog(@"Power Management Event");
    [(AppDelegate *)[NSApp delegate] update];
}

@implementation AppDelegate

-(void)updateIcon
{
    DLog(@"Updating icon");
    
    BOOL b
    = self.miFaceDetection.state
    || self.miNeverSleep.state
    || self.awakeUntil != nil;
    
    [self.statusItem setImage:[NSImage imageNamed:(b ? @"Active" : @"Disabled")]];
}

-(IBAction)toggleFaceDetection:(id)sender
{
    ASSERT_MAIN_THREAD
    
    BOOL newState = !self.miFaceDetection.state;
    
    DLog(@"%@abled Face Detection", newState ? @"En" : @"Dis");
    
    self.miFaceDetection.state = newState;
    [[NSUserDefaults standardUserDefaults] setBool:!newState forKey:@"DisableFaceDetection"];
    
    if(sender != nil) {
        [self update];
    }
    
    [self updateIcon];
}

-(IBAction)toggleNeverSleep:(id)sender
{
    ASSERT_MAIN_THREAD
    
    BOOL newState = !self.miNeverSleep.state;
    
    DLog(@"%@abled Never Sleep", newState ? @"En" : @"Dis");
    
    self.miNeverSleep.state = newState;
    [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"NeverSleep"];
    
    [self.miFaceDetection setEnabled:!newState];
    
    if(sender != nil && self.miAwakeUntil.state) {
        [self toggleStayAwakeUntil:nil];
    }
    
    if(sender != nil) {
        [self update];
    }
    
    [self updateIcon];
}

-(IBAction)toggleStayAwakeUntil:(id)sender
{
    ASSERT_MAIN_THREAD
    
    self.miAwakeUntil.state = !self.miAwakeUntil.state;
    
    if(self.miAwakeUntil.state) {
        self.awakeUntil = self.miAwakeUntil.representedObject;
        DLog(@"Reenabled Stay Awake Until %@", self.awakeUntil);
    } else {
        self.awakeUntil = nil;
        DLog(@"Disabled Stay Awake Until");
    }
    
    if(sender != nil && self.miNeverSleep.state) {
        [self toggleNeverSleep:nil];
    }
    
    [self updateIcon];
}

-(void)detailedStayAwakeUntil
{
    ASSERT_MAIN_THREAD
    
    NSDateFormatter *dateFmter = [[NSDateFormatter alloc] init];
    [dateFmter setTimeStyle:NSDateFormatterMediumStyle];
    [dateFmter setDateStyle:NSDateFormatterNoStyle];
    self.miAwakeUntil.title = [NSString stringWithFormat:@"Stay Awake Until %@",
                               [dateFmter stringFromDate: self.miAwakeUntil.representedObject]];
}

-(void)clearStayAwakeUntil
{
    ASSERT_MAIN_THREAD
    
    DLog(@"End of Stay Awake Until %@", self.awakeUntil);
    
    self.awakeUntil = nil;
    [self.miAwakeUntil setHidden:YES];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearStayAwakeUntil) object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(detailedStayAwakeUntil) object:nil];
    
    [self updateIcon];
}

- (void)scheduleStayAwakeUntilSelectors
{
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSTimeInterval remaining = self.awakeUntil == nil ? 0 : [self.awakeUntil timeIntervalSinceNow];
    
//    DLog(@"Scheduling selectors. Time remaining: %f", remaining);
    
    if(self.awakeUntil != nil) {
        NSInteger secs = [cal component:NSSecondCalendarUnit fromDate:self.awakeUntil];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(detailedStayAwakeUntil) object:nil];
        [self performSelector:@selector(detailedStayAwakeUntil) withObject:nil afterDelay:(remaining - 120 - secs) inModes:@[NSRunLoopCommonModes]];
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearStayAwakeUntil) object:nil];
    [self performSelector:@selector(clearStayAwakeUntil) withObject:nil afterDelay:(remaining) inModes:@[NSRunLoopCommonModes]];
}

-(IBAction)stayAwakeFor:(id)sender
{
    ASSERT_MAIN_THREAD
    
    assert(sender != nil);
    
    NSMenuItem *mi = (NSMenuItem*)sender;
    
    if(self.miNeverSleep.state) {
        [self toggleNeverSleep:nil];
    }
    
    self.awakeUntil = [NSDate dateWithTimeIntervalSinceNow:(60 * mi.tag)];
    self.miAwakeUntil.representedObject = self.awakeUntil;
    //DLog(@"Stay Awake Until %@ (%lu\")", self.awakeUntil, mi.tag);
    
    NSDateFormatter *dateFmter = [[NSDateFormatter alloc] init];
    [dateFmter setTimeStyle:NSDateFormatterShortStyle];
    [dateFmter setDateStyle:NSDateFormatterNoStyle];
    self.miAwakeUntil.title = [NSString stringWithFormat:@"Stay Awake Until %@",
                               [dateFmter stringFromDate: self.awakeUntil]];
    self.miAwakeUntil.state = YES;
    [self.miAwakeUntil setHidden:NO];
    
    [self scheduleStayAwakeUntilSelectors];
    
    DLog(@"Stay Awake Until %@", self.awakeUntil);
    
    [self update];
    
    [self updateIcon];
}

-(IBAction)toggleLaunchAtLogin:(id)sender
{
    ASSERT_MAIN_THREAD
    
    NSMenuItem *mItem = (NSMenuItem*) sender;
    
    if ([mItem state] == 0) {
        // Turn on launch at login
        DLog(@"Adding iamhereLauncher to login items");
        if (!SMLoginItemSetEnabled ((__bridge CFStringRef)@"jdevuyst.iamhereLauncher", YES)) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"An error ocurred"
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"Couldn't add helper app to launch at login item list."];
            [alert runModal];
        }
    } else {
        // Turn off launch at login
        DLog(@"Removing iamhereLauncher from login items");
        if (!SMLoginItemSetEnabled ((__bridge CFStringRef)@"jdevuyst.iamhereLauncher", NO)) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"An error ocurred"
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"Couldn't remove helper app from launch at login item list."];
            [alert runModal];
        }
    }
    
    [self setLoginItemMenuItemState];
}

-(void)setLoginItemMenuItemState
{
    ASSERT_MAIN_THREAD
    
    BOOL b = NO;
    
    CFArrayRef cfJobDicts = SMCopyAllJobDictionaries(kSMDomainUserLaunchd);
    NSArray* jobDicts = CFBridgingRelease(cfJobDicts);
    //DLog(@"Login items: %@", jobDicts);
    
    for(id job in jobDicts) {
        if([[job objectForKey:@"Label"] isEqualToString:@"jdevuyst.iamhereLauncher"]) {
            b = YES;
            break;
        }
    }
    
    self.miLoginItem.state = b;
}

// Create a UIImage from sample buffer data
- (CIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    CIImage *image = [CIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

// Create and configure a capture session
- (void)startCamera
{
    ASSERT_MAIN_THREAD
    
    assert(self.session == nil);
    
    DLog(@"Will start camera");
    
    NSError *error = nil;
    
    // Create the session
    AVCaptureSession *session = [AVCaptureSession new];
    
    // Configure the session to produce lower resolution video frames, if your
    // processing algorithm can cope. We'll specify medium quality for the
    // chosen device.
    session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                        error:&error];
    if (!input) {
        // Handling the error appropriately.
        NSLog(@"No input device: %@", error);
        return; // the camera could be in use
    }
    [session addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    AVCaptureVideoDataOutput *output = [AVCaptureVideoDataOutput new];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("captureQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    //dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings =
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set
    // minFrameDuration.
    //output.minFrameDuration = CMTimeMake(1, 15);
    
    // Assign session to an ivar.
    [self setSession:session];
    
    [self.session startRunning];
    
    DLog(@"Did start camera");
}

- (void)stopCamera
{\
    ASSERT_MAIN_THREAD
    
    assert(self.session != nil);
    assert(self.session.running);
    
    DLog(@"Will stop camera");
    [self.session stopRunning];
    
    self.session = nil;
    DLog(@"Did stop camera");
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    DLog(@"Dropped a frame");
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    DLog(@"Will process a frame");
    
    if (! connection.videoMinFrameDuration.flags & kCMTimeFlags_Valid) {
        DLog(@"New connection detected. Will limit frame rate.");
        const CMTime FRAME_RATE = CMTimeMake(1, 4);
        connection.videoMinFrameDuration = FRAME_RATE;
    }
    
    // Create a UIImage from the sample buffer data
    CIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
    if (! image) {
        NSLog(@"Failed to load image from webcam");
        return;
    }
    
    // Create the face detector
    static dispatch_once_t unique;
    static CIDetector *faceDetector;
    dispatch_once(&unique, ^{
        DLog(@"Initializing face detector");
        faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
    });
    
    // Detect the faces
    NSArray *faces = [faceDetector featuresInImage:image];
    if ([faces count] > 0) {
        DLog(@"Did process a frame (face(s) detected)");
        dispatch_sync(dispatch_get_main_queue(), ^{
            ASSERT_MAIN_THREAD
            [self preventSleep:@"Face(s) Detected"];
            [self updateRacy];
        });
    } else {
        DLog(@"Did process a frame (no face(s) detected)");
    }
}

- (void) preventSleep:(NSString *)reason
{
    ASSERT_MAIN_THREAD
    
    DLog(@"%@ => Preventing Sleep", reason);
    
    // kIOPMAssertionTypeNoDisplaySleep prevents display sleep,
    // kIOPMAssertionTypeNoIdleSleep prevents idle sleep
    
    //reasonForActivity is a descriptive string used by the system whenever it needs
    //  to tell the user why the system is not sleeping. For example,
    //  "Mail Compacting Mailboxes" would be a useful string.
    
    //  NOTE: IOPMAssertionCreateWithName limits the string to 128 characters.
    CFStringRef reasonForActivity= (__bridge CFStringRef)reason;
    
    IOPMAssertionID assertionID;
    //IOReturn success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep,
    //                                               kIOPMAssertionLevelOn, reasonForActivity, &assertionID);
    IOReturn success = IOPMAssertionDeclareUserActivity(reasonForActivity, kIOPMUserActiveLocal, &assertionID);
    
    assert(success == kIOReturnSuccess);
}

- (void)screensDidSleep
{
    ASSERT_MAIN_THREAD
    
    if(!self.isUserSessionActive) {
        DLog(@"screensDidSleep called while user session inactive");
        return;
    }
    
    assert(self.isScreenOn);
    DLog(@"Screens Fell Asleep");
    
    self.isScreenOn = NO;
    self.wasUserActive = NO;
    
    if(self.miAwakeUntil.state) {
        [self toggleStayAwakeUntil:nil];
    }
    
    [self update];
}

- (void)screensDidWake
{
    ASSERT_MAIN_THREAD
    
    if(!self.isUserSessionActive) {
        DLog(@"screensDidWake called while user session inactive");
        return;
    }
    
    assert(!self.isScreenOn);
    DLog(@"Screens Woke Up");
    
    self.isScreenOn = YES;
}

- (void)didActivateApp
{
    ASSERT_MAIN_THREAD
    
    if(self.isScreenOn && !self.wasUserActive) {
        DLog(@"Workspace Activated");
        
//        [self startCamera];
//        [self stopCamera];
        
        self.wasUserActive = YES;
        [self updateRacy];
        
        [self scheduleStayAwakeUntilSelectors];
    }
}

- (void)didActivateUserSession
{
    DLog(@"Switched to this user");
    
    self.isUserSessionActive = YES;
    self.isScreenOn = YES;
    self.wasUserActive = NO;
    [self didActivateApp];
}

- (void)didDeactivateUserSession
{
    DLog(@"Switched to a different user");
    
    self.isUserSessionActive = NO;
    self.isScreenOn = NO;
    self.wasUserActive = NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    ASSERT_MAIN_THREAD
    
    self.isScreenOn = YES;
    self.isUserSessionActive = YES;
    
    // Initialize menu items
    [self setLoginItemMenuItemState];
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"DisableFaceDetection"]) {
        [self toggleFaceDetection:nil];
    }
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"NeverSleep"]) {
        [self toggleNeverSleep:nil];
    }
    self.miQuit.title = [[NSString alloc] initWithFormat:@"%@ %@",
                         self.miQuit.title,
                         [[NSRunningApplication currentApplication] localizedName]];
    
    // Install status bar menu
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [self.statusItem setHighlightMode:YES];
    [self.trayMenu setAutoenablesItems:NO];
    [self.statusItem setMenu:self.trayMenu];
    [self updateIcon];
    
    // Setup power management notifications
    {
//        CFRunLoopSourceRef source1 = IOPMPrefsNotificationCreateRunLoopSource(pmDidChange, nil); // private API
        CFRunLoopSourceRef source2 = IOPSNotificationCreateRunLoopSource(pmDidChange, nil);
        
        CFRunLoopRef runLoop = [[NSRunLoop mainRunLoop] getCFRunLoop];
//        CFRunLoopAddSource(runLoop, source1, kCFRunLoopCommonModes); // depends on private API
        CFRunLoopAddSource(runLoop, source2, kCFRunLoopCommonModes);
        
//        CFRelease(source1); // depends on private API
        CFRelease(source2);
        CFRelease(runLoop);
    }
    
    // Setup other notification
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(screensDidSleep)
                                                               name: NSWorkspaceScreensDidSleepNotification
                                                             object: nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(screensDidWake)
                                                               name: NSWorkspaceScreensDidWakeNotification
                                                             object: nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(didActivateApp)
                                                               name: NSWorkspaceDidActivateApplicationNotification
                                                             object: nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(didActivateUserSession)
                                                               name: NSWorkspaceSessionDidBecomeActiveNotification
                                                             object: nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self
                                                           selector: @selector(didDeactivateUserSession)
                                                               name: NSWorkspaceSessionDidResignActiveNotification
                                                             object: nil];
}

- (void)update
{
    [self update:NO];
}

- (void)updateRacy
{
    [self update:YES];
}

- (void)update:(BOOL)racy
{
    ASSERT_MAIN_THREAD
    
    DLog(@"Running update");
    
    [self.updateTimer invalidate];
    
    BOOL cameraWasRunning = [self.session isRunning];
    if(cameraWasRunning) {
        DLog(@"Turning Camera Off");
        [self stopCamera];
    }
    
    if(! self.wasUserActive) {
        DLog(@"User Not Found => Return");
        return;
    }
    
    if(!self.miFaceDetection.state && !self.miNeverSleep.state && self.awakeUntil == nil) {
        DLog(@"All Features Disabled => Return");
        return;
    }
    
    NSString *reason = @"Unknown Reason";
    const NSDate *d = [NSDate dateWithTimeIntervalSince1970:0];
    const NSDate *now = [NSDate new];
    
    // Check current assertions for activity
    {
        NSDictionary *assertions = [NSDictionary new];
        CFDictionaryRef assertionsRef = CFBridgingRetain(assertions);
        IOReturn success = IOPMCopyAssertionsByProcess(&assertionsRef);
        
        assert(success == kIOReturnSuccess);
        
        //NSDictionary *assertions = CFBridgingRelease(*assertionsRef);
        
        CFRelease(assertionsRef);
        //DLog(@"assertions: %@", assertions);
        
        for(id key in assertions) {
            for(id assertion in [assertions objectForKey:key]) {
                NSString *assertType = [assertion objectForKey:@"AssertType"];
                
                if([assertType isEqualToString:@"UserIsActive"]) {
                    NSDate *prediction = [assertion objectForKey:@"AssertTimeoutUpdateTime"];
                    
                    NSNumber *timeLeft = [assertion objectForKey:@"AssertTimeoutTimeLeft"];
                    
                    if([timeLeft isEqualTo:@0]) {
                        DLog(@"No Blank Screen on Idle => Return");
                        return;
                    }
                    
                    prediction = [prediction dateByAddingTimeInterval:[timeLeft doubleValue]];
                    
                    if([prediction isGreaterThan:d]) {
                        //DLog(@"New most recent user activity found");
                        reason = @"Predicted Standby Time";
                        d = prediction;
                        self.wasUserActive = YES;
                    }
                } else if([assertType isEqualToString:@"InternalPreventDisplaySleep"] > 0
                          || [assertType isEqualToString:@"PreventUserIdleDisplaySleep"] > 0) {
                    DLog(@"An app is preventing the screen from sleeping");
                }
            }
        }
    }
    
    // Take into account time needed for face detection
    d = [d dateByAddingTimeInterval:-IDEAL_DURATION];
    
    // Decide on next action
    if([now isGreaterThanOrEqualTo:[d dateByAddingTimeInterval:-TOLERANCE]]) {
        if(racy) {
            reason = @"No user activity detected, but racy";
            d = [now dateByAddingTimeInterval:RETRY_INTERVAL];
        } else if(self.miNeverSleep.state) {
            [self preventSleep:@"Never Sleep"];
            [self update:YES];
            return;
        } else if(self.awakeUntil != nil && [self.awakeUntil isGreaterThanOrEqualTo:now]) {
            [self preventSleep:@"Stay Awake Longer"];
            [self update:YES];
            return;
        } else if(cameraWasRunning) {
            reason = @"No Face(s) Detected";
            d = [now dateByAddingTimeInterval:RETRY_INTERVAL];
        } else if(self.miFaceDetection.state) {
            reason = @"Turning Camera On";
            d = [now dateByAddingTimeInterval:IDEAL_DURATION];
            [self startCamera];
        } else {
            assert(NO);
        }
    }
    
    DLog(@"%@ => Reschedule for %@", reason, d);
    self.updateTimer = [[NSTimer alloc] initWithFireDate:[d copy]
                                                interval:0
                                                  target:self
                                                selector:@selector(update)
                                                userInfo:nil
                                                 repeats:NO];
    [self.updateTimer setTolerance:TOLERANCE];
    [[NSRunLoop currentRunLoop] addTimer:self.updateTimer forMode:NSRunLoopCommonModes];
}

@end
