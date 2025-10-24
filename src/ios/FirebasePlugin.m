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

+ (FirebasePlugin *) firebasePlugin {
    return firebasePlugin;
}

- (void)pluginInitialize {
    NSLog(@"FirebasePlugin - Starting Firebase plugin");
    firebasePlugin = self;
    [FIRMessaging messaging].delegate = self;
}

//
// Notifications
//
- (void)getId:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getToken:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        CDVPluginResult *pluginResult;
        if (error) {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        } else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)hasPermission:(CDVInvokedUrlCommand *)command {
    BOOL enabled = NO;
    UIApplication *application = [UIApplication sharedApplication];

    if ([[UNUserNotificationCenter class] != nil]) {
        // iOS 10+ - async check
        [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {
            enabled = (settings.authorizationStatus == UNAuthorizedStatusAuthorized);
            NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
            [message setObject:[NSNumber numberWithBool:enabled] forKey:@"isEnabled"];
            CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
            [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
        }];
        return; // Exit early; result sent async
    } else if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        enabled = application.currentUserNotificationSettings.types != UIUserNotificationTypeNone;
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        enabled = application.enabledRemoteNotificationTypes != UIRemoteNotificationTypeNone;
#pragma GCC diagnostic pop
    }

    NSMutableDictionary* message = [NSMutableDictionary dictionaryWithCapacity:1];
    [message setObject:[NSNumber numberWithBool:enabled] forKey:@"isEnabled"];
    CDVPluginResult *commandResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [self.commandDelegate sendPluginResult:commandResult callbackId:command.callbackId];
}

- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    if ([UNUserNotificationCenter class] != nil) {
        // iOS 10 or higher
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [[UNUserNotificationCenter currentNotificationCenter]
            requestAuthorizationWithOptions:authOptions
            completionHandler:^(BOOL granted, NSError * _Nullable error) {
                [[UIApplication sharedApplication] registerForRemoteNotifications];
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus: granted ? CDVCommandStatus_OK : CDVCommandStatus_ERROR];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
    } else {
        // iOS 10 notifications aren't available
        // fall back to iOS 8-9 notifications
        UIUserNotificationType allNotificationTypes = (UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:allNotificationTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
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
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging] subscribeToTopic:topic completion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription] : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    NSString* topic = [NSString stringWithFormat:@"/topics/%@", [command.arguments objectAtIndex:0]];

    [[FIRMessaging messaging] unsubscribeFromTopic:topic completion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription] : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unregister:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] deleteTokenWithCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"FirebasePlugin - Unable to delete FCM token: %@", error);
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        } else {
            NSLog(@"FirebasePlugin - FCM token deleted successfully");
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
}

- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    self.notificationCallbackId = command.callbackId;

    if (self.notificationStack != nil && [self.notificationStack count]) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;

    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"FirebasePlugin - Error fetching FCM token: %@", error);
        } else if (token != nil) {
            [self sendToken:token];
        }
    }];
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:userInfo];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) {
            self.notificationStack = [[NSMutableArray alloc] init];
        }

        // stack notifications until a callback has been registered
        [self.notificationStack addObject:userInfo];

        if ([self.notificationStack count] >= kNotificationStackSize) {
            [self.notificationStack removeObjectAtIndex:0]; // remove oldest
        }
    }
}

- (void)sendToken:(NSString *)token {
    if (self.tokenRefreshCallbackId != nil) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
    }
}

- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:1];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];

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
    [self sendNotification:remoteMessage.appData];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    NSDictionary *userInfo = notification.request.content.userInfo;
    [self sendNotification:userInfo];

    // Present the notification in the foreground (system default behavior)
    completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionSound);
    // Use UNNotificationPresentationOptionNone to suppress system presentation and handle fully in JS
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    NSDictionary *userInfo = response.notification.request.content.userInfo;
    [self sendNotification:userInfo];

    completionHandler();
}

//
// Analytics
//
- (void)setAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command {
    BOOL enabled = [[command argumentAtIndex:0] boolValue];
    [FIRAnalytics setAnalyticsCollectionEnabled:enabled];
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSDictionary *parameters;
        @try {
            NSString *description = NSLocalizedString([command argumentAtIndex:1 withDefault:@"No Message Provided"], nil);
            parameters = @{ NSLocalizedDescriptionKey: description };
        }
        @catch (NSException *exception) {
            parameters = [command argumentAtIndex:1];
        }

        [FIRAnalytics logEventWithName:name parameters:parameters];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setScreenName:(CDVInvokedUrlCommand *)command {
    NSString* name = [command.arguments objectAtIndex:0];
    [FIRAnalytics logEventWithName:kFIREventScreenView
                        parameters:@{kFIRParameterScreenName: name,
                                     kFIRParameterScreenClass: @"<unknown>"}];

    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* id = [command.arguments objectAtIndex:0];

        [FIRAnalytics setUserID:id];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString* name = [command.arguments objectAtIndex:0];
        NSString* value = [command.arguments objectAtIndex:1];

        [FIRAnalytics setUserPropertyString:value forName:name];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end