#import "FirebasePlugin.h"
#import <Cordova/CDV.h>
#import "AppDelegate.h"

@import FirebaseMessaging;
@import FirebaseAnalytics;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif

#ifndef NSFoundationVersionNumber_iOS_9_x_Max
#define NSFoundationVersionNumber_iOS_9_x_Max 1299
#endif

@interface FirebasePlugin () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end

@implementation FirebasePlugin

@synthesize notificationCallbackId;
@synthesize tokenRefreshCallbackId;
@synthesize notificationStack;
@synthesize traces;

static NSInteger const kNotificationStackSize = 10;
static FirebasePlugin *firebasePlugin;

+ (FirebasePlugin *)firebasePlugin {
    return firebasePlugin;
}

- (void)pluginInitialize {
    NSLog(@"FirebasePlugin - Starting Firebase plugin");
    firebasePlugin = self;
    [FIRMessaging messaging].delegate = self;
}

#pragma mark - Notifications

- (void)getId:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            NSLog(@"FirebasePlugin - Error fetching FCM token for getId: %@", error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token ?: @""];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getToken:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            NSLog(@"FirebasePlugin - Error fetching FCM token for getToken: %@", error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token ?: @""];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)hasPermission:(CDVInvokedUrlCommand *)command {
    if ([UNUserNotificationCenter class]) {
        // iOS 10+ - async check
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            BOOL enabled = (settings.authorizationStatus == UNAuthorizationStatusAuthorized ||
                            settings.authorizationStatus == UNAuthorizationStatusProvisional);
            NSMutableDictionary *message = [NSMutableDictionary dictionaryWithCapacity:1];
            [message setObject:@(enabled) forKey:@"isEnabled"];
            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
            [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        }];
    } else {
        // iOS 9 and below
        UIApplication *application = [UIApplication sharedApplication];
        BOOL enabled = NO;
        if ([application respondsToSelector:@selector(currentUserNotificationSettings)]) {
            enabled = application.currentUserNotificationSettings.types != UIUserNotificationTypeNone;
        } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
            enabled = application.enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
#pragma GCC diagnostic pop
        }
        NSMutableDictionary *message = [NSMutableDictionary dictionaryWithCapacity:1];
        [message setObject:@(enabled) forKey:@"isEnabled"];
        CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
        [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
    }
}

- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    if ([UNUserNotificationCenter class]) {
        // iOS 10 or higher
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions = (UNAuthorizationOptionAlert |
                                             UNAuthorizationOptionSound |
                                             UNAuthorizationOptionBadge);
        [[UNUserNotificationCenter currentNotificationCenter]
         requestAuthorizationWithOptions:authOptions
                      completionHandler:^(BOOL granted, NSError * _Nullable error) {
            CDVPluginResult *pluginResult;
            if (error) {
                NSLog(@"FirebasePlugin - Error requesting notification permission: %@", error);
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
            } else {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                    });
                }
                pluginResult = [CDVPluginResult resultWithStatus:granted ? CDVCommandStatus_OK : CDVCommandStatus_ERROR];
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    } else {
        // iOS 9 and below
        UIUserNotificationType allNotificationTypes = (UIUserNotificationTypeSound |
                                                      UIUserNotificationTypeAlert |
                                                      UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    int number = [[command.arguments objectAtIndex:0] intValue];
    [self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:number];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        long badge = [[UIApplication sharedApplication] applicationIconBadgeNumber];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:badge];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)subscribe:(CDVInvokedUrlCommand *)command {
    NSString *topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];
    [[FIRMessaging messaging] subscribeToTopic:topic completion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            NSLog(@"FirebasePlugin - Error subscribing to topic %@: %@", topic, error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    NSString *topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];
    [[FIRMessaging messaging] unsubscribeFromTopic:topic completion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            NSLog(@"FirebasePlugin - Error unsubscribing from topic %@: %@", topic, error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unregister:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] deleteTokenWithCompletion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            NSLog(@"FirebasePlugin - Unable to delete FCM token: %@", error);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            NSLog(@"FirebasePlugin - FCM token deleted successfully");
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    self.notificationCallbackId = command.callbackId;
    if (self.notificationStack && [self.notificationStack count]) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error) {
            NSLog(@"FirebasePlugin - Error fetching FCM token for refresh: %@", error);
        } else if (token) {
            [self sendToken:token];
        }
    }];
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId) {
        NSMutableDictionary *payload = [userInfo mutableCopy];
        // Ensure consistent payload keys with AppDelegate
        if (!payload[@"FromPushNotification"]) {
            payload[@"FromPushNotification"] = @"true";
        }
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:payload];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) {
            self.notificationStack = [[NSMutableArray alloc] init];
        }
        [self.notificationStack addObject:[userInfo mutableCopy]];
        if ([self.notificationStack count] >= kNotificationStackSize) {
            [self.notificationStack removeObjectAtIndex:0]; // Remove oldest (FIFO)
        }
    }
}

