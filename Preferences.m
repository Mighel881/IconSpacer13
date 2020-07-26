#import <UIKit/UIKit.h>
#import "Preferences.h"
#import <Social/Social.h>
#import <SafariServices/SafariServices.h>
#import <spawn.h>
#import <firmware.h>
#import <UIKit/UIImage+Private.h>
#import <sys/sysctl.h>
#import "Image.h"

#define IS_PAD ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconsp13.plist"
#define Notify_Preferences "com.ichitaso.iconsp13.preferencechanged"
#define Notify_Resprings "com.ichitaso.iconsp13.respring"

#define TWEAK_TITLE @"IconSpacer13";
#define TWEAK_DESCRIPTION @"by Cannathea";
#define BUNDLE_NAME @"IconSpacerSettings.bundle"

#define SettingsColor(alphaValue) [UIColor colorWithRed:0.48 green:0.49 blue:0.54 alpha:alphaValue]
#define PSTableColor(alphaValue) [UIColor colorWithRed:0.00 green:0.00 blue:0.00 alpha:alphaValue]
#define PSDarkColor(alphaValue) [UIColor colorWithRed:1.00 green:1.00 blue:1.00 alpha:alphaValue]

#define LOGO_IMAGE @"CannatheaLogo"

static BOOL isTinted() {
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/com.ichitaso.iconsp13.list"]) {
        return YES;
    }
    return NO;
}

static void easy_spawn(const char * args[]) {
    pid_t pid;
    int status;
    posix_spawn(&pid, args[0], NULL, NULL, (char * const*)args, NULL);
    waitpid(pid, &status, WEXITED);
}

@class PSSpecifier;

@interface PSSpecifier (Private)
- (void)setIdentifier:(NSString *)identifier;
@end

@interface PSListController (Private)
- (void)loadView;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)_returnKeyPressed:(id)arg1;
- (void)presentViewController:(id)arg1 animated:(BOOL)arg2 completion:(id)arg3;
@end

@interface PSTableCell (Private)
@property(readonly, assign, nonatomic) UILabel *textLabel;
@end

@interface CustomButtonCell : PSTableCell
@end

@implementation CustomButtonCell
- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.textLabel.textColor = PSDarkColor(1.0);
    } else {
        self.textLabel.textColor = PSTableColor(1.0);
    }
}
@end

@interface CustomLinkCell : PSTableCell {
    NSString *_user;
}
@property (nonatomic, readonly) BOOL isBig;
@property (nonatomic, retain, readonly) UIView *avatarView;
@property (nonatomic, retain, readonly) UIImageView *avatarImageView;
@property (nonatomic, retain) UIImage *avatarImage;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(id)specifier;
- (BOOL)shouldShowAvatar;
@end

@implementation CustomLinkCell
- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.textLabel.textColor = PSDarkColor(1.0);
    } else {
        self.textLabel.textColor = PSTableColor(1.0);
    }
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    
    if (self) {
        _isBig = specifier.properties[@"big"] && ((NSNumber *)specifier.properties[@"big"]).boolValue;
        
        self.accessoryView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"twitter" inBundle:[NSBundle bundleForClass:self.class]]];
        
        _user = [specifier.properties[@"user"] copy];
        NSAssert(_user, @"User name not provided");
        
        self.detailTextLabel.text = [@"@" stringByAppendingString:_user];
        
        self.detailTextLabel.numberOfLines = _isBig ? 0 : 1;
        self.detailTextLabel.textColor = [UIColor colorWithWhite:142.f / 255.f alpha:1];
        
        if (self.shouldShowAvatar) {
            CGFloat size = _isBig ? 38.f : 29.f;
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, [UIScreen mainScreen].scale);
            specifier.properties[@"iconImage"] = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            _avatarView = [[UIView alloc] initWithFrame:self.imageView.bounds];
            _avatarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _avatarView.backgroundColor = [UIColor colorWithWhite:0.9f alpha:1];
            _avatarView.userInteractionEnabled = NO;
            _avatarView.clipsToBounds = YES;
            _avatarView.layer.cornerRadius = size / 2;
            [self.imageView addSubview:_avatarView];
            
            if (specifier.properties[@"initials"]) {
                _avatarView.backgroundColor = [UIColor colorWithWhite:0.8f alpha:1];
                
                UILabel *label = [[UILabel alloc] initWithFrame:_avatarView.bounds];
                label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                label.font = [UIFont systemFontOfSize:13.f];
                label.textAlignment = NSTextAlignmentCenter;
                label.textColor = [UIColor whiteColor];
                label.text = specifier.properties[@"initials"];
                [_avatarView addSubview:label];
            } else {
                _avatarImageView = [[UIImageView alloc] initWithFrame:_avatarView.bounds];
                _avatarImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                _avatarImageView.alpha = 0;
                _avatarImageView.userInteractionEnabled = NO;
                _avatarImageView.layer.minificationFilter = kCAFilterTrilinear;
                [_avatarView addSubview:_avatarImageView];
                
                [self loadAvatarIfNeeded];
            }
        }
    }
    
    return self;
}

