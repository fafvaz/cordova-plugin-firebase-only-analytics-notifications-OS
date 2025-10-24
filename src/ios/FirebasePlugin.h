#import <Cordova/CDV.h>
@import UserNotifications;
@import FirebaseMessaging;
@import FirebaseAnalytics;

@interface FirebasePlugin : CDVPlugin <UNUserNotificationCenterDelegate, FIRMessagingDelegate>

+ (FirebasePlugin *)firebasePlugin;

- (void)getId:(CDVInvokedUrlCommand *)command;
- (void)getToken:(CDVInvokedUrlCommand *)command;
- (void)hasPermission:(CDVInvokedUrlCommand *)command;
- (void)grantPermission:(CDVInvokedUrlCommand *)command;
- (void)setBadgeNumber:(CDVInvokedUrlCommand *)command;
- (void)getBadgeNumber:(CDVInvokedUrlCommand *)command;
- (void)subscribe:(CDVInvokedUrlCommand *)command;
- (void)unsubscribe:(CDVInvokedUrlCommand *)command;
- (void)unregister:(CDVInvokedUrlCommand *)command;
- (void)onNotificationOpen:(CDVInvokedUrlCommand *)command;
- (void)onTokenRefresh:(CDVInvokedUrlCommand *)command;
- (void)sendNotification:(NSDictionary *)userInfo;
- (void)sendToken:(NSString *)token;

// Analytics
- (void)logEvent:(CDVInvokedUrlCommand *)command;
- (void)setScreenName:(CDVInvokedUrlCommand *)command;
- (void)setUserId:(CDVInvokedUrlCommand *)command;
- (void)setUserProperty:(CDVInvokedUrlCommand *)command;
- (void)setAnalyticsCollectionEnabled:(CDVInvokedUrlCommand *)command;

// Utils
- (void)clearAllNotifications:(CDVInvokedUrlCommand *)command;

@property (nonatomic, copy)   NSString *notificationCallbackId;
@property (nonatomic, copy)   NSString *tokenRefreshCallbackId;
@property (nonatomic, strong) NSMutableArray *notificationStack;
@property (nonatomic, strong) NSMutableDictionary *traces;

@end
``