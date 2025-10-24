#import "FirebasePlugin.h"
@import FirebaseMessaging;
@import FirebaseAnalytics;
@import UserNotifications;

static NSInteger const kNotificationStackSize = 10;
static FirebasePlugin *firebasePlugin;

@implementation FirebasePlugin
@synthesize notificationCallbackId, tokenRefreshCallbackId, notificationStack, traces;

+ (FirebasePlugin *)firebasePlugin {
    return firebasePlugin;
}

- (void)pluginInitialize {
    NSLog(@"FirebasePlugin - Starting Firebase plugin");
    firebasePlugin = self;
    [FIRMessaging messaging].delegate = self; // FIRApp.configure acontece no AppDelegate
}

#pragma mark - Notifications

- (void)getId:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error
            ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription]
            : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token ?: @""];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getToken:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error
            ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription]
            : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token ?: @""];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)hasPermission:(CDVInvokedUrlCommand *)command {
    if ([UNUserNotificationCenter class]) {
        [[UNUserNotificationCenter currentNotificationCenter]
            getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings * _Nonnull settings) {

            BOOL enabled = (settings.authorizationStatus == UNAuthorizationStatusAuthorized
                         || settings.authorizationStatus == UNAuthorizationStatusProvisional);

            CDVPluginResult *result =
                [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                               messageAsDictionary:@{ @"isEnabled": @(enabled) }];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }];
    } else {
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
        CDVPluginResult *result =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                           messageAsDictionary:@{ @"isEnabled": @(enabled) }];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)grantPermission:(CDVInvokedUrlCommand *)command {
    if ([UNUserNotificationCenter class]) {
        [UNUserNotificationCenter currentNotificationCenter].delegate = self;
        UNAuthorizationOptions authOptions = (UNAuthorizationOptionAlert |
                                              UNAuthorizationOptionSound |
                                              UNAuthorizationOptionBadge);
        [[UNUserNotificationCenter currentNotificationCenter]
            requestAuthorizationWithOptions:authOptions
            completionHandler:^(BOOL granted, NSError * _Nullable error) {
                NSMutableDictionary *payload = [@{ @"granted": @(granted) } mutableCopy];
                if (error) payload[@"error"] = error.localizedDescription ?: @"";
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] registerForRemoteNotifications];
                    });
                }
                CDVPluginResult *pluginResult =
                    [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:payload];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }];
    } else {
        UIUserNotificationType allTypes = (UIUserNotificationTypeSound |
                                           UIUserNotificationTypeAlert |
                                           UIUserNotificationTypeBadge);
        UIUserNotificationSettings *settings =
            [UIUserNotificationSettings settingsForTypes:allTypes categories:nil];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        CDVPluginResult *pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:@{ @"granted": @YES }];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command {
    NSInteger number = [[command.arguments objectAtIndex:0] integerValue];
    [self.commandDelegate runInBackground:^{
        [UIApplication sharedApplication].applicationIconBadgeNumber = number;
        [self.commandDelegate sendPluginResult:
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    }];
}

- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSInteger badge = [UIApplication sharedApplication].applicationIconBadgeNumber;
        [self.commandDelegate sendPluginResult:
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:(double)badge]
                                     callbackId:command.callbackId];
    }];
}

