#import <firmware.h>
#import <dlfcn.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconsp13.plist"
#define Notify_Preferences "com.ichitaso.iconsp13.preferencechanged"

static BOOL isEnabled;
static float pTopSpace;
static float pBottomSpace;
static float pLeftSpace;
static float pRightSpace;
static float lTopSpace;
static float lBottomSpace;
static float lLeftSpace;
static float lRightSpace;

@interface SBIconListGridLayoutConfiguration : NSObject
- (void)setPortraitLayoutInsets:(UIEdgeInsets)arg1;
- (UIEdgeInsets)portraitLayoutInsets;
- (UIEdgeInsets)landscapeLayoutInsets;
- (NSUInteger)numberOfPortraitRows;
- (NSUInteger)numberOfPortraitColumns;
- (NSUInteger)numberOfLandscapeColumns;
- (NSUInteger)numberOfLandscapeRows;
@end

static SBIconListGridLayoutConfiguration *config = nil;

%hook SBIconListGridLayoutConfiguration
- (id)init {
    config = self;
    return %orig;
}
- (UIEdgeInsets)portraitLayoutInsets {
    if (isEnabled && [self numberOfPortraitColumns] != 3 && [self numberOfPortraitRows] != 3 && !([self numberOfPortraitRows] < 2)) {
        UIEdgeInsets orig = %orig;
        CGFloat top = orig.top;
        CGFloat left = orig.left;
        CGFloat bottom = orig.bottom;
        CGFloat right = orig.right;
        //NSLog(@"portraitLayoutInsets top:%@ left:%@ bottom:%@ right:%@",@(orig.top),@(orig.left),@(orig.bottom),@(orig.right));
        return UIEdgeInsetsMake(top+pTopSpace, left+pLeftSpace, bottom-pTopSpace, right+pRightSpace);
    }
    return %orig;
}
- (UIEdgeInsets)landscapeLayoutInsets {
    if (isEnabled && [self numberOfPortraitColumns] != 3 && [self numberOfPortraitRows] != 3 && !([self numberOfPortraitRows] < 2)) {
        UIEdgeInsets orig = %orig;
        CGFloat top = orig.top;
        CGFloat left = orig.left;
        CGFloat bottom = orig.bottom;
        CGFloat right = orig.right;
        return UIEdgeInsetsMake(top+lTopSpace, left+lLeftSpace, bottom-lTopSpace, right+lRightSpace);
    }
    return %orig;
}
%end

static void settingsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    
    isEnabled = (BOOL)[dict[@"enabled"] ?: @YES boolValue];
    pTopSpace = (float)[dict[@"pTopSpace"] ?: @0 floatValue];
    pBottomSpace = (float)[dict[@"pBottomSpace"] ?: @0 floatValue];
    pLeftSpace = (float)[dict[@"pLeftSpace"] ?: @0 floatValue];
    pRightSpace = (float)[dict[@"pRightSpace"] ?: @0 floatValue];
    lTopSpace = (float)[dict[@"lTopSpace"] ?: @0 floatValue];
    lBottomSpace = (float)[dict[@"lBottomSpace"] ?: @0 floatValue];
    lLeftSpace = (float)[dict[@"lLeftSpace"] ?: @0 floatValue];
    lRightSpace = (float)[dict[@"lRightSpace"] ?: @0 floatValue];
    
    //[config portraitLayoutInsets];
    //[config landscapeLayoutInsets];
}

%ctor {
    @autoreleasepool {
        // Settings Notifications
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        settingsChanged,
                                        CFSTR(Notify_Preferences),
                                        NULL,
                                        CFNotificationSuspensionBehaviorCoalesce);
        
        settingsChanged(NULL, NULL, NULL, NULL, NULL);
    }
}