#pragma mark - Avatar

- (UIImage *)avatarImage {
    return _avatarImageView.image;
}

- (void)setAvatarImage:(UIImage *)avatarImage {
    // set the image on the image view
    _avatarImageView.image = avatarImage;
    // if we haven’t faded in yet
    if (_avatarImageView.alpha == 0) {
        // do so now
        [UIView animateWithDuration:0.15 animations:^{
            _avatarImageView.alpha = 1;
        }];
    }
}

- (BOOL)shouldShowAvatar {
    return YES;
}

- (void)loadAvatarIfNeeded {
    if (!_user) return;
    
    if (self.avatarImage) return;
    
    NSString *urlStr = @"https://mobile.twitter.com/%@/profile_image?size=bigger";
    urlStr = [urlStr stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    urlStr = [NSString stringWithFormat:urlStr, _user];
    
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [[[NSURLSession sharedSession] dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if (error) return;
        
        UIImage *image = [UIImage imageWithData:data];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.avatarImage = image;
        });
        
    }] resume];
}
@end

static CGFloat const kHBFPHeaderTopInset = 64.f;
static CGFloat const kHBFPHeaderHeight = 160.f;

@interface IconSpacerController : PSListController {
    CGRect topFrame;
	UILabel *bannerTitle;
	UILabel *footerLabel;
	UILabel *titleLabel;
    UILabel *purchaseLabel;
}
@property(retain) UIView *bannerView;
- (NSArray *)specifiers;
- (void)respringPrefs:(NSNotification *)notification;
- (void)respring;
@end

@implementation IconSpacerController

- (instancetype)init {
    self = [super init];
    
    // Respring Notification
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"respringPrefs" object:nil];
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)respringPrefsCallBack,
                                    CFSTR(Notify_Resprings),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(respringPrefs:) name:@"respringPrefs" object:nil];
    
    return self;
}

void respringPrefsCallBack() {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"respringPrefs" object:nil];
}

- (void)respringPrefs:(NSNotification *)notification {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:nil
                                        message:@"Respring is required"
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
                                                          
                                                      }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Respring"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
                                                          [self showLoadingView];
                                                          [self performSelector:@selector(respring) withObject:self afterDelay:1.0];
                                                      }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)showLoadingView {
    UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
    
    UIView *loading = [[UIView alloc] initWithFrame:CGRectMake(window.frame.size.width/2-50, window.frame.size.height/2-50, 100, 100)];
    [loading setBackgroundColor:[UIColor blackColor]];
    [loading setAlpha:0.7];
    loading.layer.cornerRadius = 15;
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(10, 10, 80, 80)];
    spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleLarge;
    spinner.color = [UIColor whiteColor];
    [spinner startAnimating];
    
    [loading addSubview:spinner];
    loading.userInteractionEnabled = NO;
    [window addSubview:loading];
}

- (void)respring {
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/sbreload"]) {
        easy_spawn((const char *[]){"/usr/bin/sbreload", NULL});
    } else {
        easy_spawn((const char *[]){"/usr/bin/killall", "backboardd", NULL});
    }
}

