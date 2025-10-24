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

- (BOOL)application:(UIApplication *)application
swizzledDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSLog(@"FirebasePlugin - Finished launching");

    // 1) Configure Firebase o mais cedo possível
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [FIRApp configure];
    });

    // 2) Central de notificações (iOS 10+) + delegate
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = (id<UNUserNotificationCenterDelegate>)self;

    // 3) Solicitar autorização (alerta, som, badge)
    UNAuthorizationOptions options = (UNAuthorizationOptionAlert |
                                      UNAuthorizationOptionSound |
                                      UNAuthorizationOptionBadge);
    [center requestAuthorizationWithOptions:options
                          completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (error) {
            NSLog(@"FirebasePlugin - Erro ao solicitar autorização de push: %@", error);
        }
        if (granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            });
        } else {
            NSLog(@"FirebasePlugin - Permissão de push negada pelo usuário");
        }
    }];

    // 4) Messaging delegate para token FCM e mensagens de dados
    [FIRMessaging messaging].delegate = (id<FIRMessagingDelegate>)self;

    // 5) Estado inicial: em background até o app ficar ativo
    self.applicationInBackground = @(YES);

    // Chama a implementação original (depois da configuração acima)
    return [self application:application swizzledDidFinishLaunchingWithOptions:launchOptions];
}

#pragma mark - FIRMessagingDelegate (token FCM moderno)

- (void)messaging:(FIRMessaging *)messaging
didReceiveRegistrationToken:(NSString *)fcmToken {
    if (fcmToken.length > 0) {
        NSLog(@"FirebasePlugin - Token FCM atualizado: %@", fcmToken);
        [FirebasePlugin.firebasePlugin sendToken:fcmToken];
    } else {
        NSLog(@"FirebasePlugin - Token FCM vazio/indisponível");
    }
}

#pragma mark - App lifecycle

- (void)applicationDidBecomeActive:(UIApplication *)application {
    self.applicationInBackground = @(NO);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    self.applicationInBackground = @(YES);
}

#pragma mark - APNs

- (void)application:(UIApplication *)application
didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    // O Firebase usará esse APNs token para mapear o FCM token
    [FIRMessaging messaging].APNSToken = deviceToken;
}

#pragma mark - Recebimento de notificações

// iOS 10+: app em primeiro plano
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {

    NSDictionary *userInfo = notification.request.content.userInfo;

    // Marcar que veio de push e foi "apresentada"
    NSMutableDictionary *userInfoMutable = [userInfo mutableCopy];
    userInfoMutable[@"FromPushNotification"] = @"true";

    // Notifica JS (evento "recebida" com app em foreground)
    [self handleRemoteNotification:userInfoMutable clickOpen:@"false"];

    // Apresentação visual enquanto em foreground
    UNNotificationPresentationOptions opts =
        (UNNotificationPresentationOptionAlert |
         UNNotificationPresentationOptionSound |
         UNNotificationPresentationOptionBadge);
    completionHandler(opts);
}

// iOS 10+: clique/ação do usuário na notificação
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
 didReceiveNotificationResponse:(UNNotificationResponse *)response
          withCompletionHandler:(void (^)(void))completionHandler {

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSMutableDictionary *userInfoMutable = [userInfo mutableCopy];
    userInfoMutable[@"FromPushNotification"] = @"true";

    [self handleRemoteNotification:userInfoMutable clickOpen:@"true"];
    completionHandler();
}

// iOS 7–9 e/ou mensagens silenciosas com fetch
- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self handleRemoteNotification:userInfo clickOpen:@"false"];
}

- (void)application:(UIApplication *)application
didReceiveRemoteNotification:(NSDictionary *)userInfo
fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    [self handleRemoteNotification:userInfo clickOpen:@"false"];
    completionHandler(UIBackgroundFetchResultNewData);
}

#pragma mark - Encaminhamento unificado

- (void)handleRemoteNotification:(NSDictionary *)userInfo clickOpen:(NSString *)clickOpen {
    NSLog(@"FirebasePlugin - Received remote notification: %@", userInfo);

    BOOL isInBackground = [self.applicationInBackground boolValue];
    if (isInBackground) {
        NSLog(@"FirebasePlugin - App in background, received remote notification");
    } else {
        NSLog(@"FirebasePlugin - App in foreground, received remote notification");
    }

    NSMutableDictionary *payload = [userInfo mutableCopy];
    payload[@"FromPushNotification"] = ([clickOpen isEqualToString:@"true"] ? @"true" : @"false");

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    if ([clickOpen isEqualToString:@"true"]) {
        [nc postNotificationName:@"FirebaseRemoteNotificationClickedDispatch" object:payload];
    } else {
        [nc postNotificationName:@"FirebaseRemoteNotificationReceivedDispatch" object:payload];
    }

    [FirebasePlugin.firebasePlugin sendNotification:payload];
}

#pragma mark - Associated object (background flag)

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, @selector(applicationInBackground));
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, @selector(applicationInBackground),
                             applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end