package org.apache.cordova.firebase;

import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.core.app.NotificationManagerCompat;

import java.util.UUID; // Para gerar o UUID
import org.apache.cordova.CallbackContext; // Para trabalhar com o CallbackContext do Cordova
import org.apache.cordova.CordovaInterface; // Se você estiver usando o CordovaInterface
import org.apache.cordova.CordovaWebView; // Se você estiver usando o CordovaWebView
import android.util.Log; // Para logging
import com.crashlytics.android.Crashlytics; // Se você estiver usando Crashlytics


//import android.support.annotation.NonNull;
//import android.support.v4.app.NotificationManagerCompat;
import android.text.TextUtils;
import android.util.Base64;
import android.util.Log;
import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.analytics.FirebaseAnalytics;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.remoteconfig.FirebaseRemoteConfig;
import com.google.firebase.remoteconfig.FirebaseRemoteConfigInfo;
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings;
import com.google.firebase.remoteconfig.FirebaseRemoteConfigValue;
import com.google.firebase.perf.FirebasePerformance;
import com.google.firebase.perf.metrics.Trace;
import me.leolin.shortcutbadger.ShortcutBadger;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.Manifest;
import android.content.pm.PackageManager;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PermissionHelper;
import org.json.JSONArray;
import org.json.JSONException;

import java.util.Arrays;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

// Firebase PhoneAuth
import java.util.concurrent.TimeUnit;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.AuthResult;
import com.google.firebase.FirebaseException;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseAuthInvalidCredentialsException;
import com.google.firebase.FirebaseTooManyRequestsException;
import com.google.firebase.auth.PhoneAuthCredential;
import com.google.firebase.auth.PhoneAuthProvider;

// Crashlytics
import com.crashlytics.android.Crashlytics;
import io.fabric.sdk.android.Fabric;

// Dynamic Links
import com.google.firebase.dynamiclinks.DynamicLink;
import com.google.firebase.dynamiclinks.FirebaseDynamicLinks;
import com.google.firebase.dynamiclinks.PendingDynamicLinkData;

public class FirebasePlugin extends CordovaPlugin {

  private FirebaseAnalytics mFirebaseAnalytics;
  private static final String TAG = "FirebasePlugin";
  protected static final String KEY = "badge";
  private static final String[]  POST_NOTIFICATION = {"android.permission.POST_NOTIFICATIONS"};
  private static final int REQUEST_CODE_ENABLE_PERMISSION = 1695;

  private static boolean inBackground = true;
  private static ArrayList<Bundle> notificationStack = null;
  private static CallbackContext notificationCallbackContext;
  private static CallbackContext tokenRefreshCallbackContext;
  private static CallbackContext dynamicLinkCallback;
  private CallbackContext callbackContext;
  

