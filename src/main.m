#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <unistd.h>

static const CFTimeInterval kWarpCooldownSeconds = 0.25;
static const CFTimeInterval kLogRetentionSeconds = 300.0;
static const NSUInteger kMaxVisibleLogEntries = 15;
static const useconds_t kDefaultCursorRestoreDelayMicroseconds = 120000;
static const useconds_t kDefaultSyntheticMouseMoveDelayMicroseconds = 0;
static const useconds_t kDefaultSyntheticClickDelayMicroseconds = 0;
static const useconds_t kDefaultSyntheticInterClickDelayMicroseconds = 90000;
static const useconds_t kDefaultActivationDelayMicroseconds = 60000;
static const useconds_t kDefaultPostActivationSettleDelayMicroseconds = 12000;
static const useconds_t kDefaultFocusCompensationClickDelayMicroseconds = 90000;
static const CFTimeInterval kDefaultTouchCoordinateFreshnessSeconds = 0.20;
static const CFTimeInterval kDefaultNativeMouseSuppressionSeconds = 0.15;
static const int64_t kSyntheticEventTag = 0x58454E454F4EULL;
static const CGFloat kTargetDisplayOwnershipTolerance = 48.0;

@protocol XeneonRuntimeLogCapture <NSObject>
- (void)recordLogMessage:(NSString *)message;
@end

static NSString * const XeneonRuntimeStatusDidChangeNotification = @"XeneonRuntimeStatusDidChangeNotification";
static NSString * const XeneonRuntimeLogsDidChangeNotification = @"XeneonRuntimeLogsDidChangeNotification";
static __weak id<XeneonRuntimeLogCapture> gActiveRuntime = nil;

static void XeneonRuntimeLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void XeneonRuntimeLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    va_list copiedArgs;
    va_copy(copiedArgs, args);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:copiedArgs];
    va_end(copiedArgs);
    va_end(args);

    if (message.length > 0) {
        fprintf(stderr, "%s\n", message.UTF8String);
        fflush(stderr);
        [gActiveRuntime recordLogMessage:message];
    }
}

#define NSLog XeneonRuntimeLog

@interface XeneonRuntime : NSObject <XeneonRuntimeLogCapture>
@property(nonatomic, strong) NSArray<NSString *> *displayNameHints;
@property(nonatomic, strong) NSArray<NSString *> *hidProductNameHints;
@property(nonatomic, strong) NSMutableSet<NSValue *> *seenDevices;
@property(nonatomic, strong) NSMutableSet<NSValue *> *matchedDevices;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *recentLogEntries;
@property(nonatomic, strong, nullable) NSScreen *targetScreen;
@property(nonatomic, assign) CGDirectDisplayID targetDisplayID;
@property(nonatomic, assign) CGDirectDisplayID configuredDisplayID;
@property(nonatomic, assign) int configuredVendorID;
@property(nonatomic, assign) int configuredProductID;
@property(nonatomic, assign) CFTimeInterval lastWarpTime;
@property(nonatomic, assign) CFTimeInterval lastPermissionWarningTime;
@property(nonatomic, assign) BOOL invertTouchY;
@property(nonatomic, assign) BOOL hasTouchX;
@property(nonatomic, assign) BOOL hasTouchY;
@property(nonatomic, assign) double normalizedTouchX;
@property(nonatomic, assign) double normalizedTouchY;
@property(nonatomic, assign) CFTimeInterval lastTouchXTime;
@property(nonatomic, assign) CFTimeInterval lastTouchYTime;
@property(nonatomic, assign) BOOL restoreCursorAfterClick;
@property(nonatomic, assign) useconds_t restoreCursorDelayMicroseconds;
@property(nonatomic, assign) useconds_t syntheticMouseMoveDelayMicroseconds;
@property(nonatomic, assign) useconds_t syntheticClickDelayMicroseconds;
@property(nonatomic, assign) useconds_t syntheticInterClickDelayMicroseconds;
@property(nonatomic, assign) CFTimeInterval touchCoordinateFreshnessSeconds;
@property(nonatomic, assign) CFTimeInterval suppressNativeMouseUntil;
@property(nonatomic, assign) CFTimeInterval nativeMouseSuppressionSeconds;
@property(nonatomic, assign) BOOL takeoverActive;
@property(nonatomic, assign) BOOL takeoverHasWarped;
@property(nonatomic, assign) BOOL takeoverPending;
@property(nonatomic, assign) CGPoint takeoverTargetPoint;
@property(nonatomic, assign) NSPoint takeoverOriginalPointer;
@property(nonatomic, assign) BOOL seizeTouchDevice;
@property(nonatomic, assign) BOOL activateTargetApplication;
@property(nonatomic, assign) useconds_t activationDelayMicroseconds;
@property(nonatomic, assign) useconds_t postActivationSettleDelayMicroseconds;
@property(nonatomic, assign) BOOL sendFocusCompensationClick;
@property(nonatomic, assign) useconds_t focusCompensationClickDelayMicroseconds;
@property(nonatomic, assign) BOOL sendSyntheticMouseMove;
@property(nonatomic, assign) int clickCount;
@property(nonatomic, assign) IOHIDManagerRef hidManager;
@property(nonatomic, assign) CFMachPortRef eventTap;
@property(nonatomic, assign) CFRunLoopSourceRef eventTapSource;
@property(nonatomic, assign) BOOL accessibilityTrusted;
@property(nonatomic, assign) BOOL inputMonitoringTrusted;
@property(nonatomic, assign) BOOL postEventTrusted;
@property(nonatomic, assign) BOOL nativeMouseSuppressionTapActive;
@property(nonatomic, assign) BOOL hidManagerAvailable;
@property(nonatomic, assign) BOOL hidManagerOpenSucceeded;
@property(nonatomic, assign) NSUInteger matchedTouchDeviceCount;
- (void)run;
- (void)start;
- (void)refreshTargetDisplay;
- (void)startNativeMouseSuppressionTap;
- (void)startHIDMonitoring;
- (void)handleDeviceArrival:(IOHIDDeviceRef)device;
- (void)handleDeviceRemoval:(IOHIDDeviceRef)device;
- (void)handleInputValue:(IOHIDValueRef)value;
- (NSArray<NSString *> *)recentLogLines;
- (NSString *)runtimeStatusSummary;
- (NSString *)displayStatusSummary;
- (NSString *)permissionStatusSummary;
- (NSString *)touchDeviceStatusSummary;
- (NSString *)diagnosticsReport;
- (void)refreshPermissionStatusWithPrompt:(BOOL)prompt;
@end

@interface XeneonAppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) XeneonRuntime *runtime;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *statusMenu;
@property(nonatomic, strong) NSMenuItem *statusItemMenuEntry;
@property(nonatomic, strong) NSMenuItem *displayItem;
@property(nonatomic, strong) NSMenuItem *permissionItem;
@property(nonatomic, strong) NSMenuItem *touchItem;
@property(nonatomic, strong) NSTimer *refreshTimer;
@end

static NSString *StringProperty(IOHIDDeviceRef device, CFStringRef key) {
    CFTypeRef value = IOHIDDeviceGetProperty(device, key);
    return [(__bridge id)value isKindOfClass:[NSString class]] ? (__bridge NSString *)value : nil;
}

static NSNumber *NumberProperty(IOHIDDeviceRef device, CFStringRef key) {
    CFTypeRef value = IOHIDDeviceGetProperty(device, key);
    return [(__bridge id)value isKindOfClass:[NSNumber class]] ? (__bridge NSNumber *)value : nil;
}

static NSString *DeviceSummary(IOHIDDeviceRef device) {
    NSString *productName = StringProperty(device, CFSTR(kIOHIDProductKey));
    NSNumber *vendorID = NumberProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID = NumberProperty(device, CFSTR(kIOHIDProductIDKey));
    NSNumber *usagePage = NumberProperty(device, CFSTR(kIOHIDPrimaryUsagePageKey));
    NSNumber *usage = NumberProperty(device, CFSTR(kIOHIDPrimaryUsageKey));

    if (productName == nil) {
        productName = @"Unknown HID Device";
    }

    return [NSString stringWithFormat:@"product=%@ vendorID=%@ productID=%@ usagePage=%@ usage=%@",
            productName,
            vendorID != nil ? vendorID : @"?",
            productID != nil ? productID : @"?",
            usagePage != nil ? usagePage : @"?",
            usage != nil ? usage : @"?"];
}

static BOOL StringMatchesAnyHint(NSString *value, NSArray<NSString *> *hints) {
    NSString *folded = value.uppercaseString;
    for (NSString *hint in hints) {
        if ([folded containsString:hint.uppercaseString]) {
            return YES;
        }
    }
    return NO;
}

static CGDirectDisplayID DisplayIDForScreen(NSScreen *screen) {
    NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
    return screenNumber.unsignedIntValue;
}

