# cordova-plugin-firebase
This plugin brings push notifications, analytics, event tracking, crash reporting and more from Google Firebase to your Cordova project.
Android and iOS supported.

## MABS Compatibility (OutSystems)
This plugin version (0.3.1+) is built for **OutSystems MABS 11 and MABS 12.x**:

* No `compileSdkVersion` or Android Gradle Plugin overrides (MABS owns the toolchain: Gradle 8 / AGP 8 / Java 17, compileSdk 34+).
* `com.google.gms:google-services` **4.5.0** (applied via `cdvPluginPostBuildExtras`).
* Android: Firebase **Analytics 22.0.2**, **Messaging 24.0.3**, **Config 22.0.1**, **Performance 21.0.4**, **Dynamic Links 22.1.0**, **Auth 23.0.0**, **Crashlytics 19.0.3**.
  These are the newest Firebase Android versions whose Kotlin metadata (≤ 2.0) can be read by MABS 12.1's Kotlin 1.9 compiler. Firebase artifacts published after Nov 2024 (e.g. analytics 22.5.0, auth 23.2.1) are compiled with Kotlin 2.1 and fail `kaptGenerateStubsDebugKotlin` with "metadata is 2.1.0, expected version is 1.9.0" — do not upgrade beyond these pins until MABS ships Kotlin 2.1+.
* iOS: pods `Firebase/Analytics` and `Firebase/Messaging` **~> 10.29.0** (last Firebase 10.x, Xcode 16-ready).
  Why 10.x and not 11/12: apps that include GoogleSignIn-based plugins pin `GoogleUtilities ~> 7.13.0` in the Podfile (MABS pods.json), and **all Firebase iOS 11.x releases require `GoogleUtilities ~> 8.0`** — `pod install` then fails with "CocoaPods could not find compatible versions for pod GoogleUtilities/MethodSwizzler". FirebaseAnalytics 10.29.0 requires `GoogleUtilities ~> 7.11`, which resolves cleanly to 7.13.3. If the app ever upgrades to GoogleSignIn 8.x (GoogleUtilities 8.x), Firebase iOS 11/12 can be adopted.
* The legacy Fabric Crashlytics SDK (`com.crashlytics.android` / `io.fabric`) and its Gradle plugin/hooks were removed; crash reporting now uses the modern `FirebaseCrashlytics` API. The native actions `logError`, `forceCrashlytics` and `setCrashlyticsUserId` are still dispatched on Android (their JS wrappers are commented out in `www/firebase.js`, so call them via `cordova.exec` if you need them).
* `FirebaseCrashlytics.crash()` was **removed in Crashlytics 19.0.0** (the version pinned here is 19.0.3), which is why MABS 12.1 failed with `error: cannot find symbol ... method crash()`. `forceCrashlytics` now throws an uncaught `RuntimeException` on the UI thread instead, which is the supported way to force a fatal crash and is still recorded and reported by Crashlytics.
* **Crashlytics 19.x also crashes the app at startup unless the Crashlytics *Gradle* plugin is applied**, which MABS builds never do (MABS owns the Gradle toolchain and only google-services is wired up). `FirebaseInitProvider` throws before any Cordova code runs:
  `java.lang.RuntimeException: Unable to get provider com.google.firebase.provider.FirebaseInitProvider: java.lang.IllegalStateException: The Crashlytics build ID is missing. This occurs when the Crashlytics Gradle plugin is missing from your app's build configuration.`
  The build ID is the R8 mapping-file id, generated only by `com.google.firebase:firebase-crashlytics-gradle`, so `src/android/cordova-plugin-firebase-crashlytics.xml` ships `<bool name="com.crashlytics.RequireBuildId">false</bool>` into `app/src/main/res/values/`. `CrashlyticsCore.onPreExecute()` reads exactly that resource (verified with `javap` on the 19.0.3 AAR: `CommonUtils.getBooleanResourceValue(context, "com.crashlytics.RequireBuildId", true)` → `isBuildIdValid()` returns `true` and logs *"Configured not to require a build ID."*), so Crashlytics initializes without a build ID and Analytics/FCM/Remote Config/Performance plus `recordException()`/`log()`/`setUserId()` keep working. Crash reports are still recorded and uploaded, but they are **not symbolicated** (no mapping file id). If a MABS build ever applies the Crashlytics Gradle plugin, delete that resource file to avoid a duplicate-resource error and to regain full build-ID + mapping support (see the commented block in `src/android/build.gradle`).