  @Override
  protected void pluginInitialize() {
    final Context context = this.cordova.getActivity().getApplicationContext();
    final Bundle extras = this.cordova.getActivity().getIntent().getExtras();
    this.cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        Log.d(TAG, "Starting Firebase plugin");
        mFirebaseAnalytics = FirebaseAnalytics.getInstance(context);
        mFirebaseAnalytics.setAnalyticsCollectionEnabled(true);
        if (extras != null && extras.size() > 1) {
          if (FirebasePlugin.notificationStack == null) {
            FirebasePlugin.notificationStack = new ArrayList<Bundle>();
          }
          if (extras.containsKey("google.message_id")) {
            extras.putBoolean("tap", true);
            notificationStack.add(extras);
          }
        }
      }
    });
  }

  @Override
  public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
    if (action.equals("getId")) {
      this.getId(callbackContext);
      return true;      
    } else if (action.equals("getToken")) {
        this.getToken(callbackContext);
        return true;
    } else if (action.equals("getPushNotificationStatus")) {
       this.getPushNotificationStatus(callbackContext);
      return true;
    } else if (action.equals("hasPermission")) {
      this.hasPermission(callbackContext);
      return true;
    } else if (action.equals("setBadgeNumber")) {
      this.setBadgeNumber(callbackContext, args.getInt(0));
      return true;
    } else if (action.equals("getBadgeNumber")) {
      this.getBadgeNumber(callbackContext);
      return true;
    } else if (action.equals("subscribe")) {
      this.subscribe(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("requestPermissions")) {
      
      cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
           
          requestPermissions(callbackContext);
        } catch (Exception e) {
          
          callbackContext.error(e.getMessage());
        }
      }
    });
       
      return true;
    } else if (action.equals("unsubscribe")) {
      this.unsubscribe(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("unregister")) {
      this.unregister(callbackContext);
      return true;
    } else if (action.equals("onNotificationOpen")) {
      this.onNotificationOpen(callbackContext);
      return true;
    } else if (action.equals("onTokenRefresh")) {
      this.onTokenRefresh(callbackContext);
      return true;
    } else if (action.equals("logEvent")) {
      this.logEvent(callbackContext, args.getString(0), args.getJSONObject(1));
      return true;
    } else if (action.equals("logError")) {
      this.logError(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("setCrashlyticsUserId")) {
      this.setCrashlyticsUserId(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("setScreenName")) {
      this.setScreenName(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("setUserId")) {
      this.setUserId(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("setUserProperty")) {
      this.setUserProperty(callbackContext, args.getString(0), args.getString(1));
      return true;
    } else if (action.equals("activateFetched")) {
      this.activateFetched(callbackContext);
      return true;
    } else if (action.equals("fetch")) {
      if (args.length() > 0) this.fetch(callbackContext, args.getLong(0));
      else this.fetch(callbackContext);
      return true;
    } else if (action.equals("getByteArray")) {
      this.getByteArray(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("getValue")) {
      this.getValue(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("getInfo")) {
      this.getInfo(callbackContext);
      return true;
    } else if (action.equals("setConfigSettings")) {
      this.setConfigSettings(callbackContext, args.getJSONObject(0));
      return true;
    } else if (action.equals("setDefaults")) {
      this.setDefaults(callbackContext, args.getJSONObject(0));
      return true;
    } else if (action.equals("startTrace")) {
      this.startTrace(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("incrementCounter")) {
      this.incrementCounter(callbackContext, args.getString(0), args.getString(1));
      return true;
    } else if (action.equals("stopTrace")) {
      this.stopTrace(callbackContext, args.getString(0));
      return true;
    } else if (action.equals("addTraceAttribute")) {
      this.addTraceAttribute(callbackContext, args.getString(0), args.getString(1), args.getString(2));
      return true;  
    } else if (action.equals("forceCrashlytics")) {
      this.forceCrashlytics(callbackContext);
      return true;
    } else if (action.equals("setPerformanceCollectionEnabled")) {
      this.setPerformanceCollectionEnabled(callbackContext, args.getBoolean(0));
      return true;
    } else if (action.equals("setAnalyticsCollectionEnabled")) {
      this.setAnalyticsCollectionEnabled(callbackContext, args.getBoolean(0));
      return true;
    } else if (action.equals("onDynamicLink")) {
      this.onDynamicLink(callbackContext);
      return true;
    } else if (action.equals("clearAllNotifications")) {
      this.clearAllNotifications(callbackContext);
      return true;
  }

    return false;
  }

  @Override
  public void onPause(boolean multitasking) {
    FirebasePlugin.inBackground = true;
  }

  @Override
  public void onResume(boolean multitasking) {
    FirebasePlugin.inBackground = false;
  }

  @Override
  public void onReset() {
    FirebasePlugin.notificationCallbackContext = null;
    FirebasePlugin.tokenRefreshCallbackContext = null;
  }

  @Override
  public void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    final Bundle data = intent.getExtras();
    if (this.dynamicLinkCallback != null) {
      respondWithDynamicLink(intent);
    }
    if (data != null && data.containsKey("google.message_id")) {
      data.putBoolean("tap", true);
      FirebasePlugin.sendNotification(data, this.cordova.getActivity().getApplicationContext());
    }
  }

  public static boolean inBackground() {
    return FirebasePlugin.inBackground;
  }

  public static boolean hasNotificationsCallback() {
    return FirebasePlugin.notificationCallbackContext != null;
  }

  //
  // Cloud Messaging FCM
  //
  public static void sendNotification(Bundle bundle, Context context) {
    Log.d(TAG, "sendNotification called");
    if (!FirebasePlugin.hasNotificationsCallback()) {
      if (FirebasePlugin.notificationStack == null) {
        FirebasePlugin.notificationStack = new ArrayList<Bundle>();
      }
      notificationStack.add(bundle);

      Log.d(TAG, "sendNotification notificationStack.add");
      return;
    }

    final CallbackContext callbackContext = FirebasePlugin.notificationCallbackContext;
    if (callbackContext != null && bundle != null) {
      JSONObject json = new JSONObject();
      Set<String> keys = bundle.keySet();
      for (String key : keys) {
        try {
          json.put(key, bundle.get(key));
        } catch (JSONException e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
          return;
        }
      }

      PluginResult pluginresult = new PluginResult(PluginResult.Status.OK, json);
      pluginresult.setKeepCallback(true);
      callbackContext.sendPluginResult(pluginresult);
      Log.d(TAG, "sendNotification success");
    }
  }

  private void getPushNotificationStatus(final CallbackContext callbackContext) {
    cordova.getThreadPool().execute(() -> {
        try {
            NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(cordova.getActivity());
            callbackContext.success(String.valueOf(notificationManagerCompat.areNotificationsEnabled()));
        } catch (Exception e) {
            callbackContext.error(e.getMessage());
        }
    });
    }

  public static void sendToken(String token) {
    Log.d(TAG, "sendToken called");
    if (FirebasePlugin.tokenRefreshCallbackContext == null) {
      Log.d(TAG, "sendToken tokenRefreshCallbackContext null");
      return;
    }

    final CallbackContext callbackContext = FirebasePlugin.tokenRefreshCallbackContext;
    if (callbackContext != null && token != null) {
      PluginResult pluginresult = new PluginResult(PluginResult.Status.OK, token);
      pluginresult.setKeepCallback(true);
      callbackContext.sendPluginResult(pluginresult);
      Log.d(TAG, "sendToken success. token: " + token);
    }
  }

  private void onNotificationOpen(final CallbackContext callbackContext) {
    Log.d(TAG, "onNotificationOpen called");
    FirebasePlugin.notificationCallbackContext = callbackContext;
    if (FirebasePlugin.notificationStack != null) {
      for (Bundle bundle : FirebasePlugin.notificationStack) {
        FirebasePlugin.sendNotification(bundle, this.cordova.getActivity().getApplicationContext());
        Log.d(TAG, "onNotificationOpen sendNotification");
      }
      FirebasePlugin.notificationStack.clear();
      Log.d(TAG, "onNotificationOpen notificationStack.clear");
    }
  }

private void onTokenRefresh(final CallbackContext callbackContext) {
    Log.d(TAG, "onTokenRefresh called");
    FirebasePlugin.tokenRefreshCallbackContext = callbackContext;

    cordova.getThreadPool().execute(new Runnable() {
        public void run() {
            try {
                FirebaseMessaging.getInstance().getToken().addOnCompleteListener(new OnCompleteListener<String>() {
                    @Override
                    public void onComplete(@NonNull Task<String> task) {
                        if (!task.isSuccessful()) {
                            Log.w(TAG, "Fetching FCM registration token failed", task.getException());
                            callbackContext.error("Fetching FCM registration token failed");
                            return;
                        }

                        // Obtenha o token do FCM
                        String currentToken = task.getResult();
                        // Log e manipule o token conforme necessário
                        if (currentToken != null) {
                            FirebasePlugin.sendToken(currentToken);
                            Log.d(TAG, "onTokenRefresh success. token: " + currentToken);
                        }
                    }
                });
            } catch (Exception e) {
                Crashlytics.logException(e);
                callbackContext.error(e.getMessage());
            }
        }
    });
}


  private void getId(final CallbackContext callbackContext) {
    Log.d(TAG, "getUniqueId called");
    cordova.getThreadPool().execute(new Runnable() {
        public void run() {
            try {
                // Gerar um UUID único
                String uniqueID = UUID.randomUUID().toString();
                callbackContext.success(uniqueID);
                Log.d(TAG, "getUniqueId success. ID: " + uniqueID);
            } catch (Exception e) {
                Crashlytics.logException(e);
                callbackContext.error(e.getMessage());
            }
        }
    });
}

  private void getToken(final CallbackContext callbackContext) {
    Log.d(TAG, "getToken called");
    cordova.getThreadPool().execute(new Runnable() {
        public void run() {
            try {
                FirebaseMessaging.getInstance().getToken().addOnCompleteListener(new OnCompleteListener<String>() {
                    @Override
                    public void onComplete(@NonNull Task<String> task) {
                        if (!task.isSuccessful()) {
                            Log.w(TAG, "Fetching FCM registration token failed", task.getException());
                            callbackContext.error("Fetching FCM registration token failed");
                            return;
                        }

                        // Obtenha o token do FCM
                        String token = task.getResult();
                        callbackContext.success(token);
                        Log.d(TAG, "getToken success. token: " + token);
                    }
                });
            } catch (Exception e) {
                Crashlytics.logException(e);
                callbackContext.error(e.getMessage());
            }
        }
    });
}


  private void hasPermission(final CallbackContext callbackContext) {
    Log.d(TAG, "hasPermission called");
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Context context = cordova.getActivity();
          NotificationManagerCompat notificationManagerCompat = NotificationManagerCompat.from(context);
          boolean areNotificationsEnabled = notificationManagerCompat.areNotificationsEnabled();
          JSONObject object = new JSONObject();
          object.put("isEnabled", areNotificationsEnabled);
          callbackContext.success(object);
          Log.d(TAG, "hasPermission success. areEnabled: " + (areNotificationsEnabled ? "true" : "false"));
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setBadgeNumber(final CallbackContext callbackContext, final int number) {
    Log.d(TAG, "setBadgeNumber called. number: " + Integer.toString(number));
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Context context = cordova.getActivity();
          SharedPreferences.Editor editor = context.getSharedPreferences(KEY, Context.MODE_PRIVATE).edit();
          editor.putInt(KEY, number);
          editor.apply();
          ShortcutBadger.applyCount(context, number);
          callbackContext.success();
          Log.d(TAG, "setBadgeNumber success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void getBadgeNumber(final CallbackContext callbackContext) {
    Log.d(TAG, "getBadgeNumber called");
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Context context = cordova.getActivity();
          SharedPreferences settings = context.getSharedPreferences(KEY, Context.MODE_PRIVATE);
          int number = settings.getInt(KEY, 0);
          callbackContext.success(number);
          Log.d(TAG, "getBadgeNumber success. number: " + Integer.toString(number));
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }
  
  private void subscribe(final CallbackContext callbackContext, final String topic) {
    Log.d(TAG, "subscribe called. topic: " + topic);
    if(android.os.Build.VERSION.SDK_INT > 30) {
      cordova.requestPermissions(this, REQUEST_CODE_ENABLE_PERMISSION, POST_NOTIFICATION);
    }
    if(!cordova.hasPermission(POST_NOTIFICATION[0])) {
      callbackContext.error("Not permission notification");
      return;
    }
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          FirebaseMessaging.getInstance().subscribeToTopic(topic);
          callbackContext.success();
          Log.d(TAG, "subscribe success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

 private void requestPermissions(final CallbackContext callbackContext) {

    this.callbackContext = callbackContext;

  System.out.println("PermissionHelper.hasPermission(this, android.permission.POST_NOTIFICATIONS)");
  System.out.println(PermissionHelper.hasPermission(this, "android.permission.POST_NOTIFICATIONS"));
   
    if (PermissionHelper.hasPermission(this, "android.permission.POST_NOTIFICATIONS")) {
        callbackContext.success();
    } else {
       System.out.println("pede a permissao: ");
      
        PermissionHelper.requestPermission(this, REQUEST_CODE_ENABLE_PERMISSION, "android.permission.POST_NOTIFICATIONS");
    }
 }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
      System.out.println("requestCode");
      System.out.println(requestCode);
      System.out.println("REQUEST_CODE_ENABLE_PERMISSION");
      System.out.println(REQUEST_CODE_ENABLE_PERMISSION);
      System.out.println("grantResults[0]");
      System.out.println(grantResults[0]);
      System.out.println("PackageManager.PERMISSION_GRANTED");
      System.out.println(PackageManager.PERMISSION_GRANTED);
      
        if (requestCode == REQUEST_CODE_ENABLE_PERMISSION) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                callbackContext.success();
            } else {
              System.out.println("Permission denied");
                callbackContext.error("Permission denied");
            }
        }
    }


    
    
 /*   Log.d(TAG, "requestPermission called.");
    System.out.println("version: " + android.os.Build.VERSION.SDK_INT);
    if(android.os.Build.VERSION.SDK_INT > 30) {
      cordova.requestPermissions(this, REQUEST_CODE_ENABLE_PERMISSION, POST_NOTIFICATION);
      System.out.println("request 1");
    }
    if(!cordova.hasPermission(POST_NOTIFICATION[0])) {
      callbackContext.error("Not permission notification");
      System.out.println("request 2");
      return;
    }
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
           System.out.println("request 3");
          callbackContext.success();
          Log.d(TAG, "request success");
        } catch (Exception e) {
          System.out.println("request 4");
          System.out.println(e);
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
    
  }
*/
 

  private void unsubscribe(final CallbackContext callbackContext, final String topic) {
    Log.d(TAG, "unsubscribe called. topic: " + topic);
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          FirebaseMessaging.getInstance().unsubscribeFromTopic(topic);
          callbackContext.success();
          Log.d(TAG, "unsubscribe success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }
  
  private void unregister(final CallbackContext callbackContext) {
    Log.d(TAG, "unregister called");
    cordova.getThreadPool().execute(new Runnable() {
        public void run() {
            try {
                // Desregistrar o token atual
                FirebaseMessaging.getInstance().deleteToken()
                    .addOnCompleteListener(new OnCompleteListener<Void>() {
                        @Override
                        public void onComplete(@NonNull Task<Void> task) {
                            // Verificar se a operação de desregistrar foi bem-sucedida
                            if (!task.isSuccessful()) {
                                Log.w(TAG, "Unregistering FCM token failed", task.getException());
                                callbackContext.error("Unregistering FCM token failed");
                                return;
                            }

                            // Solicitar um novo token
                            FirebaseMessaging.getInstance().getToken().addOnCompleteListener(new OnCompleteListener<String>() {
                                @Override
                                public void onComplete(@NonNull Task<String> task) {
                                    if (!task.isSuccessful()) {
                                        Log.w(TAG, "Fetching FCM registration token failed", task.getException());
                                        callbackContext.error("Fetching FCM registration token failed");
                                        return;
                                    }

                                    // Obter o novo token do FCM
                                    String newToken = task.getResult();
                                    FirebasePlugin.sendToken(newToken);
                                    Log.d(TAG, "unregister success. New token: " + newToken);
                                    callbackContext.success(newToken);
                                }
                            });
                        }
                    });
            } catch (Exception e) {
                Crashlytics.logException(e);
                callbackContext.error(e.getMessage());
            }
        }
    });
}


  private void clearAllNotifications(final CallbackContext callbackContext) {
    Log.d(TAG, "clearAllNotifications called");
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Context context = cordova.getActivity();
          NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
          nm.cancelAll();
          callbackContext.success();
          Log.d(TAG, "clearAllNotifications success");
        } catch (Exception e) {
          Crashlytics.log(e.getMessage());
        }
      }
    });
  }

    //
  // Dynamic Links
  //
  private void onDynamicLink(final CallbackContext callbackContext) {
    this.dynamicLinkCallback = callbackContext;

    respondWithDynamicLink(cordova.getActivity().getIntent());
  }

  private void respondWithDynamicLink(Intent intent) {
    FirebaseDynamicLinks.getInstance().getDynamicLink(intent)
      .addOnSuccessListener(cordova.getActivity(), new OnSuccessListener<PendingDynamicLinkData>() {
        @Override
        public void onSuccess(PendingDynamicLinkData pendingDynamicLinkData) {
          if (pendingDynamicLinkData != null) {
            Uri deepLink = pendingDynamicLinkData.getLink();

            if (deepLink != null) {
              JSONObject response = new JSONObject();
              try {
                response.put("deepLink", deepLink);
                response.put("clickTimestamp", pendingDynamicLinkData.getClickTimestamp());

                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, response);
                pluginResult.setKeepCallback(true);
                dynamicLinkCallback.sendPluginResult(pluginResult);

                doOnDynamicLink(deepLink.toString());
              } catch (JSONException e) {
                Log.e(TAG, "Fail to handle dynamic link data", e);
              }
            }
          }
        }
      });
  }

  private void doOnDynamicLink(final String dynamicLink) {
    cordova.getActivity().runOnUiThread(new Runnable() {
      @Override
      public void run() {
        String method = String.format("javascript:window.fp.dynamicLinkCallback( '%s' );", dynamicLink );;
        webView.loadUrl(method);
      }
    });
  }

  // 
  // Analytics
  //
  private void logEvent(final CallbackContext callbackContext, final String name, final JSONObject params) throws JSONException {
    Log.d(TAG, "logEvent called. name: " + name);
    final Bundle bundle = new Bundle();
    Iterator iter = params.keys();
    while (iter.hasNext()) {
      String key = (String) iter.next();
      Object value = params.get(key);

      if (value instanceof Integer || value instanceof Double) {
        bundle.putFloat(key, ((Number) value).floatValue());
      } else {
        bundle.putString(key, value.toString());
      }
    }

    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          mFirebaseAnalytics.logEvent(name, bundle);
          callbackContext.success();
          Log.d(TAG, "logEvent success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setScreenName(final CallbackContext callbackContext, final String name) {
    Log.d(TAG, "setScreenName called. name: " + name);
    cordova.getActivity().runOnUiThread(new Runnable() {
      public void run() {
        try {
          mFirebaseAnalytics.setCurrentScreen(cordova.getActivity(), name, null);
          callbackContext.success();
          Log.d(TAG, "setScreenName success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setUserId(final CallbackContext callbackContext, final String id) {
    Log.d(TAG, "setUserId called. id: " + id);
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          mFirebaseAnalytics.setUserId(id);
          callbackContext.success();
          Log.d(TAG, "setUserId success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setUserProperty(final CallbackContext callbackContext, final String name, final String value) {
    Log.d(TAG, "setUserProperty called. name: " + name + " value: " + value);
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          mFirebaseAnalytics.setUserProperty(name, value);
          callbackContext.success();
          Log.d(TAG, "setUserProperty success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setAnalyticsCollectionEnabled(final CallbackContext callbackContext, final boolean enabled) {
    Log.d(TAG, "setAnalyticsCollectionEnabled called. enabled: " + (enabled ? "true" : "false"));
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          mFirebaseAnalytics.setAnalyticsCollectionEnabled(enabled);
          callbackContext.success();
          Log.d(TAG, "setAnalyticsCollectionEnabled success");
        } catch (Exception e) {
          Crashlytics.log(e.getMessage());
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  // 
  // Performance monitoring
  //
  private HashMap<String,Trace> traces = new HashMap<String,Trace>();

  private void startTrace(final CallbackContext callbackContext, final String name) {
    Log.d(TAG, "startTrace called. name: " + name);
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Trace myTrace = null;
          if (self.traces.containsKey(name)) {
            myTrace = self.traces.get(name);
          }
          if (myTrace == null) {
            myTrace = FirebasePerformance.getInstance().newTrace(name);
            myTrace.start();
            self.traces.put(name, myTrace);
          }
          callbackContext.success();
          Log.d(TAG, "startTrace success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void incrementCounter(final CallbackContext callbackContext, final String name, final String counterNamed) {
    Log.d(TAG, "incrementCounter called. name: " + name + " counterNamed: " + counterNamed);
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Trace myTrace = null;
          if (self.traces.containsKey(name)) {
            myTrace = self.traces.get(name);
          }
          if (myTrace != null && myTrace instanceof Trace) {
            myTrace.incrementMetric(counterNamed, 1);
            callbackContext.success();
            Log.d(TAG, "incrementCounter success");
          } else {
            callbackContext.error("Trace not found");
            Log.d(TAG, "incrementCounter trace not found");
          }
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void stopTrace(final CallbackContext callbackContext, final String name) {
    Log.d(TAG, "stopTrace called. name: " + name);
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Trace myTrace = null;
          if (self.traces.containsKey(name)) {
            myTrace = self.traces.get(name);
          }
          if (myTrace != null && myTrace instanceof Trace) {
            myTrace.stop();
            self.traces.remove(name);
            callbackContext.success();
            Log.d(TAG, "stopTrace success");
          } else {
            callbackContext.error("Trace not found");
            Log.d(TAG, "stopTrace trace not found");
          }
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void addTraceAttribute(final CallbackContext callbackContext, final String traceName, final String attribute, final String value) {
    Log.d(TAG, "addTraceAttribute called. traceName: " + traceName + " attribute: " + attribute + " value: " + value);
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Trace myTrace = null;
          if (self.traces.containsKey(traceName)) {
            myTrace = self.traces.get(traceName);
          }
          if (myTrace != null && myTrace instanceof Trace) {
            myTrace.putAttribute(attribute, value);
            callbackContext.success();
            Log.d(TAG, "addTraceAttribute success");
          } else {
            callbackContext.error("Trace not found");
            Log.d(TAG, "addTraceAttribute trace not found");
          }
        } catch (Exception e) {
          Crashlytics.log(e.getMessage());
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setPerformanceCollectionEnabled(final CallbackContext callbackContext, final boolean enabled) {
    Log.d(TAG, "setPerformanceCollectionEnabled called. enabled: " + (enabled ? "true" : "false"));
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          FirebasePerformance.getInstance().setPerformanceCollectionEnabled(enabled);
          callbackContext.success();
          Log.d(TAG, "setPerformanceCollectionEnabled success");
        } catch (Exception e) {
          Crashlytics.log(e.getMessage());
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  // 
  // Crashlytics
  //
  private void forceCrashlytics(final CallbackContext callbackContext) {
    Log.d(TAG, "forceCrashlytics called");
    final FirebasePlugin self = this;
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        Crashlytics.getInstance().crash();
      }
    });
  }
  
  private void logError(final CallbackContext callbackContext, final String message) throws JSONException {
    Log.d(TAG, "logError called. message: " + message);
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          Crashlytics.logException(new Exception(message));
          callbackContext.success(1);
          Log.d(TAG, "logError success");
        } catch (Exception e) {
          Crashlytics.log(e.getMessage());
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setCrashlyticsUserId(final CallbackContext callbackContext, final String userId) {
    Log.d(TAG, "setCrashlyticsUserId called. userId: " + userId);
    cordova.getActivity().runOnUiThread(new Runnable() {
      public void run() {
        try {
          Crashlytics.setUserIdentifier(userId);
          callbackContext.success();
          Log.d(TAG, "setCrashlyticsUserId success");
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  //
  // Remote Configuration
  //
  private void activateFetched(final CallbackContext callbackContext) {
    Log.d(TAG, "activateFetched called");
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          final boolean activated = FirebaseRemoteConfig.getInstance().activateFetched();
          Log.d(TAG, "activateFetched success. activated: " + String.valueOf(activated));
          callbackContext.success(String.valueOf(activated));
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void fetch(CallbackContext callbackContext) {
    Log.d(TAG, "fetch called");
    fetch(callbackContext, FirebaseRemoteConfig.getInstance().fetch());
  }

  private void fetch(CallbackContext callbackContext, long cacheExpirationSeconds) {
    Log.d(TAG, "fetch called. cacheExpirationSeconds: " + String.valueOf(cacheExpirationSeconds));
    fetch(callbackContext, FirebaseRemoteConfig.getInstance().fetch(cacheExpirationSeconds));
  }

  private void fetch(final CallbackContext callbackContext, final Task<Void> task) {
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          task.addOnSuccessListener(new OnSuccessListener<Void>() {
            @Override
            public void onSuccess(Void data) {
              Log.d(TAG, "fetch success");
              callbackContext.success();
            }
          }).addOnFailureListener(new OnFailureListener() {
            @Override
            public void onFailure(Exception e) {
              Log.d(TAG, "fetch error. error: " + e.getMessage());
              callbackContext.error(e.getMessage());
            }
          });
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void getByteArray(final CallbackContext callbackContext, final String key) {
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          byte[] bytes = FirebaseRemoteConfig.getInstance().getByteArray(key);
          JSONObject object = new JSONObject();
          object.put("base64", Base64.encodeToString(bytes, Base64.DEFAULT));
          object.put("array", new JSONArray(bytes));
          callbackContext.success(object);
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void getValue(final CallbackContext callbackContext, final String key) {
    Log.d(TAG, "getValue called. key: " + key);
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          FirebaseRemoteConfigValue value = FirebaseRemoteConfig.getInstance().getValue(key);
          Log.d(TAG, "getValue success. value: " + value.asString());
          callbackContext.success(value.asString());
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void getInfo(final CallbackContext callbackContext) {
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          FirebaseRemoteConfigInfo remoteConfigInfo = FirebaseRemoteConfig.getInstance().getInfo();
          JSONObject info = new JSONObject();

          JSONObject settings = new JSONObject();
          settings.put("developerModeEnabled", remoteConfigInfo.getConfigSettings().isDeveloperModeEnabled());
          info.put("configSettings", settings);

          info.put("fetchTimeMillis", remoteConfigInfo.getFetchTimeMillis());
          info.put("lastFetchStatus", remoteConfigInfo.getLastFetchStatus());

          callbackContext.success(info);
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setConfigSettings(final CallbackContext callbackContext, final JSONObject config) {
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          boolean devMode = config.getBoolean("developerModeEnabled");
          FirebaseRemoteConfigSettings.Builder settings = new FirebaseRemoteConfigSettings.Builder()
              .setDeveloperModeEnabled(devMode);
          FirebaseRemoteConfig.getInstance().setConfigSettings(settings.build());
          callbackContext.success();
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private void setDefaults(final CallbackContext callbackContext, final JSONObject defaults) {
    cordova.getThreadPool().execute(new Runnable() {
      public void run() {
        try {
          FirebaseRemoteConfig.getInstance().setDefaults(defaultsToMap(defaults));
          callbackContext.success();
        } catch (Exception e) {
          Crashlytics.logException(e);
          callbackContext.error(e.getMessage());
        }
      }
    });
  }

  private static Map<String, Object> defaultsToMap(JSONObject object) throws JSONException {
    final Map<String, Object> map = new HashMap<String, Object>();

    for (Iterator<String> keys = object.keys(); keys.hasNext(); ) {
      String key = keys.next();
      Object value = object.get(key);

      if (value instanceof Integer) {
        //setDefaults() should take Longs
        value = new Long((Integer) value);
      } else if (value instanceof JSONArray) {
        JSONArray array = (JSONArray) value;
        if (array.length() == 1 && array.get(0) instanceof String) {
          //parse byte[] as Base64 String
          value = Base64.decode(array.getString(0), Base64.DEFAULT);
        } else {
          //parse byte[] as numeric array
          byte[] bytes = new byte[array.length()];
          for (int i = 0; i < array.length(); i++)
            bytes[i] = (byte) array.getInt(i);
          value = bytes;
        }
      }

      map.put(key, value);
    }
    return map;
  }
}