static NSArray<NSString *> *DisplayNameHintsFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_DISPLAY_NAME_HINTS"];
    if (value.length == 0) {
        return @[ @"XENEON", @"EDGE", @"CORSAIR" ];
    }

    NSMutableArray<NSString *> *hints = [NSMutableArray array];
    for (NSString *part in [value componentsSeparatedByString:@","]) {
        NSString *trimmed = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (trimmed.length > 0) {
            [hints addObject:trimmed];
        }
    }

    return hints.count > 0 ? hints : @[ @"XENEON", @"EDGE", @"CORSAIR" ];
}

static CGDirectDisplayID ConfiguredDisplayIDFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_DISPLAY_ID"];
    if (value.length == 0) {
        return kCGNullDirectDisplay;
    }

    unsigned long long displayID = strtoull(value.UTF8String, NULL, 10);
    return (CGDirectDisplayID)displayID;
}

static NSScreen *MainDisplayScreen(void) {
    CGDirectDisplayID mainDisplayID = CGMainDisplayID();
    for (NSScreen *screen in NSScreen.screens) {
        if (DisplayIDForScreen(screen) == mainDisplayID) {
            return screen;
        }
    }

    for (NSScreen *screen in NSScreen.screens) {
        if (NSPointInRect(NSZeroPoint, screen.frame)) {
            return screen;
        }
    }

    return NSScreen.screens.firstObject;
}

static CGPoint QuartzPointForAppKitPoint(CGPoint point) {
    NSScreen *mainScreen = MainDisplayScreen();
    if (mainScreen == nil) {
        return point;
    }

    CGFloat mainDisplayMaxY = NSMaxY(mainScreen.frame);
    return CGPointMake(point.x, mainDisplayMaxY - point.y);
}

static CGPoint QuartzLocalDisplayPointForAppKitPoint(CGPoint point, NSScreen *screen) {
    NSRect frame = screen.frame;
    return CGPointMake(point.x - frame.origin.x, NSMaxY(frame) - point.y);
}

static void PostSyntheticLeftClick(CGPoint point, int clickState) {
    CGPoint quartzPoint = QuartzPointForAppKitPoint(point);
    CGEventRef mouseDown = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, quartzPoint, kCGMouseButtonLeft);
    CGEventRef mouseUp = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, quartzPoint, kCGMouseButtonLeft);

    if (mouseDown != NULL) {
        CGEventSetIntegerValueField(mouseDown, kCGMouseEventClickState, clickState);
        CGEventSetIntegerValueField(mouseDown, kCGEventSourceUserData, kSyntheticEventTag);
        CGEventPost(kCGHIDEventTap, mouseDown);
        CFRelease(mouseDown);
    }

    if (mouseUp != NULL) {
        CGEventSetIntegerValueField(mouseUp, kCGMouseEventClickState, clickState);
        CGEventSetIntegerValueField(mouseUp, kCGEventSourceUserData, kSyntheticEventTag);
        CGEventPost(kCGHIDEventTap, mouseUp);
        CFRelease(mouseUp);
    }
}

static void PostSyntheticLeftSingleClick(CGPoint point) {
    PostSyntheticLeftClick(point, 1);
}

static void PostSyntheticMouseMoved(CGPoint point) {
    CGPoint quartzPoint = QuartzPointForAppKitPoint(point);
    CGEventRef mouseMoved = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, quartzPoint, kCGMouseButtonLeft);
    if (mouseMoved != NULL) {
        CGEventSetIntegerValueField(mouseMoved, kCGEventSourceUserData, kSyntheticEventTag);
        CGEventPost(kCGSessionEventTap, mouseMoved);
        CFRelease(mouseMoved);
    }
}

static BOOL InvertTouchYFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_TOUCH_INVERT_Y"];
    if (value.length == 0) {
        return YES;
    }

    NSString *folded = value.uppercaseString;
    return !([folded isEqualToString:@"0"] || [folded isEqualToString:@"NO"] || [folded isEqualToString:@"FALSE"]);
}

static BOOL RestoreCursorAfterClickFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_RESTORE_CURSOR"];
    if (value.length == 0) {
        return NO;
    }

    NSString *folded = value.uppercaseString;
    return !([folded isEqualToString:@"0"] || [folded isEqualToString:@"NO"] || [folded isEqualToString:@"FALSE"]);
}

static useconds_t RestoreCursorDelayMicrosecondsFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_RESTORE_CURSOR_DELAY_MS"];
    if (value.length == 0) {
        return kDefaultCursorRestoreDelayMicroseconds;
    }

    long parsed = strtol(value.UTF8String, NULL, 10);
    if (parsed < 0) {
        parsed = 0;
    }

    return (useconds_t)parsed * 1000;
}

static useconds_t MicrosecondsFromMillisecondsEnvironment(NSString *key, useconds_t fallback) {
    NSString *value = NSProcessInfo.processInfo.environment[key];
    if (value.length == 0) {
        return fallback;
    }

    long parsed = strtol(value.UTF8String, NULL, 10);
    if (parsed < 0) {
        parsed = 0;
    }
    return (useconds_t)parsed * 1000;
}

static useconds_t SyntheticMouseMoveDelayMicrosecondsFromEnvironment(void) {
    return MicrosecondsFromMillisecondsEnvironment(@"XENEON_MOUSE_MOVE_DELAY_MS",
                                                   kDefaultSyntheticMouseMoveDelayMicroseconds);
}

static useconds_t SyntheticClickDelayMicrosecondsFromEnvironment(void) {
    return MicrosecondsFromMillisecondsEnvironment(@"XENEON_CLICK_DELAY_MS",
                                                   kDefaultSyntheticClickDelayMicroseconds);
}

static useconds_t SyntheticInterClickDelayMicrosecondsFromEnvironment(void) {
    return MicrosecondsFromMillisecondsEnvironment(@"XENEON_INTER_CLICK_DELAY_MS",
                                                   kDefaultSyntheticInterClickDelayMicroseconds);
}

static useconds_t ActivationDelayMicrosecondsFromEnvironment(void) {
    return MicrosecondsFromMillisecondsEnvironment(@"XENEON_ACTIVATION_DELAY_MS",
                                                   kDefaultActivationDelayMicroseconds);
}

static useconds_t PostActivationSettleDelayMicrosecondsFromEnvironment(void) {
    return MicrosecondsFromMillisecondsEnvironment(@"XENEON_POST_ACTIVATION_SETTLE_DELAY_MS",
                                                   kDefaultPostActivationSettleDelayMicroseconds);
}

static BOOL SendFocusCompensationClickFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_FOCUS_COMPENSATION_CLICK"];
    if (value.length == 0) {
        return NO;
    }

    NSString *folded = value.uppercaseString;
    return !([folded isEqualToString:@"0"] || [folded isEqualToString:@"NO"] || [folded isEqualToString:@"FALSE"]);
}

static useconds_t FocusCompensationClickDelayMicrosecondsFromEnvironment(void) {
    return MicrosecondsFromMillisecondsEnvironment(@"XENEON_FOCUS_COMPENSATION_CLICK_DELAY_MS",
                                                   kDefaultFocusCompensationClickDelayMicroseconds);
}

static CFTimeInterval TouchCoordinateFreshnessSecondsFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_TOUCH_COORDINATE_MAX_AGE_MS"];
    if (value.length == 0) {
        return kDefaultTouchCoordinateFreshnessSeconds;
    }

    long parsed = strtol(value.UTF8String, NULL, 10);
    if (parsed < 0) {
        parsed = 0;
    }
    return ((CFTimeInterval)parsed) / 1000.0;
}

static CFTimeInterval NativeMouseSuppressionSecondsFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_SUPPRESS_NATIVE_MOUSE_MS"];
    if (value.length == 0) {
        return kDefaultNativeMouseSuppressionSeconds;
    }

    long parsed = strtol(value.UTF8String, NULL, 10);
    if (parsed < 0) {
        parsed = 0;
    }
    return ((CFTimeInterval)parsed) / 1000.0;
}

static BOOL SendSyntheticMouseMoveFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_SEND_MOUSE_MOVE"];
    if (value.length == 0) {
        return NO;
    }

    NSString *folded = value.uppercaseString;
    return !([folded isEqualToString:@"0"] || [folded isEqualToString:@"NO"] || [folded isEqualToString:@"FALSE"]);
}

static BOOL SeizeTouchDeviceFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_SEIZE_TOUCH_DEVICE"];
    if (value.length == 0) {
        return YES;
    }

    NSString *folded = value.uppercaseString;
    return !([folded isEqualToString:@"0"] || [folded isEqualToString:@"NO"] || [folded isEqualToString:@"FALSE"]);
}

static BOOL ActivateTargetApplicationFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_ACTIVATE_TARGET_APP"];
    if (value.length == 0) {
        return YES;
    }

    NSString *folded = value.uppercaseString;
    return !([folded isEqualToString:@"0"] || [folded isEqualToString:@"NO"] || [folded isEqualToString:@"FALSE"]);
}