### Coexistence with the Adobe plugin
Tested/compatible with the OutSystems Forge **Adobe Experience Platform Connector** (v1.0.2 — ACPCore/ACPAnalytics/ACPTarget). The Adobe connector adds no manifest receivers/services and does not swizzle the app delegate, so it does not conflict with this plugin's FCM message service or notification delegate handling. Note that Adobe's ACP mobile SDKs are deprecated by Adobe; plan a migration to the AEPSDK (Edge) if Adobe analytics is strategic.


## Firebase Configuration Files
1) Download your Firebase configuration files, GoogleService-Info.plist for ios and google-services.json for android.
2) Create a zipped folder with the name "google-services.zip" and put both configuration files inside.
3) On the "www" folder, create a folder called <YourAppIdentifier> + ".firebase" and place the zip inside.

```
- My Project/
    config.xml
    platforms/
    plugins/
    www/
        com.example.application.appid.firebase/
            google-services.zip/
                google-services.json        <--
                GoogleService-Info.plist    <--
```

See https://support.google.com/firebase/answer/7015592 for details how to download the files from firebase.

This plugin uses a hook (before plugin install) that copies the configuration files to the right place, namely platforms/ios/\<My Project\>/Resources for ios and platforms/android for android.

**Note that the Firebase SDK requires the configuration files to be present and valid, otherwise your app will crash on boot or Firebase features won't work.**

## Push Notification Custom Sound
1) Have your sound files ready with the correct extension (.wav, .mp3 for Android / .wav, .caf for iOS) and rename them "push_sound".
2) Prepare a zipped folder called "push_sound.zip" with the sound files.
3) Add the zip folder to the "www" folder.

```
- My Project/
    platforms/
    plugins/
    www/
        push_sound.zip/
            push_sound.wav      <--
            push_sound.caf      <--
```

## Methods

### getToken

Get the device token (id):
```
window.FirebasePlugin.getToken(function(token) {
    // save this server-side and use it to push notifications to this device
    console.log(token);
}, function(error) {
    console.error(error);
});
```
Note that token will be null if it has not been established yet

### onTokenRefresh

Register for token changes:
```
window.FirebasePlugin.onTokenRefresh(function(token) {
    // save this server-side and use it to push notifications to this device
    console.log(token);
}, function(error) {
    console.error(error);
});
```
This is the best way to get a valid token for the device as soon as the token is established

### onNotificationOpen

Register notification callback:
```
window.FirebasePlugin.onNotificationOpen(function(notification) {
    console.log(notification);
}, function(error) {
    console.error(error);
});
```
Notification flow:

1. App is in foreground:
    1. User receives the notification data in the JavaScript callback without any notification on the device itself (this is the normal behaviour of push notifications, it is up to you, the developer, to notify the user)
2. App is in background:
    1. User receives the notification message in its device notification bar
    2. User taps the notification and the app opens
    3. User receives the notification data in the JavaScript callback

Notification icon on Android:

[Changing notification icon](#changing-notification-icon)

### grantPermission (iOS only)

Grant permission to recieve push notifications (will trigger prompt):
```
window.FirebasePlugin.grantPermission();
```
### hasPermission

Check permission to recieve push notifications:
```
window.FirebasePlugin.hasPermission(function(data){
    console.log(data.isEnabled);
});
```

### setBadgeNumber

Set a number on the icon badge:
```
window.FirebasePlugin.setBadgeNumber(3);
```

Set 0 to clear the badge
```
window.FirebasePlugin.setBadgeNumber(0);
```

### getBadgeNumber

Get icon badge number:
```
window.FirebasePlugin.getBadgeNumber(function(n) {
    console.log(n);
});
```

### subscribe

Subscribe to a topic:
```
window.FirebasePlugin.subscribe("example");
```

### unsubscribe

Unsubscribe from a topic:
```
window.FirebasePlugin.unsubscribe("example");
```

### unregister

Unregister from firebase, used to stop receiving push notifications. Call this when you logout user from your app. :
```
window.FirebasePlugin.unregister();
```

### logEvent

Log an event using Analytics:
```
window.FirebasePlugin.logEvent("select_content", {content_type: "page_view", item_id: "home"});
```

### setScreenName

Set the name of the current screen in Analytics:
```
window.FirebasePlugin.setScreenName("Home");
```

### setUserId

Set a user id for use in Analytics:
```
window.FirebasePlugin.setUserId("user_id");
```

### setUserProperty

Set a user property for use in Analytics:
```
window.FirebasePlugin.setUserProperty("name", "value");
```

### verifyPhoneNumber

Request a verification ID and send a SMS with a verification code. Use them to construct a credential to sign in the user (in your app).
- https://firebase.google.com/docs/auth/android/phone-auth
- https://firebase.google.com/docs/reference/js/firebase.auth.Auth#signInWithCredential
- https://firebase.google.com/docs/reference/js/firebase.User#linkWithCredential

**NOTE: This will only works on physical devices.**

iOS will return: credential (string)
Android will return: 
credential.verificationId (object and with key verificationId)
credential.instantVerification (boolean)

You need to use device plugin in order to access the right key. 

IMPORTANT NOTE: Android supports auto-verify and instant device verification. Therefore in that cases it doesn't make sense to ask for sms code as you won't receive any. Also, **verificationId** will be *false* in this case. In order to sign the user in you need to check **credential.instantVerification**, if it's true, skip the SMS Code entry, call your backend server (sorry, the only way to succeed with this plugin) and pass over the phonenumber as param to identify the user (via ajax for example, using any endpoint to your backend).

When using node.js Firebase Admin-SDK, follow this tutorial:
- https://firebase.google.com/docs/auth/admin/create-custom-tokens

Pass back your custom generated token and call 
```js 
firebase.auth().signInWithCustomToken(customTokenFromYourServer);
```
instead of 
```
firebase.auth().signInWithCredential(credential)
```
**YOU HAVE TO COVER THIS PROCESS, OR YOU WILL HAVE ABOUT 5% OF USERS STUCKING AT YOUR SCREEN, NO RECEIVING ANYTHING**
If this process is too complex for you, use this awesome plugin
- https://github.com/chemerisuk/cordova-plugin-firebase-authentication

It's not perfect but it fits for the most usecases and doesn't require to call your endpoint, as it has native phone auth support.

```
window.FirebasePlugin.verifyPhoneNumber(number, timeOutDuration, function(credential) {
    console.log(credential);

    // ask user to input verificationCode:
    var code = inputField.value.toString();

    var verificationId = credential.verificationId;

    var credential = firebase.auth.PhoneAuthProvider.credential(verificationId, code);

    // sign in with the credential
    firebase.auth().signInWithCredential(credential);
    
    // call if credential.instantVerification was true (android only)
    firebase.auth().signInWithCustomToken(customTokenFromYourServer);

    // OR link to an account
    firebase.auth().currentUser.linkWithCredential(credential)
}, function(error) {
    console.error(error);
});
```


#### Android
To use this auth you need to configure your app SHA hash in the android app configuration on firebase console.
See https://developers.google.com/android/guides/client-auth to know how to get SHA app hash.

#### iOS
Setup your push notifications first, and verify that they are arriving to your physical device before you test this method. Use the APNs auth key to generate the .p8 file and upload it to firebase.  When you call this method, FCM sends a silent push to the device to verify it.

### fetch

Fetch Remote Config parameter values for your app:
```
window.FirebasePlugin.fetch(function () {
    // success callback
}, function () {
    // error callback
});
// or, specify the cacheExpirationSeconds
window.FirebasePlugin.fetch(600, function () {
    // success callback
}, function () {
    // error callback
});
```

### activateFetched

Activate the Remote Config fetched config:
```
window.FirebasePlugin.activateFetched(function(activated) {
    // activated will be true if there was a fetched config activated,
    // or false if no fetched config was found, or the fetched config was already activated.
    console.log(activated);
}, function(error) {
    console.error(error);
});
```

### getValue

Retrieve a Remote Config value:
```
window.FirebasePlugin.getValue("key", function(value) {
    console.log(value);
}, function(error) {
    console.error(error);
});
// or, specify a namespace for the config value
window.FirebasePlugin.getValue("key", "namespace", function(value) {
    console.log(value);
}, function(error) {
    console.error(error);
});
```

### getByteArray (Android only)
**NOTE: byte array is only available for SDK 19+**
Retrieve a Remote Config byte array:
```
window.FirebasePlugin.getByteArray("key", function(bytes) {
    // a Base64 encoded string that represents the value for "key"
    console.log(bytes.base64);
    // a numeric array containing the values of the byte array (i.e. [0xFF, 0x00])
    console.log(bytes.array);
}, function(error) {
    console.error(error);
});
// or, specify a namespace for the byte array
window.FirebasePlugin.getByteArray("key", "namespace", function(bytes) {
    // a Base64 encoded string that represents the value for "key"
    console.log(bytes.base64);
    // a numeric array containing the values of the byte array (i.e. [0xFF, 0x00])
    console.log(bytes.array);
}, function(error) {
    console.error(error);
});
```

### getInfo (Android only)

Get the current state of the FirebaseRemoteConfig singleton object:
```
window.FirebasePlugin.getInfo(function(info) {
    // the status of the developer mode setting (true/false)
    console.log(info.configSettings.developerModeEnabled);
    // the timestamp (milliseconds since epoch) of the last successful fetch
    console.log(info.fetchTimeMillis);
    // the status of the most recent fetch attempt (int)
    // 0 = Config has never been fetched.
    // 1 = Config fetch succeeded.
    // 2 = Config fetch failed.
    // 3 = Config fetch was throttled.
    console.log(info.lastFetchStatus);
}, function(error) {
    console.error(error);
});
```

### setConfigSettings (Android only)

Change the settings for the FirebaseRemoteConfig object's operations:
```
var settings = {
    developerModeEnabled: true
}
window.FirebasePlugin.setConfigSettings(settings);
```

### setDefaults (Android only)

Set defaults in the Remote Config:
```
// define defaults
var defaults = {
    // map property name to value in Remote Config defaults
    mLong: 1000,
    mString: 'hello world',
    mDouble: 3.14,
    mBoolean: true,
    // map "mBase64" to a Remote Config byte array represented by a Base64 string
    // Note: the Base64 string is in an array in order to differentiate from a string config value
    mBase64: ["SGVsbG8gV29ybGQ="],
    // map "mBytes" to a Remote Config byte array represented by a numeric array
    mBytes: [0xFF, 0x00]
}
// set defaults
window.FirebasePlugin.setDefaults(defaults);
// or, specify a namespace
window.FirebasePlugin.setDefaults(defaults, "namespace");
```

### startTrace

Start a trace.

```
window.FirebasePlugin.startTrace("test trace", success, error);
```

### incrementCounter

To count the performance-related events that occur in your app (such as cache hits or retries), add a line of code similar to the following whenever the event occurs, using a string other than retry to name that event if you are counting a different type of event:

```
window.FirebasePlugin.incrementCounter("test trace", "retry", success, error);
```

### stopTrace

Stop the trace

```
window.FirebasePlugin.stopTrace("test trace");
```
 
### setAnalyticsCollectionEnabled

Enable/disable analytics collection

```
window.FirebasePlugin.setAnalyticsCollectionEnabled(true); // Enables analytics collection

window.FirebasePlugin.setAnalyticsCollectionEnabled(false); // Disables analytics collection
```

## Google Tag Manager
### Android
Download your container-config json file from Tag Manager and add a resource-file node in your config.xml.
```
....
<platform name="android">
        <content src="index.html" />
        <resource-file src="GTM-5MFXXXX.json" target="assets/containers/GTM-5MFXXXX.json" />
        ...
```

## Changing Notification Icon
The plugin will use notification_icon from drawable resources if it exists, otherwise the default app icon will is used.
To set a big icon and small icon for notifications, define them through drawable nodes.  
Create the required styles.xml files and add the icons to the  
`<projectroot>/res/native/android/res/<drawable-DPI>` folders.  

The example below uses a png named "ic_silhouette.png", the app Icon (@mipmap/icon) and sets a base theme.  
From android version 21 (Lollipop) notifications were changed, needing a seperate setting.  
If you only target Lollipop and above, you don't need to setup both.  
Thankfully using the version dependant asset selections, we can make one build/apk supporting all target platforms.  
`<projectroot>/res/native/android/res/values/styles.xml`
```
<?xml version="1.0" encoding="utf-8" ?>
<resources>
    <!-- inherit from the holo theme -->
    <style name="AppTheme" parent="android:Theme.Light">
        <item name="android:windowDisablePreview">true</item>
    </style>
    <drawable name="notification_big">@mipmap/icon</drawable>
    <drawable name="notification_icon">@mipmap/icon</drawable>
</resources>
```
and  
`<projectroot>/res/native/android/res/values-v21/styles.xml`
```
<?xml version="1.0" encoding="utf-8" ?>
<resources>
    <!-- inherit from the material theme -->
    <style name="AppTheme" parent="android:Theme.Material">
        <item name="android:windowDisablePreview">true</item>
    </style>
    <drawable name="notification_big">@mipmap/icon</drawable>
    <drawable name="notification_icon">@drawable/ic_silhouette</drawable>
</resources>
```

## Notification Colors

On Android Lollipop and above you can also set the accent color for the notification by adding a color setting.

`<projectroot>/res/native/android/res/values/colors.xml`
```
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FFFFFF00</color>
    <color name="primary_dark">#FF220022</color>
    <color name="accent">#FF00FFFF</color>
</resources>
```
