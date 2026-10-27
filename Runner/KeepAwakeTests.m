#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/message.h>
#import <dlfcn.h>
#import "Lease.h"

static void Report(NSString *state) {
    fprintf(stdout, "CHARGEUNLOCK:%s\n", state.UTF8String);
    fflush(stdout);
}

@interface KeepAwakeTests : XCTestCase
@end

@implementation KeepAwakeTests
- (void)testKeepAwake {
    self.continueAfterFailure = NO;
    NSString *session = NSProcessInfo.processInfo.environment[@"CHARGEUNLOCK_SESSION"];
    XCTAssertNotNil([[NSUUID alloc] initWithUUIDString:session]);
    if (!session) return;

    // These developer-only APIs are unavailable to ordinary App Store apps.
    void *sbs = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
    mach_port_t (*serverPort)(void) = sbs ? dlsym(sbs, "SBSSpringBoardServerPort") : NULL;
    void (*lockStatus)(mach_port_t, BOOL *, BOOL *) = sbs ? dlsym(sbs, "SBGetScreenLockStatus") : NULL;
    Class eventClass = NSClassFromString(@"XCDeviceEvent");
    SEL make = NSSelectorFromString(@"deviceEventWithPage:usage:duration:");
    SEL perform = NSSelectorFromString(@"performDeviceEvent:error:");
    if (!serverPort || !lockStatus || ![eventClass respondsToSelector:make] ||
        ![XCUIDevice.sharedDevice respondsToSelector:perform]) {
        Report(@"unsupported");
        XCTFail(@"Required device automation APIs are unavailable");
        if (sbs) dlclose(sbs);
        return;
    }

    __block double heartbeat = 0;
    int token = 0;
    NSString *name = [@"local.chargeunlock.heartbeat." stringByAppendingString:session];
    uint32_t result = notify_register_dispatch(name.UTF8String, &token, dispatch_get_main_queue(), ^(int unused) {
        heartbeat = NSProcessInfo.processInfo.systemUptime;
    });
    XCTAssertEqual(result, NOTIFY_STATUS_OK);
    if (result != NOTIFY_STATUS_OK) return;
    UIDevice.currentDevice.batteryMonitoringEnabled = YES;
    double started = NSProcessInfo.processInfo.systemUptime;
    double lastPulse = 0;
    NSString *previous = @"";
    Report(@"ready");
    @try {
        while (YES) {
            @autoreleasepool {
                [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
                double now = NSProcessInfo.processInfo.systemUptime;
                if (now - MAX(started, heartbeat) > 30) break;
                BOOL locked = YES, passcode = YES;
                lockStatus(serverPort(), &locked, &passcode);
                UIDeviceBatteryState battery = UIDevice.currentDevice.batteryState;
                BOOL powered = battery == UIDeviceBatteryStateCharging || battery == UIDeviceBatteryStateFull;
                NSString *state = !powered ? @"unplugged" : locked ? @"locked" :
                    !CUCanPulse(now, heartbeat, powered, !locked) ? @"waiting" : @"armed";
                if (![state isEqual:previous]) { Report(state); previous = state; }
                if (!CUCanPulse(now, heartbeat, powered, !locked) || now - lastPulse < 10) continue;
                // F13 has no normal iOS action; apps with custom hardware-key bindings may handle it.
                id event = ((id (*)(id, SEL, unsigned int, unsigned int, double))objc_msgSend)(eventClass, make, 0x07, 0x68, 0.005);
                NSError *error = nil;
                BOOL ok = event && ((BOOL (*)(id, SEL, id, NSError **))objc_msgSend)(XCUIDevice.sharedDevice, perform, event, &error);
                if (!ok) { Report(@"event-failed"); XCTFail(@"F13 event failed: %@", error); break; }
                lastPulse = NSProcessInfo.processInfo.systemUptime;
                Report(@"awake");
            }
        }
    } @finally {
        notify_cancel(token);
        UIDevice.currentDevice.batteryMonitoringEnabled = NO;
        dlclose(sbs);
        Report(@"stopped");
    }
}
@end