static int ClickCountFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_CLICK_COUNT"];
    if (value.length == 0) {
        return 2;
    }

    long parsed = strtol(value.UTF8String, NULL, 10);
    if (parsed < 1) {
        return 1;
    }
    if (parsed > 2) {
        return 2;
    }
    return (int)parsed;
}

static double ClampUnit(double value) {
    if (value < 0.0) {
        return 0.0;
    }
    if (value > 1.0) {
        return 1.0;
    }
    return value;
}

static CGPoint TargetPointForNormalizedTouch(NSRect frame, double normalizedX, double normalizedY, BOOL invertY) {
    double effectiveY = invertY ? (1.0 - normalizedY) : normalizedY;
    return CGPointMake(frame.origin.x + (normalizedX * frame.size.width),
                       frame.origin.y + (effectiveY * frame.size.height));
}

static BOOL PointIsEffectivelyOnTargetDisplay(NSPoint point, NSRect targetFrame, CGFloat tolerance) {
    NSRect expandedFrame = NSInsetRect(targetFrame, -tolerance, -tolerance);
    return NSPointInRect(point, expandedFrame);
}

static CGDirectDisplayID DisplayContainingAppKitPoint(NSPoint point) {
    CGPoint quartzPoint = QuartzPointForAppKitPoint(point);
    CGDirectDisplayID displays[8] = { 0 };
    uint32_t displayCount = 0;
    CGError error = CGGetDisplaysWithPoint(quartzPoint, (uint32_t)(sizeof(displays) / sizeof(displays[0])), displays, &displayCount);
    if (error != kCGErrorSuccess || displayCount == 0) {
        return kCGNullDirectDisplay;
    }
    return displays[0];
}

static BOOL PointShouldBeTreatedAsOnTargetDisplay(NSPoint point,
                                                  NSRect targetFrame,
                                                  CGDirectDisplayID targetDisplayID,
                                                  CGFloat tolerance) {
    CGDirectDisplayID containingDisplayID = DisplayContainingAppKitPoint(point);
    if (containingDisplayID != kCGNullDirectDisplay) {
        return containingDisplayID == targetDisplayID;
    }
    return PointIsEffectivelyOnTargetDisplay(point, targetFrame, tolerance);
}

static BOOL CursorIsNearPoint(NSPoint cursorPoint, CGPoint targetPoint, CGFloat tolerance) {
    return fabs(cursorPoint.x - targetPoint.x) <= tolerance &&
           fabs(cursorPoint.y - targetPoint.y) <= tolerance;
}

static BOOL WarpMouseCursorWithRetry(CGPoint targetPoint, NSRect targetFrame, CGError *lastError, NSPoint *pointerAfterWarp) {
    CGError error = kCGErrorSuccess;
    NSPoint pointer = NSZeroPoint;
    CGPoint quartzTargetPoint = QuartzPointForAppKitPoint(targetPoint);

    for (int attempt = 0; attempt < 3; attempt++) {
        error = CGWarpMouseCursorPosition(quartzTargetPoint);
        pointer = NSEvent.mouseLocation;
        if (NSPointInRect(pointer, targetFrame)) {
            if (lastError != NULL) {
                *lastError = error;
            }
            if (pointerAfterWarp != NULL) {
                *pointerAfterWarp = pointer;
            }
            return YES;
        }
        usleep(1000);
    }

    if (lastError != NULL) {
        *lastError = error;
    }
    if (pointerAfterWarp != NULL) {
        *pointerAfterWarp = pointer;
    }
    return NO;
}

static BOOL ForceCursorToPoint(CGPoint targetPoint,
                               NSScreen *targetScreen,
                               CGDirectDisplayID targetDisplayID,
                               CGError *lastError,
                               NSPoint *pointerAfterMove) {
    CGError error = kCGErrorSuccess;
    NSPoint pointer = NSZeroPoint;
    CGPoint quartzTargetPoint = QuartzPointForAppKitPoint(targetPoint);
    CGPoint displayLocalPoint = QuartzLocalDisplayPointForAppKitPoint(targetPoint, targetScreen);

    for (int attempt = 0; attempt < 4; attempt++) {
        error = CGWarpMouseCursorPosition(quartzTargetPoint);
        CGDisplayMoveCursorToPoint(targetDisplayID, displayLocalPoint);

        CGEventRef moved = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, quartzTargetPoint, kCGMouseButtonLeft);
        if (moved != NULL) {
            CGEventSetIntegerValueField(moved, kCGEventSourceUserData, kSyntheticEventTag);
            CGEventPost(kCGHIDEventTap, moved);
            CFRelease(moved);
        }

        usleep(2000);
        pointer = NSEvent.mouseLocation;
        if (CursorIsNearPoint(pointer, targetPoint, 24.0)) {
            if (lastError != NULL) {
                *lastError = error;
            }
            if (pointerAfterMove != NULL) {
                *pointerAfterMove = pointer;
            }
            return YES;
        }
    }

    if (lastError != NULL) {
        *lastError = error;
    }
    if (pointerAfterMove != NULL) {
        *pointerAfterMove = pointer;
    }
    return NO;
}

static CGPoint AXPointForAppKitPoint(CGPoint point) {
    return QuartzPointForAppKitPoint(point);
}

static pid_t FrontmostWindowOwnerPIDAtPoint(CGPoint point) {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    if (systemWide != NULL) {
        CGPoint axPoint = AXPointForAppKitPoint(point);
        AXUIElementRef element = NULL;
        AXError axError = AXUIElementCopyElementAtPosition(systemWide, axPoint.x, axPoint.y, &element);
        if (axError == kAXErrorSuccess && element != NULL) {
            pid_t pid = -1;
            AXUIElementGetPid(element, &pid);
            CFRelease(element);
            CFRelease(systemWide);
            if (pid > 0) {
                return pid;
            }
        } else if (element != NULL) {
            CFRelease(element);
        }
        NSLog(@"AX hit-test at quartz=(%d, %d) ax=(%d, %d) failed with error=%d.",
              (int)point.x,
              (int)point.y,
              (int)axPoint.x,
              (int)axPoint.y,
              axError);
        CFRelease(systemWide);
    }

    CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    if (windows == NULL) {
        return -1;
    }

    pid_t pid = -1;
    for (NSDictionary *windowInfo in (__bridge NSArray *)windows) {
        NSNumber *layer = windowInfo[(id)kCGWindowLayer];
        NSNumber *ownerPID = windowInfo[(id)kCGWindowOwnerPID];
        NSDictionary *boundsDictionary = windowInfo[(id)kCGWindowBounds];
        NSNumber *alpha = windowInfo[(id)kCGWindowAlpha];

        if (layer == nil || ownerPID == nil || boundsDictionary == nil) {
            continue;
        }
        if (layer.integerValue < 0) {
            continue;
        }
        if (alpha != nil && alpha.doubleValue <= 0.0) {
            continue;
        }

        CGRect bounds = CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDictionary, &bounds)) {
            continue;
        }
        if (CGRectContainsPoint(bounds, point)) {
            pid = (pid_t)ownerPID.intValue;
            break;
        }
    }

    CFRelease(windows);
    return pid;
}

static BOOL TouchCoordinatesAreFresh(CFTimeInterval now,
                                     BOOL hasTouchX,
                                     BOOL hasTouchY,
                                     CFTimeInterval lastTouchXTime,
                                     CFTimeInterval lastTouchYTime,
                                     CFTimeInterval maxAge,
                                     CFTimeInterval *xAgeOut,
                                     CFTimeInterval *yAgeOut) {
    CFTimeInterval xAge = now - lastTouchXTime;
    CFTimeInterval yAge = now - lastTouchYTime;
    if (xAgeOut != NULL) {
        *xAgeOut = xAge;
    }
    if (yAgeOut != NULL) {
        *yAgeOut = yAge;
    }
    return hasTouchX && hasTouchY && xAge <= maxAge && yAge <= maxAge;
}

static int ConfiguredTouchVendorIDFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_TOUCH_VENDOR_ID"];
    if (value.length == 0) {
        return 10176;
    }
    return (int)strtol(value.UTF8String, NULL, 10);
}

static int ConfiguredTouchProductIDFromEnvironment(void) {
    NSString *value = NSProcessInfo.processInfo.environment[@"XENEON_TOUCH_PRODUCT_ID"];
    if (value.length == 0) {
        return 2137;
    }
    return (int)strtol(value.UTF8String, NULL, 10);
}

static void DeviceMatchingCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)result;
    (void)sender;
    XeneonRuntime *runtime = (__bridge XeneonRuntime *)context;
    [runtime handleDeviceArrival:device];
}

static void DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    (void)result;
    (void)sender;
    XeneonRuntime *runtime = (__bridge XeneonRuntime *)context;
    [runtime handleDeviceRemoval:device];
}

static void InputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    (void)result;
    (void)sender;
    XeneonRuntime *runtime = (__bridge XeneonRuntime *)context;
    [runtime handleInputValue:value];
}