- (NSArray *)specifiers {
	if (_specifiers == nil) {
        NSMutableArray *specifiers = [NSMutableArray array];
        PSSpecifier *spec;
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Settings"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSwitchCell
                                                edit:Nil];
        [spec setProperty:@"enabled" forKey:@"key"];
        [spec setProperty:@YES forKey:@"default"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Portrait Mode"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
        [specifiers addObject:spec];
                
        spec = [PSSpecifier preferenceSpecifierNamed:@"pt"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"pTopSpace" forKey:@"key"];
        [spec setProperty:@0 forKey:@"default"];
        [spec setProperty:@0 forKey:@"min"];
        [spec setProperty:@500 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@500 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        /*spec = [PSSpecifier preferenceSpecifierNamed:@"pl"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"pLeftSpace" forKey:@"key"];
        [spec setProperty:@0 forKey:@"default"];
        [spec setProperty:@-300 forKey:@"min"];
        [spec setProperty:@300 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@600 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"pb"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"pBottomSpace" forKey:@"key"];
        [spec setProperty:@0 forKey:@"default"];
        [spec setProperty:@-300 forKey:@"min"];
        [spec setProperty:@300 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@300 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"pr"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"pRightSpace" forKey:@"key"];
        [spec setProperty:@0 forKey:@"default"];
        [spec setProperty:@-300 forKey:@"min"];
        [spec setProperty:@300 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@600 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];*/
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Landscape Mode"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
        [spec setProperty:@"On devices other than iPhone X series, when you return with the home button, it will be reflected when you move the page etc." forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"lt"
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"lTopSpace" forKey:@"key"];
        [spec setProperty:@0 forKey:@"default"];
        [spec setProperty:@0 forKey:@"min"];
        [spec setProperty:@500.0 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@500 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        /*spec = [PSSpecifier preferenceSpecifierNamed:Nil
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"lLeftSpace" forKey:@"key"];
        [spec setProperty:@0.0 forKey:@"default"];
        [spec setProperty:@-300.0 forKey:@"min"];
        [spec setProperty:@300.0 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@1 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:Nil
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"lBottomSpace" forKey:@"key"];
        [spec setProperty:@0.0 forKey:@"default"];
        [spec setProperty:@-300.0 forKey:@"min"];
        [spec setProperty:@300.0 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@1 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:Nil
                                              target:self
                                                 set:@selector(setPreferenceValue:specifier:)
                                                 get:@selector(readPreferenceValue:)
                                              detail:Nil
                                                cell:PSSliderCell
                                                edit:Nil];
        [spec setProperty:@"lRightSpace" forKey:@"key"];
        [spec setProperty:@0.0 forKey:@"default"];
        [spec setProperty:@-300.0 forKey:@"min"];
        [spec setProperty:@300.0 forKey:@"max"];
        [spec setProperty:@YES forKey:@"isSegmented"];
        [spec setProperty:@1 forKey:@"segmentCount"];
        [spec setProperty:@YES forKey:@"showValue"];
        [specifiers addObject:spec];*/
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Settings"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSButtonCell
                                                edit:nil];
        
        spec->action = @selector(resetSettings);
        [spec setProperty:@1 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"CustomButtonCell") forKey:@"cellClass"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier emptyGroupSpecifier];
        [spec setProperty:@"I would appreciate it if you could donate or buy my paid tweaks." forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Donate"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:PSLinkCell
                                                edit:nil];
        
        spec->action = @selector(openDonate);
        [spec setProperty:@1 forKey:@"alignment"];
        [spec setProperty:NSClassFromString(@"CustomButtonCell") forKey:@"cellClass"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Credit"
                                              target:self
                                                 set:Nil
                                                 get:Nil
                                              detail:Nil
                                                cell:PSGroupCell
                                                edit:Nil];
        [spec setProperty:@"© 2015 - 2020 Cannathea by ichitaso" forKey:@"footerText"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Developed by ichitaso"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:[PSTableCell cellTypeFromString:@"PSButtonCell"]
                                                edit:nil];
        
        spec->action = @selector(openIchitasoTwitter);
        [spec setProperty:@"ichitaso" forKey:@"user"];
        [spec setProperty:NSClassFromString(@"CustomLinkCell") forKey:@"cellClass"];
        [specifiers addObject:spec];
        
        spec = [PSSpecifier preferenceSpecifierNamed:@"Icon designed by Jannik"
                                              target:self
                                                 set:nil
                                                 get:nil
                                              detail:nil
                                                cell:[PSTableCell cellTypeFromString:@"PSButtonCell"]
                                                edit:nil];
        
        spec->action = @selector(openJannikTwitter);
        [spec setProperty:@"JannikCrack" forKey:@"user"];
        [spec setProperty:NSClassFromString(@"CustomLinkCell") forKey:@"cellClass"];
        [specifiers addObject:spec];
        
        _specifiers = [specifiers copy];
	}
	return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @autoreleasepool {
        NSMutableDictionary *EnablePrefsCheck = [[NSMutableDictionary alloc] initWithContentsOfFile:PREF_PATH]?:[NSMutableDictionary dictionary];
        [EnablePrefsCheck setObject:value forKey:[specifier identifier]];
        
        //if ([[specifier identifier] isEqualToString:@"enabled"]) {
        //    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Resprings), NULL, NULL, YES);
        //}
        
        [EnablePrefsCheck writeToFile:PREF_PATH atomically:YES];
        
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
    }
}
- (id)readPreferenceValue:(PSSpecifier*)specifier {
    @autoreleasepool {
        NSDictionary *EnablePrefsCheck = [[NSDictionary alloc] initWithContentsOfFile:PREF_PATH];
        return EnablePrefsCheck[[specifier identifier]]?:[[specifier properties] objectForKey:@"default"];
    }
}