// *** Sem "/topics/" — apenas o nome do tópico
- (void)subscribe:(CDVInvokedUrlCommand *)command {
    NSString *topic = [command.arguments objectAtIndex:0];
    [[FIRMessaging messaging] subscribeToTopic:topic completion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error
            ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription]
            : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unsubscribe:(CDVInvokedUrlCommand *)command {
    NSString *topic = [command.arguments objectAtIndex:0];
    [[FIRMessaging messaging] unsubscribeFromTopic:topic completion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error
            ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription]
            : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)unregister:(CDVInvokedUrlCommand *)command {
    [[FIRMessaging messaging] deleteTokenWithCompletion:^(NSError * _Nullable error) {
        CDVPluginResult *pluginResult = error
            ? [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription]
            : [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command {
    self.notificationCallbackId = command.callbackId;
    if (self.notificationStack.count) {
        for (NSDictionary *userInfo in self.notificationStack) {
            [self sendNotification:userInfo];
        }
        [self.notificationStack removeAllObjects];
    }
}

- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command {
    self.tokenRefreshCallbackId = command.callbackId;
    [[FIRMessaging messaging] tokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (!error && token) { [self sendToken:token]; }
    }];
}

- (void)sendNotification:(NSDictionary *)userInfo {
    if (self.notificationCallbackId) {
        NSMutableDictionary *payload = [userInfo mutableCopy];
        if (!payload[@"FromPushNotification"]) payload[@"FromPushNotification"] = @"true";
        CDVPluginResult *pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:payload];
        pluginResult.keepCallback = @YES;
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.notificationCallbackId];
    } else {
        if (!self.notificationStack) self.notificationStack = [NSMutableArray array];
        [self.notificationStack addObject:[userInfo mutableCopy]];
        if (self.notificationStack.count >= kNotificationStackSize) {
            [self.notificationStack removeObjectAtIndex:0];
        }
    }
}

- (void)sendToken:(NSString *)token {
    if (self.tokenRefreshCallbackId && token) {
        CDVPluginResult *pluginResult =
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:token];
        pluginResult.keepCallback = @YES;
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.tokenRefreshCallbackId];
    }
}

#pragma mark - FIRMessagingDelegate

- (void)messaging:(FIRMessaging *)messaging didReceiveRegistrationToken:(NSString *)fcmToken {
    NSLog(@"FirebasePlugin - FCM registration token refreshed: %@", fcmToken);
    if (fcmToken) { [self sendToken:fcmToken]; }
}

// (Opcional) Antigo canal direto removido: -messaging:didReceiveMessage:

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSMutableDictionary *payload = [notification.request.content.userInfo mutableCopy];
    payload[@"FromPushNotification"] = @"true";
    payload[@"wasTapped"] = @(NO);
    NSLog(@"FirebasePlugin - Foreground notification: %@", payload);
    [self sendNotification:payload];
    completionHandler(UNNotificationPresentationOptionAlert |
                      UNNotificationPresentationOptionSound |
                      UNNotificationPresentationOptionBadge);
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
    [self.commandDelegate sendPluginResult:
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

- (void)logEvent:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString *name = [command.arguments objectAtIndex:0];
        NSDictionary *parameters = nil;
        @try {
            parameters = [command argumentAtIndex:1];
            if (!parameters) {
                NSString *desc = [command argumentAtIndex:1 withDefault:@"No Message Provided"];
                parameters = @{ NSLocalizedDescriptionKey: desc };
            }
        } @catch (NSException *exception) {
            NSLog(@"FirebasePlugin - Error parsing logEvent parameters: %@", exception);
            parameters = @{ NSLocalizedDescriptionKey: @"Invalid parameters" };
        }
        [FIRAnalytics logEventWithName:name parameters:parameters];
        [self.commandDelegate sendPluginResult:
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    }];
}

- (void)setScreenName:(CDVInvokedUrlCommand *)command {
    NSString *name = [command.arguments objectAtIndex:0];
    if (name) {
        [FIRAnalytics logEventWithName:kFIREventScreenView
                             parameters:@{ kFIRParameterScreenName: name,
                                           kFIRParameterScreenClass: @"CordovaViewController" }];
    }
    [self.commandDelegate sendPluginResult:
        [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [FIRAnalytics setUserID:[command.arguments objectAtIndex:0]];
        [self.commandDelegate sendPluginResult:
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    }];
}

- (void)setUserProperty:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString *name = [command.arguments objectAtIndex:0];
        NSString *value = [command.arguments objectAtIndex:1];
        if (name && value) [FIRAnalytics setUserPropertyString:value forName:name];
        [self.commandDelegate sendPluginResult:
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    }];
}

- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
        if ([UNUserNotificationCenter class]) {
            [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
        }
        [self.commandDelegate sendPluginResult:
            [CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    }];
}

@end