static CGEventRef NativeMouseSuppressionCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    (void)proxy;

    XeneonRuntime *runtime = (__bridge XeneonRuntime *)userInfo;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (runtime.eventTap != NULL) {
            CGEventTapEnable(runtime.eventTap, true);
        }
        return event;
    }

    if (CFAbsoluteTimeGetCurrent() >= runtime.suppressNativeMouseUntil) {
        return event;
    }

    if (CGEventGetIntegerValueField(event, kCGEventSourceUserData) == kSyntheticEventTag) {
        return event;
    }

    switch (type) {
        case kCGEventLeftMouseDown:
        case kCGEventLeftMouseUp:
        case kCGEventLeftMouseDragged:
            return NULL;
        default:
            return event;
    }
}

static void DisplayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo) {
    (void)display;
    (void)flags;
    XeneonRuntime *runtime = (__bridge XeneonRuntime *)userInfo;
    [runtime refreshTargetDisplay];
}

@implementation XeneonRuntime

- (instancetype)init {
    self = [super init];
    if (self) {
        _displayNameHints = DisplayNameHintsFromEnvironment();
        _hidProductNameHints = @[ @"XENEON", @"EDGE", @"TOUCH" ];
        _seenDevices = [NSMutableSet set];
        _matchedDevices = [NSMutableSet set];
        _recentLogEntries = [NSMutableArray array];
        _configuredDisplayID = ConfiguredDisplayIDFromEnvironment();
        _configuredVendorID = ConfiguredTouchVendorIDFromEnvironment();
        _configuredProductID = ConfiguredTouchProductIDFromEnvironment();
        _lastWarpTime = 0;
        _lastPermissionWarningTime = 0;
        _invertTouchY = InvertTouchYFromEnvironment();
        _hasTouchX = NO;
        _hasTouchY = NO;
        _normalizedTouchX = 0.5;
        _normalizedTouchY = 0.5;
        _lastTouchXTime = 0;
        _lastTouchYTime = 0;
        _restoreCursorAfterClick = RestoreCursorAfterClickFromEnvironment();
        _restoreCursorDelayMicroseconds = RestoreCursorDelayMicrosecondsFromEnvironment();
        _syntheticMouseMoveDelayMicroseconds = SyntheticMouseMoveDelayMicrosecondsFromEnvironment();
        _syntheticClickDelayMicroseconds = SyntheticClickDelayMicrosecondsFromEnvironment();
        _syntheticInterClickDelayMicroseconds = SyntheticInterClickDelayMicrosecondsFromEnvironment();
        _touchCoordinateFreshnessSeconds = TouchCoordinateFreshnessSecondsFromEnvironment();
        _suppressNativeMouseUntil = 0;
        _nativeMouseSuppressionSeconds = NativeMouseSuppressionSecondsFromEnvironment();
        _takeoverActive = NO;
        _takeoverHasWarped = NO;
        _takeoverPending = NO;
        _takeoverTargetPoint = CGPointZero;
        _takeoverOriginalPointer = NSZeroPoint;
        _seizeTouchDevice = SeizeTouchDeviceFromEnvironment();
        _activateTargetApplication = ActivateTargetApplicationFromEnvironment();
        _activationDelayMicroseconds = ActivationDelayMicrosecondsFromEnvironment();
        _postActivationSettleDelayMicroseconds = PostActivationSettleDelayMicrosecondsFromEnvironment();
        _sendFocusCompensationClick = SendFocusCompensationClickFromEnvironment();
        _focusCompensationClickDelayMicroseconds = FocusCompensationClickDelayMicrosecondsFromEnvironment();
        _sendSyntheticMouseMove = SendSyntheticMouseMoveFromEnvironment();
        _clickCount = ClickCountFromEnvironment();
        _hidManager = NULL;
        _eventTap = NULL;
        _eventTapSource = NULL;
        _targetDisplayID = kCGNullDirectDisplay;
        _accessibilityTrusted = NO;
        _inputMonitoringTrusted = NO;
        _postEventTrusted = NO;
        _nativeMouseSuppressionTapActive = NO;
        _hidManagerAvailable = NO;
        _hidManagerOpenSucceeded = NO;
        _matchedTouchDeviceCount = 0;
    }
    return self;
}

- (void)dealloc {
    if (gActiveRuntime == self) {
        gActiveRuntime = nil;
    }
    if (_eventTapSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _eventTapSource, kCFRunLoopCommonModes);
        CFRelease(_eventTapSource);
    }
    if (_eventTap != NULL) {
        CFMachPortInvalidate(_eventTap);
        CFRelease(_eventTap);
    }
    if (_hidManager != NULL) {
        IOHIDManagerUnscheduleFromRunLoop(_hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDManagerClose(_hidManager, kIOHIDOptionsTypeNone);
        CFRelease(_hidManager);
    }
}

- (void)start {
    gActiveRuntime = self;
    [self printBanner];
    [self logAccessibilityStatusAndPromptIfNeeded];
    [self refreshTargetDisplay];
    [self startNativeMouseSuppressionTap];
    [self startHIDMonitoring];
    CGDisplayRegisterReconfigurationCallback(DisplayReconfigurationCallback, (__bridge void *)self);
}

- (void)run {
    [self start];
    [[NSRunLoop currentRunLoop] run];
}

- (void)notifyStatusChanged {
    [[NSNotificationCenter defaultCenter] postNotificationName:XeneonRuntimeStatusDidChangeNotification object:self];
}

- (void)pruneRecentLogs {
    CFAbsoluteTime cutoff = CFAbsoluteTimeGetCurrent() - kLogRetentionSeconds;
    NSIndexSet *expiredIndexes = [self.recentLogEntries indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
        (void)idx;
        (void)stop;
        NSNumber *timestamp = entry[@"timestamp"];
        return timestamp != nil && timestamp.doubleValue < cutoff;
    }];
    if (expiredIndexes.count > 0) {
        [self.recentLogEntries removeObjectsAtIndexes:expiredIndexes];
    }
}

- (void)recordLogMessage:(NSString *)message {
    if (message.length == 0) {
        return;
    }

    [self.recentLogEntries addObject:@{
        @"timestamp" : @(CFAbsoluteTimeGetCurrent()),
        @"message" : message,
    }];
    [self pruneRecentLogs];
    [[NSNotificationCenter defaultCenter] postNotificationName:XeneonRuntimeLogsDidChangeNotification object:self];
}

- (NSArray<NSString *> *)recentLogLines {
    [self pruneRecentLogs];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSUInteger startIndex = self.recentLogEntries.count > kMaxVisibleLogEntries ? (self.recentLogEntries.count - kMaxVisibleLogEntries) : 0;
    for (NSUInteger index = startIndex; index < self.recentLogEntries.count; index++) {
        NSDictionary *entry = self.recentLogEntries[index];
        NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:[entry[@"timestamp"] doubleValue]];
        NSString *message = entry[@"message"];
        [lines addObject:[NSString stringWithFormat:@"%@ %@", [formatter stringFromDate:date], message]];
    }
    return lines;
}

- (NSString *)runtimeStatusSummary {
    if (!self.accessibilityTrusted) {
        return @"Status: Waiting for Accessibility permission";
    }
    if (!self.inputMonitoringTrusted) {
        return @"Status: Waiting for Input Monitoring permission";
    }
    if (!self.postEventTrusted) {
        return @"Status: Waiting for synthetic event permission";
    }
    if (self.targetScreen == nil) {
        return @"Status: XENEON display not detected";
    }
    if (self.matchedTouchDeviceCount == 0) {
        return @"Status: Waiting for touchscreen device";
    }
    if (!self.nativeMouseSuppressionTapActive) {
        return @"Status: Mouse suppression tap unavailable";
    }
    return @"Status: Ready";
}

- (NSString *)displayStatusSummary {
    if (self.targetScreen == nil) {
        return @"Display: not recognized";
    }
    return [NSString stringWithFormat:@"Display: %@ (connected)", self.targetScreen.localizedName];
}

- (NSString *)permissionStatusSummary {
    return [NSString stringWithFormat:@"Permissions: Accessibility %@, Input Monitoring %@, Event Posting %@",
            self.accessibilityTrusted ? @"yes" : @"no",
            self.inputMonitoringTrusted ? @"yes" : @"no",
            self.postEventTrusted ? @"yes" : @"no"];
}

- (NSString *)touchDeviceStatusSummary {
    if (self.matchedTouchDeviceCount == 0) {
        return @"Touch device: none matched";
    }
    return [NSString stringWithFormat:@"Touch device: %lu matched", (unsigned long)self.matchedTouchDeviceCount];
}

