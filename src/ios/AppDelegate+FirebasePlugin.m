#import "AppDelegate+FirebasePlugin.h"
#import "FirebasePlugin.h"
#import <objc/runtime.h>

@import Firebase;
@import UserNotifications;

#define kApplicationInBackgroundKey @"applicationInBackground"
#define kDelegateKey @"delegate"

@implementation AppDelegate (FirebasePlugin)

+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method swizzled = class_getInstanceMethod(self, @selector(application:swizzledDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, swizzled);
}

- (BOOL)application:(UIApplication *)application swizzledDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"FirebasePlugin - Finished launching");
    [self application:application swizzledDidFinishLaunchingWithOptions:launchOptions];

    [FIRMessaging messaging].delegate = self;
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;

    [[UIApplication sharedApplication] registerForRemoteNotifications];
    [FIRApp configure];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefreshNotification:)
                                                 name:FIRMessagingRegistrationTokenRefreshedNotification object:nil];

    self.applicationInBackground = @(YES);
    
    return YES;
}

- (void)tokenRefreshNotification:(NSNotification *)notification {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"FirebasePlugin - Erro ao obter o token do FCM: %@", error);
        } else {
            if (token != nil) {
                NSLog(@"FirebasePlugin - Token do FCM: %@", token);
                [FirebasePlugin.firebasePlugin sendToken:token];
            }
        }
    }];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    self.applicationInBackground = @(NO);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    self.applicationInBackground = @(YES);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [FIRMessaging messaging].APNSToken = deviceToken;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self handleRemoteNotification:userInfo clickOpen:@"false"];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    [self handleRemoteNotification:userInfo clickOpen:@"false"];
    completionHandler(UIBackgroundFetchResultNewData);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {

    NSDictionary *userInfo = notification.request.content.userInfo;
    [self handleRemoteNotification:userInfo clickOpen:@"true"];
    completionHandler(UNNotificationPresentationOptionAlert);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
 didReceiveNotificationResponse:(UNNotificationResponse *)response
          withCompletionHandler:(void (^)(void))completionHandler {

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    [self handleRemoteNotification:userInfo clickOpen:@"true"];
    completionHandler();
}

- (void)handleRemoteNotification:(NSDictionary *)userInfo clickOpen:(NSString *) clickOpen {
    NSLog(@"FirebasePlugin - Received remote notification: %@", userInfo);

    
    BOOL isInBackground = [self.applicationInBackground boolValue];

    if (isInBackground) {
        NSLog(@"FirebasePlugin - App in background, received remote notification");
    } else {
        NSLog(@"FirebasePlugin - App in foreground, received remote notification");
    }
    
    
    NSMutableDictionary *userInfoMutable = [userInfo mutableCopy];
    [userInfoMutable setValue:(clickOpen ? @"true": @"false") forKey:@"FromPushNotification"];
    
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;

    if([clickOpen  isEqual: @"true"]) {
        [nc postNotificationName:@"FirebaseRemoteNotificationClickedDispatch" object:userInfoMutable];
    } else {
        [nc postNotificationName:@"FirebaseRemoteNotificationReceivedDispatch" object:userInfoMutable];
    }
 
    [FirebasePlugin.firebasePlugin sendNotification:userInfo];
}

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, @selector(applicationInBackground));
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, @selector(applicationInBackground), applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