- (void)sendToken:(NSString *)token {
    if (self.tokenRefreshCallbackId && token) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
    }
}

- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        // Clear badge and notifications
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
        if ([UNUserNotificationCenter class]) {
            [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        }
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

#pragma mark - FIRMessagingDelegate

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FirebasePlugin - FCM registration token refreshed: %@", fcmToken);
    if (fcmToken) {
        [self sendToken:fcmToken];
    }
}

- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"FirebasePlugin - Received data message: %@", remoteMessage.appData);
    NSMutableDictionary *payload = [remoteMessage.appData mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @(NO);
    [self sendNotification:payload];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSMutableDictionary *payload = [notification.request.content.userInfo mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @(NO);
    NSLog(@"FirebasePlugin - Foreground notification: %@", payload);
    [self sendNotification:payload];

    // Present notification in foreground
    UNNotificationPresentationOptions options = (UNNotificationPresentationOptionAlert |
                                                UNNotificationPresentationOptionSound |
                                                UNNotificationPresentationOptionBadge);
    completionHandler(options);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {
    NSMutableDictionary *payload = [response.notification.request.content.userInfo mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @(YES);
    NSLog(@"FirebasePlugin - Notification tapped: %@", payload);
    [self sendNotification:payload];
    completionHandler();
}

#pragma mark - Analytics

- (void)setAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
    BOOL enabled = [[command argumentAtIndex:0] boolValue];
    [FIRAnalytics setAnalyticsCollectionEnabled:enabled];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString *name = [command.arguments objectAtIndex:0];
        NSDictionary *parameters;
        @try {
            parameters = [command argumentAtIndex:1];
            if (!parameters) {
                NSString *description = NSLocalizedString([command argumentAtIndex:1 withDefault:@"No Message Provided"], nil);
                parameters = @{ NSLocalizedDescriptionKey: description };
            }
        } @catch (NSException *exception) {
            NSLog(@"FirebasePlugin - Error parsing logEvent parameters: %@", exception);
            parameters = @{ NSLocalizedDescriptionKey: @"Invalid parameters" };
        }

        [FIRAnalytics logEventWithName:name parameters:parameters];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setScreenName:(CDVInvokedUrlCommand *)command {
    NSString *name = [command.arguments objectAtIndex:0];
    if (name) {
        [FIRAnalytics logEventWithName:kFIREventScreenView
                            parameters:@{kFIRParameterScreenName: name,
                                         kFIRParameterScreenClass: @"CordovaViewController"}];
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString *userId = [command.arguments objectAtIndex:0];
        [FIRAnalytics setUserID:userId];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString *name = [command.arguments objectAtIndex:0];
        NSString *value = [command.arguments objectAtIndex:1];
        if (name && value) {
            [FIRAnalytics setUserPropertyString:value forName:name];
        }
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end