- (NSString *)diagnosticsReport {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSDictionary *infoDictionary = NSBundle.mainBundle.infoDictionary;
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier != nil ? NSBundle.mainBundle.bundleIdentifier : @"<none>";
    NSString *version = infoDictionary[@"CFBundleShortVersionString"] != nil ? infoDictionary[@"CFBundleShortVersionString"] : @"<unknown>";

    [lines addObject:@"XENEON Touch Support Diagnostics"];
    [lines addObject:[NSString stringWithFormat:@"Timestamp: %@", [NSDate date]]];
    [lines addObject:[NSString stringWithFormat:@"Bundle identifier: %@", bundleIdentifier]];
    [lines addObject:[NSString stringWithFormat:@"Version: %@", version]];
    [lines addObject:[self runtimeStatusSummary]];
    [lines addObject:[self displayStatusSummary]];
    [lines addObject:[self permissionStatusSummary]];
    [lines addObject:[self touchDeviceStatusSummary]];
    [lines addObject:[NSString stringWithFormat:@"HID manager available: %@", self.hidManagerAvailable ? @"yes" : @"no"]];
    [lines addObject:[NSString stringWithFormat:@"HID manager open succeeded: %@", self.hidManagerOpenSucceeded ? @"yes" : @"no"]];
    [lines addObject:[NSString stringWithFormat:@"Native mouse suppression tap active: %@", self.nativeMouseSuppressionTapActive ? @"yes" : @"no"]];

    [lines addObject:@"Screens:"];
    for (NSScreen *screen in NSScreen.screens) {
        NSRect frame = screen.frame;
        CGDirectDisplayID displayID = DisplayIDForScreen(screen);
        BOOL isTarget = self.targetScreen != nil && displayID == self.targetDisplayID;
        NSString *screenName = screen.localizedName != nil ? screen.localizedName : @"<unnamed>";
        [lines addObject:[NSString stringWithFormat:@"- %@%@ id=%u frame=x=%d y=%d w=%d h=%d",
                          isTarget ? @"* " : @"",
                          screenName,
                          displayID,
                          (int)frame.origin.x,
                          (int)frame.origin.y,
                          (int)frame.size.width,
                          (int)frame.size.height]];
    }

    [lines addObject:@"Recent logs (last 5 min):"];
    NSArray<NSString *> *recentLogLines = [self recentLogLines];
    if (recentLogLines.count == 0) {
        [lines addObject:@"- <none>"];
    } else {
        for (NSString *line in recentLogLines) {
            [lines addObject:[NSString stringWithFormat:@"- %@", line]];
        }
    }

    return [lines componentsJoinedByString:@"\n"];
}

- (void)startNativeMouseSuppressionTap {
    CGEventMask mask =
        CGEventMaskBit(kCGEventMouseMoved) |
        CGEventMaskBit(kCGEventLeftMouseDown) |
        CGEventMaskBit(kCGEventLeftMouseUp) |
        CGEventMaskBit(kCGEventLeftMouseDragged);

    self.eventTap = CGEventTapCreate(kCGHIDEventTap,
                                     kCGHeadInsertEventTap,
                                     kCGEventTapOptionDefault,
                                     mask,
                                     NativeMouseSuppressionCallback,
                                     (__bridge void *)self);
    if (self.eventTap == NULL) {
        self.nativeMouseSuppressionTapActive = NO;
        NSLog(@"Failed to create HID-level native mouse suppression event tap.");
        [self notifyStatusChanged];
        return;
    }

    self.eventTapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, self.eventTap, 0);
    if (self.eventTapSource == NULL) {
        self.nativeMouseSuppressionTapActive = NO;
        NSLog(@"Failed to create run-loop source for native mouse suppression event tap.");
        CFMachPortInvalidate(self.eventTap);
        CFRelease(self.eventTap);
        self.eventTap = NULL;
        [self notifyStatusChanged];
        return;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(), self.eventTapSource, kCFRunLoopCommonModes);
    CGEventTapEnable(self.eventTap, true);
    self.nativeMouseSuppressionTapActive = YES;
    NSLog(@"HID-level native mouse suppression tap active.");
    [self notifyStatusChanged];
}

- (void)printBanner {
    NSLog(@"xeneon-touch-support prototype");
    NSLog(@"Monitoring HID activity and moving the pointer onto the XENEON display when needed.");
    NSLog(@"Synthetic click count: %d", self.clickCount);
    NSLog(@"Mouse move delay: %u ms", self.syntheticMouseMoveDelayMicroseconds / 1000);
    NSLog(@"Click delay: %u ms", self.syntheticClickDelayMicroseconds / 1000);
    NSLog(@"Inter-click delay: %u ms", self.syntheticInterClickDelayMicroseconds / 1000);
    NSLog(@"Touch coordinate max age: %.0f ms", self.touchCoordinateFreshnessSeconds * 1000.0);
    NSLog(@"Suppress native mouse window: %.0f ms", self.nativeMouseSuppressionSeconds * 1000.0);
    NSLog(@"Seize touch device: %@", self.seizeTouchDevice ? @"YES" : @"NO");
    NSLog(@"Activate target app: %@", self.activateTargetApplication ? @"YES" : @"NO");
    NSLog(@"Activation delay: %u ms", self.activationDelayMicroseconds / 1000);
    NSLog(@"Post-activation settle delay: %u ms", self.postActivationSettleDelayMicroseconds / 1000);
    NSLog(@"Focus compensation click: %@", self.sendFocusCompensationClick ? @"YES" : @"NO");
    NSLog(@"Focus compensation delay: %u ms", self.focusCompensationClickDelayMicroseconds / 1000);
    NSLog(@"Send synthetic mouse move: %@", self.sendSyntheticMouseMove ? @"YES" : @"NO");
    NSLog(@"Restore cursor after click: %@", self.restoreCursorAfterClick ? @"YES" : @"NO");
    NSLog(@"Restore cursor delay: %u ms", self.restoreCursorDelayMicroseconds / 1000);
}

- (void)refreshPermissionStatusWithPrompt:(BOOL)prompt {
    BOOL previousAccessibilityTrusted = self.accessibilityTrusted;
    BOOL previousInputMonitoringTrusted = self.inputMonitoringTrusted;
    BOOL previousPostEventTrusted = self.postEventTrusted;

    if (prompt) {
        NSDictionary *options = @{ (__bridge NSString *)kAXTrustedCheckOptionPrompt : @YES };
        self.accessibilityTrusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    } else {
        self.accessibilityTrusted = AXIsProcessTrusted();
    }
    self.inputMonitoringTrusted = CGPreflightListenEventAccess();
    self.postEventTrusted = CGPreflightPostEventAccess();

    if (prompt) {
        NSLog(@"Accessibility trusted: %@", self.accessibilityTrusted ? @"YES" : @"NO");
        NSLog(@"Input Monitoring trusted: %@", self.inputMonitoringTrusted ? @"YES" : @"NO");
        NSLog(@"Synthetic event posting trusted: %@", self.postEventTrusted ? @"YES" : @"NO");
        if (!self.accessibilityTrusted) {
            NSLog(@"Grant Accessibility and Input Monitoring to the app that launched this process, and if needed to this binary as well.");
            NSLog(@"If you launched the raw binary from Terminal, grant permissions to Terminal as well.");
        }
        if (!self.inputMonitoringTrusted) {
            BOOL requestIssued = CGRequestListenEventAccess();
            NSLog(@"Requested Input Monitoring access: %@", requestIssued ? @"YES" : @"NO");
        }
        if (!self.postEventTrusted) {
            BOOL requestIssued = CGRequestPostEventAccess();
            NSLog(@"Requested synthetic event posting access: %@", requestIssued ? @"YES" : @"NO");
        }
    } else if (previousAccessibilityTrusted != self.accessibilityTrusted ||
               previousInputMonitoringTrusted != self.inputMonitoringTrusted ||
               previousPostEventTrusted != self.postEventTrusted) {
        NSLog(@"Permission state changed. Accessibility=%@ InputMonitoring=%@ EventPosting=%@",
              self.accessibilityTrusted ? @"YES" : @"NO",
              self.inputMonitoringTrusted ? @"YES" : @"NO",
              self.postEventTrusted ? @"YES" : @"NO");
    }

    [self notifyStatusChanged];
}

- (void)logAccessibilityStatusAndPromptIfNeeded {
    [self refreshPermissionStatusWithPrompt:YES];
}

