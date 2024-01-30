#import "AppDelegate+FirebasePlugin.h"
#import "FirebasePlugin.h"
@import FirebaseMessaging;
// @import Fabric;
// @import Crashlytics;
 @import FirebaseAnalytics;
// @import FirebaseRemoteConfig;
// @import FirebaseAuth;
#import <objc/runtime.h>

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  @import UserNotifications;

  // Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
  // running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
  // devices running iOS 10 and above.
  @interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
  @end
#endif

#define kApplicationInBackgroundKey @"applicationInBackground"
#define kDelegateKey @"delegate"

@implementation AppDelegate (FirebasePlugin)

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0

- (void)setDelegate:(id)delegate {
    objc_setAssociatedObject(self, kDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)delegate {
    return objc_getAssociatedObject(self, kDelegateKey);
}

#endif

+ (void)load {
    Method original = class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:));
    Method swizzled = class_getInstanceMethod(self, @selector(application:swizzledDidFinishLaunchingWithOptions:));
    method_exchangeImplementations(original, swizzled);
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, kApplicationInBackgroundKey, applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, kApplicationInBackgroundKey);
}

- (BOOL)application:(UIApplication *)application swizzledDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"FirebasePlugin - Finished launching");
    [self application:application swizzledDidFinishLaunchingWithOptions:launchOptions];

    
    [FIRMessaging messaging].delegate = self;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
    // Configurar o delegado para notificações do centro de notificações
    NSLog(@"FirebasePlugin - Finished launching - Configure iOS >= 10");
    [UNUserNotificationCenter currentNotificationCenter].delegate = self;
#endif

     
    [[UIApplication sharedApplication] registerForRemoteNotifications];

    
    [FIRApp configure];

     
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefreshNotification:)
                                                 name:kFIRMessagingRegistrationTokenRefreshNotification object:nil];
    
    self.applicationInBackground = @(YES);
    
    return YES;
}
/*
- (void)tokenRefreshNotification:(NSNotification *)notification {
    // Tratar a renovação do token do FCM
    NSString *refreshedToken = [FIRMessaging messaging].FCMToken;
    if (refreshedToken) {
        NSLog(@"FirebasePlugin - Novo token do FCM: %@", refreshedToken);
        
    }
}*/


- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self connectToFcm];
    self.applicationInBackground = @(NO);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[FIRMessaging messaging] disconnect];
    self.applicationInBackground = @(YES);
    NSLog(@"FirebasePlugin - Disconnected from FCM");
}

- (void)tokenRefreshNotification:(NSNotification *)notification {
    // Token Refresh handling
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"FirebasePlugin - Erro ao obter o token do FCM: %@", error);
        } else {
            if (token != nil) {
                NSLog(@"FirebasePlugin - InstanceID token: %@", token);
                [FirebasePlugin.firebasePlugin sendToken:token];
            }
        }
    }];
}


- (void)connectToFcm {
    // Obter o token atual do FCM
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"FirebasePlugin - Erro ao obter o token do FCM: %@", error);
        } else {
            if (token != nil) {
                NSLog(@"FirebasePlugin - InstanceID token: %@", token);
            }
        }
    }];
}


- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [FIRMessaging messaging].APNSToken = deviceToken;
    NSLog(@"FirebasePlugin - deviceToken1 = %@", deviceToken);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSDictionary *mutableUserInfo = [userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];

    // Print full message.
    NSLog(@"FirebasePlugin - didReceiveRemoteNotification - before");
    NSLog(@"FirebasePlugin - Response %@", mutableUserInfo);
    NSLog(@"FirebasePlugin - didReceiveRemoteNotification - after");

    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    NSDictionary *mutableUserInfo = [userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];

    // Print full message.
    NSLog(@"FirebasePlugin - didReceiveRemoteNotification:fetchCompletionHandler - before");
    NSLog(@"FirebasePlugin - Response %@", mutableUserInfo);
    NSLog(@"FirebasePlugin - didReceiveRemoteNotification:fetchCompletionHandler - after");

    completionHandler(UIBackgroundFetchResultNewData);
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

// [START ios_10_data_message]
// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
// To enable direct data messages, you can set [Messaging messaging].shouldEstablishDirectChannel to YES.
- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"FirebasePlugin - didReceiveMessage");
    NSLog(@"FirebasePlugin - Received data message: %@", remoteMessage.appData);

    // This will allow us to handle FCM data-only push messages even if the permission for push
    // notifications is yet missing. This will only work when the app is in the foreground.
    [FirebasePlugin.firebasePlugin sendNotification:remoteMessage.appData];
}
// [END ios_10_data_message]

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
  NSLog(@"FirebasePlugin - Unable to register for remote notifications: %@", error);
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
           
    NSLog(@"FirebasePlugin - willPresentNotification:withCompletionHandler - 1");

    [self.delegate userNotificationCenter:center
              willPresentNotification:notification
                withCompletionHandler:completionHandler];

    if (![notification.request.trigger isKindOfClass:UNPushNotificationTrigger.class])
        return;

    NSDictionary *mutableUserInfo = [notification.request.content.userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];

    // Print full message.
    NSLog(@"FirebasePlugin - willPresentNotification:withCompletionHandler - before");
    NSLog(@"FirebasePlugin - Response %@", mutableUserInfo);
    NSLog(@"FirebasePlugin - willPresentNotification:withCompletionHandler - after");

    completionHandler(UNNotificationPresentationOptionAlert);
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

- (void) userNotificationCenter:(UNUserNotificationCenter *)center
 didReceiveNotificationResponse:(UNNotificationResponse *)response
          withCompletionHandler:(void (^)(void))completionHandler
{
    NSLog(@"FirebasePlugin - didReceiveNotificationResponse:withCompletionHandler - 1");
            
    [self.delegate userNotificationCenter:center
       didReceiveNotificationResponse:response
                withCompletionHandler:completionHandler];

    if (![response.notification.request.trigger isKindOfClass:UNPushNotificationTrigger.class])
        return;

    NSDictionary *mutableUserInfo = [response.notification.request.content.userInfo mutableCopy];

    [mutableUserInfo setValue:@YES forKey:@"tap"];

    // Print full message.
    NSLog(@"FirebasePlugin - didReceiveNotificationResponse:withCompletionHandler - before");
    NSLog(@"FirebasePlugin - Response %@", mutableUserInfo);
    NSLog(@"FirebasePlugin - didReceiveNotificationResponse:withCompletionHandler - after");

    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];

    completionHandler();
}

// Receive data message on iOS 10 devices.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    // Print full message
    NSLog(@"FirebasePlugin - applicationReceivedRemoteMessage");
    NSLog(@"%@", [remoteMessage appData]);
}
#endif

@end
