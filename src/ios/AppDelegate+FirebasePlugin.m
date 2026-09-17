#import <Cordova/CDV.h>
#import <UserNotifications/UserNotifications.h>
#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseMessaging/FirebaseMessaging.h>

@interface CDVAppDelegate (FirebasePlugin)

@property (nonatomic, strong, nullable) NSNumber *applicationInBackground;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@property (nonatomic, nullable, weak) id<UNUserNotificationCenterDelegate> delegate;
#endif

@end

#import "AppDelegate+FirebasePlugin.h"
#import "FirebasePlugin.h"
#import <objc/runtime.h>

#define kApplicationInBackgroundKey @"applicationInBackground"
#define kDelegateKey @"delegate"

@implementation CDVAppDelegate (FirebasePlugin)

+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method swizzled = class_getInstanceMethod(self, @selector(application:swizzledDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, swizzled);
}

- (BOOL)application:(UIApplication *)application
swizzledDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"FirebasePlugin - Configuring Firebase in didFinishLaunching");

    // 1) Configure Firebase once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (![FIRApp defaultApp]) { // Check if Firebase is already configured
            [FIRApp configure];
        }
    });

    // 2) Set up notification center (iOS 10+)
    if ([UNUserNotificationCenter class]) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = (id<UNUserNotificationCenterDelegate>)self;

        // Request authorization for notifications
        UNAuthorizationOptions options = (UNAuthorizationOptionAlert |
                                         UNAuthorizationOptionSound |
                                         UNAuthorizationOptionBadge);
        [center requestAuthorizationWithOptions:options
                             completionHandler:^(BOOL granted, NSError * _Nullable error) {
            if (error) {
                NSLog(@"FirebasePlugin - Error requesting push authorization: %@", error);
            } else if (granted) {
                NSLog(@"FirebasePlugin - Push authorization granted");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] registerForRemoteNotifications];
                });
            } else {
                NSLog(@"FirebasePlugin - Push authorization denied");
            }
        }];
    } else {
        // iOS 9 and below (legacy support, optional for iOS 15.0+)
        UIUserNotificationType types = (UIUserNotificationTypeAlert |
                                       UIUserNotificationTypeSound |
                                       UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
    }

    // 3) Set Firebase Messaging delegate
    [FIRMessaging messaging].delegate = (id<FIRMessagingDelegate>)self;

    // 4) Initialize application background state
    self.applicationInBackground = @(YES);

    // Call original implementation
    return [self application:application swizzledDidFinishLaunchingWithOptions:launchOptions];
}

#pragma mark - FIRMessagingDelegate

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FirebasePlugin - FCM registration token: %@", fcmToken);
    if (fcmToken) {
        [FirebasePlugin.firebasePlugin sendToken:fcmToken];
    }
}

#pragma mark - App Lifecycle

- (void)applicationDidBecomeActive:(UIApplication *)application {
    self.applicationInBackground = @(NO);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    self.applicationInBackground = @(YES);
}

#pragma mark - APNs

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"FirebasePlugin - Received APNs token");
    [FIRMessaging messaging].APNSToken = deviceToken;
}

- (void)application:(UIApplication *)application
didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"FirebasePlugin - Failed to register for remote notifications: %@", error);
}

#pragma mark - UNUserNotificationCenterDelegate (iOS 10+)

// Foreground notifications
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSDictionary *userInfo = notification.request.content.userInfo;
    NSMutableDictionary *payload = [userInfo mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @(NO);

    NSLog(@"FirebasePlugin - Foreground notification: %@", payload);
    [FirebasePlugin.firebasePlugin sendNotification:payload];

    // Present notification in foreground (iOS 14+ compatible)
    UNNotificationPresentationOptions options = (UNNotificationPresentationOptionList |
                                                UNNotificationPresentationOptionBanner |
                                                UNNotificationPresentationOptionSound |
                                                UNNotificationPresentationOptionBadge);
    completionHandler(options);
}

// User interaction with notification
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSMutableDictionary *payload = [userInfo mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @(YES);

    NSLog(@"FirebasePlugin - Notification tapped: %@", payload);
    [FirebasePlugin.firebasePlugin sendNotification:payload];

    completionHandler();
}

#pragma mark - iOS 7-9 Notification Handling

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    NSMutableDictionary *payload = [userInfo mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @([self.applicationInBackground boolValue]);

    NSLog(@"FirebasePlugin - Received remote notification (iOS 7-9): %@", payload);
    [FirebasePlugin.firebasePlugin sendNotification:payload];

    completionHandler(UIBackgroundFetchResultNewData);
}

#pragma mark - Associated Objects

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, kApplicationInBackgroundKey);
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, kApplicationInBackgroundKey,
                             applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id<UNUserNotificationCenterDelegate>)delegate {
    return objc_getAssociatedObject(self, kDelegateKey);
}

- (void)setDelegate:(id<UNUserNotificationCenterDelegate>)delegate {
    objc_setAssociatedObject(self, kDelegateKey,
                             delegate, OBJC_ASSOCIATION_ASSIGN);
}

@end