- (void)refreshTargetDisplay {
    NSArray<NSScreen *> *screens = NSScreen.screens;
    NSMutableArray<NSScreen *> *externalScreens = [NSMutableArray array];
    NSLog(@"Discovered %lu screen(s):", (unsigned long)screens.count);

    self.targetScreen = nil;
    self.targetDisplayID = kCGNullDirectDisplay;

    for (NSScreen *screen in screens) {
        NSString *screenName = screen.localizedName != nil ? screen.localizedName : @"";
        CGDirectDisplayID displayID = DisplayIDForScreen(screen);
        BOOL isBuiltin = CGDisplayIsBuiltin(displayID);
        BOOL matchesConfiguredID = self.configuredDisplayID != kCGNullDirectDisplay && displayID == self.configuredDisplayID;
        BOOL matchesName = StringMatchesAnyHint(screenName, self.displayNameHints);
        BOOL isMatch = matchesConfiguredID || matchesName;
        const char *marker = isMatch ? "*" : "-";
        NSRect frame = screen.frame;
        NSLog(@"  %s %@ id=%u type=%s frame=x=%d y=%d w=%d h=%d",
              marker,
              screenName,
              displayID,
              isBuiltin ? "builtin" : "external",
              (int)frame.origin.x,
              (int)frame.origin.y,
              (int)frame.size.width,
              (int)frame.size.height);

        if (!isBuiltin) {
            [externalScreens addObject:screen];
        }

        if (isMatch && self.targetScreen == nil) {
            self.targetScreen = screen;
            self.targetDisplayID = displayID;
        }
    }

    if (self.targetScreen == nil && externalScreens.count == 1) {
        NSScreen *fallbackScreen = externalScreens.firstObject;
        self.targetScreen = fallbackScreen;
        self.targetDisplayID = DisplayIDForScreen(fallbackScreen);
        NSLog(@"No display matched by name. Falling back to the only external display: %@ id=%u",
              fallbackScreen.localizedName,
              self.targetDisplayID);
    }

    if (self.targetScreen != nil) {
        NSLog(@"Target display matched: %@ id=%u", self.targetScreen.localizedName, self.targetDisplayID);
    } else {
        if (self.configuredDisplayID != kCGNullDirectDisplay) {
            NSLog(@"Target display not found. XENEON_DISPLAY_ID=%u did not match any connected screen.", self.configuredDisplayID);
        } else {
            NSLog(@"Target display not found. Set XENEON_DISPLAY_NAME_HINTS or XENEON_DISPLAY_ID if the XENEON uses an unexpected screen name. Current hints: %@",
                  [self.displayNameHints componentsJoinedByString:@", "]);
        }
    }
    [self notifyStatusChanged];
}