- (void)resetSettings {
    UIAlertController *alertController =
    [UIAlertController alertControllerWithTitle:nil
                                        message:@"Reset Settings?"
                                 preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel
                                                      handler:^(UIAlertAction *action) {
    }]];
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"OK"
                                                        style:UIAlertActionStyleDestructive
                                                      handler:^(UIAlertAction *action) {
        
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [self reloadSpecifiers];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(Notify_Preferences), NULL, NULL, YES);
        
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)loadView {
  	[super loadView];
    
  	UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
    
  	if ([window respondsToSelector:@selector(tintColor)]) {
        // Dark mode
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            window.tintColor = PSDarkColor(0.8);
        } else {
            window.tintColor = SettingsColor(0.85);
        }
    }
    // UISwitch color
    [UISwitch appearanceWhenContainedInInstancesOfClasses:@[self.class]].onTintColor = SettingsColor(0.6);
    
    UINavigationItem *navigationItem = self.navigationItem;
    // Share button
    navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                  target:self
                                                  action:@selector(shareTweak)];
    
    navigationItem.titleView =
    [[UIImageView alloc] initWithImage:[UIImage imageNamed:LOGO_IMAGE
                                                  inBundle:[NSBundle bundleForClass:self.class]]];
    
    CGFloat headerHeight = 0 + kHBFPHeaderHeight;
    CGRect selfFrame = [self.view frame];
    
    _bannerView = [[UIView alloc] init];
    _bannerView.frame = CGRectMake(0, -kHBFPHeaderHeight, selfFrame.size.width, headerHeight);
    _bannerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    [self.table addSubview:_bannerView];
    [self.table sendSubviewToBack:_bannerView];
    
    topFrame = CGRectMake(0, -kHBFPHeaderHeight, 414, kHBFPHeaderHeight);
    
    bannerTitle = [[UILabel alloc] init];
    bannerTitle.text = TWEAK_TITLE;
    [bannerTitle setFont:[UIFont fontWithName:@"HelveticaNeue-Thin" size:40]];
    // Dark mode
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        bannerTitle.textColor = PSDarkColor(0.85);
    } else {
        bannerTitle.textColor = SettingsColor(0.85);
    }
    
    [_bannerView addSubview:bannerTitle];
    
    [bannerTitle setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_bannerView addConstraint:[NSLayoutConstraint constraintWithItem:bannerTitle attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_bannerView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0f]];
    [_bannerView addConstraint:[NSLayoutConstraint constraintWithItem:bannerTitle attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_bannerView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:20.0f]];
    bannerTitle.textAlignment = NSTextAlignmentCenter;//NSTextAlignmentRight;
    
    footerLabel = [[UILabel alloc] init];
    footerLabel.text = TWEAK_DESCRIPTION;
    [footerLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:15]];
    footerLabel.textColor = [UIColor grayColor];
    footerLabel.alpha = 1.0;
    
    [_bannerView addSubview:footerLabel];
    
    [footerLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_bannerView addConstraint:[NSLayoutConstraint constraintWithItem:footerLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_bannerView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0f]];
    [_bannerView addConstraint:[NSLayoutConstraint constraintWithItem:footerLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_bannerView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:60.0f]];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    
    purchaseLabel = [[UILabel alloc] init];
    if (isTinted()) {
        purchaseLabel.text = @"Please stop piracy.";
    } else {
        purchaseLabel.text = @"Thanks for your using.";
    }
    [purchaseLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Light" size:15]];
    purchaseLabel.textColor = [UIColor grayColor];
    purchaseLabel.alpha = 1.0;
    
    [_bannerView addSubview:purchaseLabel];
    
    [purchaseLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_bannerView addConstraint:[NSLayoutConstraint constraintWithItem:purchaseLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:_bannerView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0f]];
    [_bannerView addConstraint:[NSLayoutConstraint constraintWithItem:purchaseLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_bannerView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:80.0f]];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    
    [self.table setContentInset:UIEdgeInsetsMake(kHBFPHeaderHeight-kHBFPHeaderTopInset,0,0,0)];
    [self.table setContentOffset:CGPointMake(0, -kHBFPHeaderHeight+kHBFPHeaderTopInset)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
    
    if ([window respondsToSelector:@selector(tintColor)]) {
        // Dark mode
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            window.tintColor = PSDarkColor(0.8);
        } else {
            window.tintColor = SettingsColor(0.85);
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
    
    if ([window respondsToSelector:@selector(tintColor)]) {
        // Dark mode
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            window.tintColor = PSDarkColor(0.8);
        } else {
            window.tintColor = SettingsColor(0.85);
        }
    }
}

- (void)_unloadBundleControllers {
    [super _unloadBundleControllers];
    
    UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
    if ([window respondsToSelector:@selector(tintColor)]) {
        window.tintColor = nil;
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    UIWindow *window = [[UIApplication sharedApplication].windows firstObject];
    
    if ([[[self bundle] bundlePath] hasSuffix:BUNDLE_NAME]) {
        if ([window respondsToSelector:@selector(tintColor)]) {
            // Dark mode
            if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                window.tintColor = PSDarkColor(0.8);
            } else {
                window.tintColor = SettingsColor(0.85);
            }
        }
    } else {
        if ([window respondsToSelector:@selector(tintColor)]) {
            window.tintColor = nil;
        }
    }
}
// Refresh on dark mode toggle
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_13_0) {
        [self loadView];
        [self reloadSpecifiers];
    }
}

