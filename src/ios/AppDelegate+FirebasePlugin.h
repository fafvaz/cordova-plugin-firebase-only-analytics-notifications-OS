#import <Cordova/CDV.h>
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate (FirebasePlugin)

@property (nonatomic, strong, nullable) NSNumber *applicationInBackground;

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@property (nonatomic, nullable, weak) id<UNUserNotificationCenterDelegate> delegate;
#endif

@end