- (void)startHIDMonitoring {
    self.hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (self.hidManager == NULL) {
        self.hidManagerAvailable = NO;
        self.hidManagerOpenSucceeded = NO;
        NSLog(@"Failed to create IOHIDManager.");
        [self notifyStatusChanged];
        return;
    }
    self.hidManagerAvailable = YES;

    NSArray *matching = @[
        @{ @kIOHIDPrimaryUsagePageKey : @(kHIDPage_Digitizer) },
        @{ @kIOHIDPrimaryUsagePageKey : @(kHIDPage_GenericDesktop) },
    ];

    IOHIDManagerSetDeviceMatchingMultiple(self.hidManager, (__bridge CFArrayRef)matching);
    IOHIDManagerRegisterDeviceMatchingCallback(self.hidManager, DeviceMatchingCallback, (__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(self.hidManager, DeviceRemovalCallback, (__bridge void *)self);
    IOHIDManagerScheduleWithRunLoop(self.hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);

    IOReturn openResult = IOHIDManagerOpen(self.hidManager, kIOHIDOptionsTypeNone);
    if (openResult == kIOReturnSuccess) {
        self.hidManagerOpenSucceeded = YES;
        NSLog(@"HID manager opened successfully.");
    } else if (openResult == kIOReturnExclusiveAccess) {
        self.hidManagerOpenSucceeded = NO;
        NSLog(@"HID manager open returned kIOReturnExclusiveAccess (%d). Continuing with per-device opens.", openResult);
    } else {
        self.hidManagerOpenSucceeded = NO;
        NSLog(@"Failed to open HID manager: %d. Continuing with per-device opens.", openResult);
    }
    [self notifyStatusChanged];

    CFSetRef deviceSet = IOHIDManagerCopyDevices(self.hidManager);
    if (deviceSet == NULL) {
        NSLog(@"No HID devices found by IOHIDManager.");
        return;
    }

    CFIndex count = CFSetGetCount(deviceSet);
    const void **values = calloc((size_t)count, sizeof(void *));
    CFSetGetValues(deviceSet, values);
    NSLog(@"Inspecting %ld HID device(s) for possible touchscreen matches.", (long)count);

    for (CFIndex index = 0; index < count; index++) {
        IOHIDDeviceRef device = (IOHIDDeviceRef)values[index];
        [self handleDeviceArrival:device];
    }

    free(values);
    CFRelease(deviceSet);
}

- (void)handleDeviceArrival:(IOHIDDeviceRef)device {
    NSValue *deviceKey = [NSValue valueWithPointer:device];
    if ([self.seenDevices containsObject:deviceKey]) {
        return;
    }
    [self.seenDevices addObject:deviceKey];

    NSString *summary = DeviceSummary(device);
    NSString *productName = StringProperty(device, CFSTR(kIOHIDProductKey));
    NSNumber *vendorID = NumberProperty(device, CFSTR(kIOHIDVendorIDKey));
    NSNumber *productID = NumberProperty(device, CFSTR(kIOHIDProductIDKey));
    BOOL matchesConfiguredIDs = vendorID != nil &&
        productID != nil &&
        vendorID.intValue == self.configuredVendorID &&
        productID.intValue == self.configuredProductID;
    BOOL matchesHints = StringMatchesAnyHint(productName, self.hidProductNameHints);
    BOOL isMatch = matchesConfiguredIDs || matchesHints;

    if (productName == nil) {
        productName = @"Unknown HID Device";
    }

    NSLog(@"  %s HID %@", isMatch ? "*" : "-", summary);
    if (!isMatch) {
        return;
    }
    [self.matchedDevices addObject:deviceKey];
    self.matchedTouchDeviceCount = self.matchedDevices.count;
    [self notifyStatusChanged];

    IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    IOHIDDeviceRegisterInputValueCallback(device, InputValueCallback, (__bridge void *)self);

    IOOptionBits openOptions = self.seizeTouchDevice ? kIOHIDOptionsTypeSeizeDevice : kIOHIDOptionsTypeNone;
    IOReturn openResult = IOHIDDeviceOpen(device, openOptions);
    if (openResult == kIOReturnSuccess) {
        NSLog(@"    Registered input callback for matched HID device using options=0x%x.", openOptions);
    } else if (self.seizeTouchDevice) {
        NSLog(@"    Failed to open matched HID device with seize option: %d. Retrying without seizing.", openResult);
        openResult = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
        if (openResult == kIOReturnSuccess) {
            NSLog(@"    Registered input callback for matched HID device without seize.");
        } else {
            NSLog(@"    Failed to open matched HID device without seize as well: %d", openResult);
        }
    } else {
        NSLog(@"    Failed to open matched HID device: %d", openResult);
    }
}

- (void)handleDeviceRemoval:(IOHIDDeviceRef)device {
    NSValue *deviceKey = [NSValue valueWithPointer:device];
    [self.seenDevices removeObject:deviceKey];
    [self.matchedDevices removeObject:deviceKey];
    self.matchedTouchDeviceCount = self.matchedDevices.count;
    NSLog(@"Device removed: %@", DeviceSummary(device));
    [self notifyStatusChanged];
}

- (void)handleInputValue:(IOHIDValueRef)value {
    if (self.targetScreen == nil || self.targetDisplayID == kCGNullDirectDisplay) {
        NSLog(@"Input received from HID device, but no target display is currently matched.");
        return;
    }

    IOHIDElementRef element = IOHIDValueGetElement(value);
    IOHIDDeviceRef device = IOHIDElementGetDevice(element);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    CFIndex integerValue = IOHIDValueGetIntegerValue(value);
    NSString *productName = StringProperty(device, CFSTR(kIOHIDProductKey));
    NSPoint pointer = NSEvent.mouseLocation;
    NSPoint originalPointer = pointer;
    BOOL pointerIsOnTarget = PointShouldBeTreatedAsOnTargetDisplay(pointer,
                                                                   self.targetScreen.frame,
                                                                   self.targetDisplayID,
                                                                   kTargetDisplayOwnershipTolerance);
    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (productName == nil) {
        productName = @"Unknown HID Device";
    }

    NSLog(@"Input from %@ usagePage=%u usage=%u pointer=(%d, %d)",
          productName,
          usagePage,
          usage,
          (int)pointer.x,
          (int)pointer.y);

    BOOL isPrimaryPress = usagePage == kHIDPage_Button && usage == 1 && integerValue != 0;
    BOOL isPrimaryRelease = usagePage == kHIDPage_Button && usage == 1 && integerValue == 0;
    BOOL shouldOwnThisTouch = !pointerIsOnTarget;
    BOOL isTouchActivitySignal =
        (usagePage == kHIDPage_GenericDesktop && (usage == 56 || usage == kHIDUsage_GD_X || usage == kHIDUsage_GD_Y)) ||
        usagePage == kHIDPage_Button;

    if (usagePage == kHIDPage_GenericDesktop && (usage == kHIDUsage_GD_X || usage == kHIDUsage_GD_Y)) {
        CFIndex logicalMin = IOHIDElementGetLogicalMin(element);
        CFIndex logicalMax = IOHIDElementGetLogicalMax(element);
        if (logicalMax > logicalMin) {
            double normalized = ClampUnit((double)(integerValue - logicalMin) / (double)(logicalMax - logicalMin));
            if (usage == kHIDUsage_GD_X) {
                self.normalizedTouchX = normalized;
                self.hasTouchX = YES;
                self.lastTouchXTime = now;
            } else {
                self.normalizedTouchY = normalized;
                self.hasTouchY = YES;
                self.lastTouchYTime = now;
            }
            NSLog(@"Tracked touch %@ raw=%ld logicalMin=%ld logicalMax=%ld normalized=%.4f",
                  usage == kHIDUsage_GD_X ? @"X" : @"Y",
                  (long)integerValue,
                  (long)logicalMin,
                  (long)logicalMax,
                  normalized);
        }
    }

    if (self.takeoverActive && now > self.suppressNativeMouseUntil) {
        NSLog(@"Resetting stale takeover state after native mouse suppression window elapsed.");
        self.takeoverActive = NO;
        self.takeoverHasWarped = NO;
        self.takeoverPending = NO;
        self.suppressNativeMouseUntil = 0;
    }

    if (!self.takeoverActive && !self.takeoverPending && shouldOwnThisTouch && isTouchActivitySignal) {
        BOOL suppressionWasInactive = now >= self.suppressNativeMouseUntil;
        self.suppressNativeMouseUntil = now + self.nativeMouseSuppressionSeconds;
        if (suppressionWasInactive) {
            NSLog(@"Pre-armed native mouse suppression on off-screen touch activity.");
        }
    }

    if (self.takeoverActive) {
        self.suppressNativeMouseUntil = now + self.nativeMouseSuppressionSeconds;
        if (self.hasTouchX && self.hasTouchY) {
            self.takeoverTargetPoint = TargetPointForNormalizedTouch(self.targetScreen.frame,
                                                                    self.normalizedTouchX,
                                                                    self.normalizedTouchY,
                                                                    self.invertTouchY);
        }
    }

    CFTimeInterval xAge = 0;
    CFTimeInterval yAge = 0;
    BOOL touchCoordinatesFresh = TouchCoordinatesAreFresh(now,
                                                          self.hasTouchX,
                                                          self.hasTouchY,
                                                          self.lastTouchXTime,
                                                          self.lastTouchYTime,
                                                          self.touchCoordinateFreshnessSeconds,
                                                          &xAge,
                                                          &yAge);

    if (!isPrimaryPress && !isPrimaryRelease && !self.takeoverActive && !self.takeoverPending) {
        return;
    }
    if (isPrimaryPress) {
        self.takeoverActive = NO;
        self.takeoverHasWarped = NO;
        self.takeoverPending = NO;

        if ((now - self.lastWarpTime) < kWarpCooldownSeconds) {
            NSLog(@"Warp cooldown active.");
            return;
        }

        if (!shouldOwnThisTouch) {
            NSLog(@"Pointer already on target display and native handling is allowed.");
            return;
        }

        self.takeoverOriginalPointer = originalPointer;
        self.suppressNativeMouseUntil = now + self.nativeMouseSuppressionSeconds;

        if (!(self.hasTouchX && self.hasTouchY)) {
            self.takeoverPending = YES;
            NSLog(@"Primary touch press arrived before usable X/Y coordinates were captured. Waiting to arm takeover.");
            return;
        }

        if (!touchCoordinatesFresh) {
            self.takeoverPending = YES;
            NSLog(@"Primary touch press arrived with stale coordinates. Waiting to arm takeover. xAge=%.0f ms yAge=%.0f ms maxAge=%.0f ms",
                  xAge * 1000.0,
                  yAge * 1000.0,
                  self.touchCoordinateFreshnessSeconds * 1000.0);
            return;
        }

        CGPoint pressTargetPoint = TargetPointForNormalizedTouch(self.targetScreen.frame,
                                                                 self.normalizedTouchX,
                                                                 self.normalizedTouchY,
                                                                 self.invertTouchY);
        self.takeoverTargetPoint = pressTargetPoint;
        self.takeoverActive = YES;

        NSLog(@"Arming off-screen takeover for touch point (%d, %d) on %@ using normalized=(%.4f, %.4f) invertY=%@",
              (int)pressTargetPoint.x,
              (int)pressTargetPoint.y,
              self.targetScreen.localizedName,
              self.normalizedTouchX,
              self.normalizedTouchY,
              self.invertTouchY ? @"YES" : @"NO");

        CGError pressWarpError = kCGErrorSuccess;
        NSPoint pressPointerAfterWarp = NSZeroPoint;
        BOOL pressWarpSucceeded = ForceCursorToPoint(pressTargetPoint,
                                                     self.targetScreen,
                                                     self.targetDisplayID,
                                                     &pressWarpError,
                                                     &pressPointerAfterWarp);
        BOOL pressPointerOnTargetDisplay = PointShouldBeTreatedAsOnTargetDisplay(pressPointerAfterWarp,
                                                                                 self.targetScreen.frame,
                                                                                 self.targetDisplayID,
                                                                                 kTargetDisplayOwnershipTolerance);
        self.takeoverHasWarped = pressWarpSucceeded || pressPointerOnTargetDisplay;
        if (self.takeoverHasWarped) {
            self.lastWarpTime = now;
            NSLog(@"Takeover armed on touch press. pointerAfterWarp=(%d, %d) exact=%@.",
                  (int)pressPointerAfterWarp.x,
                  (int)pressPointerAfterWarp.y,
                  pressWarpSucceeded ? @"YES" : @"NO");
        } else {
            NSLog(@"Initial takeover warp did not settle on touch press. result=%d pointerAfterWarp=(%d, %d). Release-time retry will still run.",
                  pressWarpError,
                  (int)pressPointerAfterWarp.x,
                  (int)pressPointerAfterWarp.y);
        }

        if (self.activateTargetApplication) {
            pid_t targetPID = FrontmostWindowOwnerPIDAtPoint(pressTargetPoint);
            if (targetPID > 0) {
                NSRunningApplication *targetApp = [NSRunningApplication runningApplicationWithProcessIdentifier:targetPID];
                if (targetApp != nil) {
                    BOOL activated = [targetApp activateWithOptions:0];
                    NSLog(@"Activated target application pid=%d result=%@.", targetPID, activated ? @"YES" : @"NO");
                    if (self.activationDelayMicroseconds > 0) {
                        usleep(self.activationDelayMicroseconds);
                    }
                }
            }
        }

        PostSyntheticMouseMoved(pressTargetPoint);
        NSLog(@"Posted synthetic mouse move at armed takeover point (%d, %d).",
              (int)pressTargetPoint.x,
              (int)pressTargetPoint.y);
        return;
    }

    if (self.takeoverPending && !self.takeoverActive && touchCoordinatesFresh) {
        CGPoint pendingTargetPoint = TargetPointForNormalizedTouch(self.targetScreen.frame,
                                                                   self.normalizedTouchX,
                                                                   self.normalizedTouchY,
                                                                   self.invertTouchY);
        self.takeoverTargetPoint = pendingTargetPoint;
        self.takeoverActive = YES;
        self.takeoverPending = NO;

        NSLog(@"Deferred takeover became ready. Attempting pointer warp to touch point (%d, %d) on %@ using normalized=(%.4f, %.4f) invertY=%@",
              (int)pendingTargetPoint.x,
              (int)pendingTargetPoint.y,
              self.targetScreen.localizedName,
              self.normalizedTouchX,
              self.normalizedTouchY,
              self.invertTouchY ? @"YES" : @"NO");
    }

    if (self.takeoverActive && !self.takeoverHasWarped && touchCoordinatesFresh) {
        CGError deferredWarpError = kCGErrorSuccess;
        NSPoint deferredPointerAfterWarp = NSZeroPoint;
        BOOL deferredWarpSucceeded = WarpMouseCursorWithRetry(self.takeoverTargetPoint,
                                                              self.targetScreen.frame,
                                                              &deferredWarpError,
                                                              &deferredPointerAfterWarp);
        if (deferredWarpSucceeded) {
            self.takeoverHasWarped = YES;
            self.lastWarpTime = now;
            NSLog(@"Deferred takeover warp succeeded at (%d, %d).",
                  (int)self.takeoverTargetPoint.x,
                  (int)self.takeoverTargetPoint.y);
        } else {
            NSLog(@"Deferred takeover warp failed. result=%d pointerAfterWarp=(%d, %d).",
                  deferredWarpError,
                  (int)deferredPointerAfterWarp.x,
                  (int)deferredPointerAfterWarp.y);
        }
    }

    if (isPrimaryRelease && self.takeoverActive) {
        CGPoint releasePoint = self.takeoverTargetPoint;
        NSLog(@"Touch release received. Finalizing synthetic click at (%d, %d).",
              (int)releasePoint.x,
              (int)releasePoint.y);

        CGError releaseWarpError = kCGErrorSuccess;
        NSPoint pointerBeforeClick = NSZeroPoint;
        ForceCursorToPoint(releasePoint,
                           self.targetScreen,
                           self.targetDisplayID,
                           &releaseWarpError,
                           &pointerBeforeClick);
        NSLog(@"Release cursor-settle result=%d pointerBeforeClick=(%d, %d).",
              releaseWarpError,
              (int)pointerBeforeClick.x,
              (int)pointerBeforeClick.y);

        BOOL pointerOnTargetDisplayAfterReleaseSettle = PointShouldBeTreatedAsOnTargetDisplay(pointerBeforeClick,
                                                                                              self.targetScreen.frame,
                                                                                              self.targetDisplayID,
                                                                                              kTargetDisplayOwnershipTolerance);
        if (!pointerOnTargetDisplayAfterReleaseSettle) {
            NSLog(@"Release cursor-settle did not move the pointer onto the target display. Synthetic click is skipped.");
            self.takeoverActive = NO;
            self.takeoverHasWarped = NO;
            self.takeoverPending = NO;
            self.suppressNativeMouseUntil = 0;
            return;
        }

        PostSyntheticMouseMoved(releasePoint);
        NSLog(@"Posted synthetic mouse move at release point (%d, %d).",
              (int)releasePoint.x,
              (int)releasePoint.y);
        if (self.postActivationSettleDelayMicroseconds > 0) {
            usleep(self.postActivationSettleDelayMicroseconds);
        }

        if (self.sendSyntheticMouseMove) {
            if (self.syntheticMouseMoveDelayMicroseconds > 0) {
                usleep(self.syntheticMouseMoveDelayMicroseconds);
            }
            PostSyntheticMouseMoved(releasePoint);
            NSLog(@"Posted additional synthetic mouse move at release point (%d, %d).",
                  (int)releasePoint.x,
                  (int)releasePoint.y);
        }

        if (self.syntheticClickDelayMicroseconds > 0) {
            usleep(self.syntheticClickDelayMicroseconds);
        }

        PostSyntheticLeftSingleClick(releasePoint);
        if (self.clickCount >= 2) {
            if (self.syntheticInterClickDelayMicroseconds > 0) {
                usleep(self.syntheticInterClickDelayMicroseconds);
            }
            PostSyntheticLeftSingleClick(releasePoint);
        }
        NSLog(@"Posted %d synthetic single click%@ on touch release at (%d, %d).",
              self.clickCount,
              self.clickCount == 1 ? @"" : @"s",
              (int)releasePoint.x,
              (int)releasePoint.y);

        if (self.restoreCursorAfterClick) {
            usleep(self.restoreCursorDelayMicroseconds);
            CGError restoreError = CGWarpMouseCursorPosition(QuartzPointForAppKitPoint(self.takeoverOriginalPointer));
            NSLog(@"Restored cursor to (%d, %d), result=%d.",
                  (int)self.takeoverOriginalPointer.x,
                  (int)self.takeoverOriginalPointer.y,
                  restoreError);
        }

        self.takeoverActive = NO;
        self.takeoverHasWarped = NO;
        self.takeoverPending = NO;
        self.suppressNativeMouseUntil = 0;
        return;
    }

    if (isPrimaryRelease && self.takeoverPending) {
        NSLog(@"Touch release received before usable X/Y coordinates were available. Cancelling pending takeover.");
        self.takeoverPending = NO;
        self.suppressNativeMouseUntil = 0;
        return;
    }

    if (self.takeoverActive) {
        if (!isPrimaryRelease) {
            NSLog(@"Touch session already active.");
        }
        return;
    }
}

@end

@implementation XeneonAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;

    self.runtime = [[XeneonRuntime alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateStatusMenu)
                                                 name:XeneonRuntimeStatusDidChangeNotification
                                               object:self.runtime];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateStatusMenu)
                                                 name:XeneonRuntimeLogsDidChangeNotification
                                               object:self.runtime];

    self.statusMenu = [[NSMenu alloc] initWithTitle:@"XENEON Touch Support"];

    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"XENEON Touch Support"
                                                       action:nil
                                                keyEquivalent:@""];
    titleItem.enabled = NO;
    [self.statusMenu addItem:titleItem];

    self.statusItemMenuEntry = [[NSMenuItem alloc] initWithTitle:@"Status: Starting up"
                                                          action:nil
                                                   keyEquivalent:@""];
    self.statusItemMenuEntry.enabled = NO;
    [self.statusMenu addItem:self.statusItemMenuEntry];

    self.displayItem = [[NSMenuItem alloc] initWithTitle:@"Display: checking..."
                                                  action:nil
                                           keyEquivalent:@""];
    self.displayItem.enabled = NO;
    [self.statusMenu addItem:self.displayItem];

    self.permissionItem = [[NSMenuItem alloc] initWithTitle:@"Permissions: checking..."
                                                     action:nil
                                              keyEquivalent:@""];
    self.permissionItem.enabled = NO;
    [self.statusMenu addItem:self.permissionItem];

    self.touchItem = [[NSMenuItem alloc] initWithTitle:@"Touch device: checking..."
                                                action:nil
                                         keyEquivalent:@""];
    self.touchItem.enabled = NO;
    [self.statusMenu addItem:self.touchItem];

    NSMenuItem *refreshCoordinatesItem = [[NSMenuItem alloc] initWithTitle:@"Update Coordinates"
                                                                    action:@selector(refreshDisplayCoordinates:)
                                                             keyEquivalent:@""];
    refreshCoordinatesItem.target = self;
    [self.statusMenu addItem:refreshCoordinatesItem];

    NSMenuItem *copyDiagnosticsItem = [[NSMenuItem alloc] initWithTitle:@"Copy Diagnostics"
                                                                 action:@selector(copyDiagnostics:)
                                                          keyEquivalent:@""];
    copyDiagnosticsItem.target = self;
    [self.statusMenu addItem:copyDiagnosticsItem];

    NSMenuItem *infoItem = [[NSMenuItem alloc] initWithTitle:@"Info"
                                                      action:@selector(showInfo:)
                                               keyEquivalent:@""];
    infoItem.target = self;
    [self.statusMenu addItem:infoItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit"
                                                      action:@selector(quit:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [self.statusMenu addItem:quitItem];

    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    if (self.statusItem.button != nil) {
        self.statusItem.button.title = @"XE";
        self.statusItem.button.toolTip = @"XENEON Touch Support";
    }
    self.statusItem.menu = self.statusMenu;

    [self.runtime start];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:self
                                                       selector:@selector(refreshRuntimeState)
                                                       userInfo:nil
                                                        repeats:YES];
    [self updateStatusMenu];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return NO;
}