- (void)_returnKeyPressed:(NSNotification *)notification {
    [self.view endEditing:YES];
    [super _returnKeyPressed:notification];
}

- (void)shareTweak {
    NSString *texttoshare = @"#IconSpacer13 by @ichitaso! It's a useful tweaks!";
    NSURL *urlToShare = [NSURL URLWithString:@"https://cydia.ichitaso.com/depiction/iconsp13.html"];
    
    NSURL *url1 = [NSURL URLWithString:ICON_IMAGE];
    NSData *data1 = [NSData dataWithContentsOfURL:url1 options:NSDataReadingUncached error:nil];
    UIImage *image1 = [UIImage imageWithData:data1];
    
    NSArray *activityItems = @[texttoshare, urlToShare, image1];
    
    UIActivityViewController *activityVC =
    [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                      applicationActivities:nil];
    
    // Fix Crash for iPad
    if (IS_PAD) {
        activityVC.popoverPresentationController.sourceView = self.view;
        activityVC.popoverPresentationController.sourceRect = self.view.bounds;
        activityVC.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)openDonate {
    [self openURLInBrowser:@"https://cydia.ichitaso.com/donation.html"];
}

- (void)openIchitasoTwitter {
    NSString *twitterID = @"ichitaso";
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Follow @ichitaso"
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot://"]]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Tweetbot" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"tweetbot:///user_profile/%@",twitterID]]
                                               options:@{}
                                     completionHandler:nil];
        }]];
    }
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Twitter" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"twitter://user?screen_name=%@",twitterID]]
                                               options:@{}
                                     completionHandler:nil];
        }]];
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Browser" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:[NSString stringWithFormat:@"https://twitter.com/%@",twitterID]];
        });
    }]];
    
    // Fix Crash for iPad
    if (IS_PAD) {
        CGRect rect = self.view.frame;
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect)-60,rect.size.height-50, 120,50);
        alertController.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
        }]];
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)openJannikTwitter {
    NSString *twitterID = @"JannikCrack";
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Follow @JannikCrack"
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot://"]]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Tweetbot" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"tweetbot:///user_profile/%@",twitterID]]
                                               options:@{}
                                     completionHandler:nil];
        }]];
    }
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Twitter" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"twitter://user?screen_name=%@",twitterID]]
                                               options:@{}
                                     completionHandler:nil];
        }]];
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Open in Browser" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        double delayInSeconds = 0.8;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self openURLInBrowser:[NSString stringWithFormat:@"https://twitter.com/%@",twitterID]];
        });
    }]];
    
    // Fix Crash for iPad
    if (IS_PAD) {
        CGRect rect = self.view.frame;
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(rect)-60,rect.size.height-50, 120,50);
        alertController.popoverPresentationController.permittedArrowDirections = 0;
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
        }]];
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)openURLInBrowser:(NSString *)url {
    SFSafariViewControllerConfiguration *config = [[SFSafariViewControllerConfiguration alloc] init];
    config.barCollapsingEnabled = NO;
    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url] configuration:config];
    [self presentViewController:safari animated:YES completion:nil];
}

@end