- (void)updateStatusMenu {
    self.statusItemMenuEntry.title = [self.runtime runtimeStatusSummary];
    self.displayItem.title = [self.runtime displayStatusSummary];
    self.permissionItem.title = [self.runtime permissionStatusSummary];
    self.touchItem.title = [self.runtime touchDeviceStatusSummary];

    if (self.statusItem.button != nil) {
        self.statusItem.button.toolTip = [NSString stringWithFormat:@"%@\n%@\n%@",
                                          self.statusItemMenuEntry.title,
                                          self.displayItem.title,
                                          self.permissionItem.title];
    }
}

- (void)refreshRuntimeState {
    [self.runtime refreshPermissionStatusWithPrompt:NO];
    [self updateStatusMenu];
}

- (void)copyDiagnostics:(id)sender {
    (void)sender;
    NSString *report = [self.runtime diagnosticsReport];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard setString:report forType:NSPasteboardTypeString];
    NSLog(@"Copied diagnostics report to the clipboard.");
    [self updateStatusMenu];
}

- (void)refreshDisplayCoordinates:(id)sender {
    (void)sender;
    NSLog(@"Manual display coordinate refresh requested from menu.");
    [self.runtime refreshTargetDisplay];
    [self updateStatusMenu];
}

- (void)showInfo:(id)sender {
    (void)sender;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"XENEON Touch Support";
    alert.informativeText =
        @"Author: Matthias Reinholz\n"
        @"License: GNU General Public License v3.0\n"
        @"Repository: github.com/MatthiasReinholz/macos-touch-support-for-xeneon-edge";
    [alert addButtonWithTitle:@"Open GitHub"];
    [alert addButtonWithTitle:@"OK"];

    NSModalResponse response = [alert runModal];
    if (response == NSAlertFirstButtonReturn) {
        NSURL *url = [NSURL URLWithString:@"https://github.com/MatthiasReinholz/macos-touch-support-for-xeneon-edge"];
        if (url != nil) {
            [NSWorkspace.sharedWorkspace openURL:url];
        }
    }
}

- (void)quit:(id)sender {
    (void)sender;
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];

        XeneonAppDelegate *delegate = [[XeneonAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
