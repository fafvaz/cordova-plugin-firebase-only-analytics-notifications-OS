var exec = require('cordova/exec');

var PLUGIN_NAME = 'FirebasePlugin';

//
// Cloud Messaging FCM
//
exports.getId = function (success, error) {
  exec(success, error, PLUGIN_NAME, "getId", []);
};

exports.getPushNotificationStatus = function (success, fail) {
    return exec(success, fail, PLUGIN_NAME, "getPushNotificationStatus", []);
  };

exports.getToken = function (success, error) {
  exec(success, error, PLUGIN_NAME, "getToken", []);
};

exports.hasPermission = function (success, error) {
  exec(success, error, PLUGIN_NAME, "hasPermission", []);
};

exports.grantPermission = function (success, error) {
  exec(success, error, PLUGIN_NAME, "grantPermission", []);
};

exports.setBadgeNumber = function (number, success, error) {
  exec(success, error, PLUGIN_NAME, "setBadgeNumber", [number]);
};

exports.getBadgeNumber = function (success, error) {
  exec(success, error, PLUGIN_NAME, "getBadgeNumber", []);
};

exports.subscribe = function (topic, success, error) {
  exec(success, error, PLUGIN_NAME, "subscribe", [topic]);
};

exports.requestPermissions = function (success, error) {
  exec(success, error, PLUGIN_NAME, "requestPermissions", []);
};

exports.unsubscribe = function (topic, success, error) {
  exec(success, error, PLUGIN_NAME, "unsubscribe", [topic]);
};

exports.unregister = function (success, error) {
  exec(success, error, PLUGIN_NAME, "unregister", []);
};

exports.onNotificationOpen = function (success, error) {
  exec(success, error, PLUGIN_NAME, "onNotificationOpen", []);
};

exports.onTokenRefresh = function (success, error) {
  exec(success, error, PLUGIN_NAME, "onTokenRefresh", []);
};

exports.clearAllNotifications = function (success, error) {
  exec(success, error, PLUGIN_NAME, "clearAllNotifications", []);
};

//
// Analytics
//
exports.logEvent = function (name, params, success, error) {
  exec(success, error, PLUGIN_NAME, "logEvent", [name, params]);
};

exports.setScreenName = function (name, success, error) {
  exec(success, error, PLUGIN_NAME, "setScreenName", [name]);
};

exports.setUserId = function (id, success, error) {
  exec(success, error, PLUGIN_NAME, "setUserId", [id]);
};

exports.setUserProperty = function (name, value, success, error) {
  exec(success, error, PLUGIN_NAME, "setUserProperty", [name, value]);
};

exports.setAnalyticsCollectionEnabled = function (enabled, success, error) {
  exec(success, error, PLUGIN_NAME, "setAnalyticsCollectionEnabled", [enabled]);
};

//
// Crashlytics
//
// exports.logError = function (message, success, error) {
//   exec(success, error, PLUGIN_NAME, "logError", [message]);
// };

// exports.forceCrashlytics = function (message, success, error) {
//   exec(success, error, PLUGIN_NAME, "forceCrashlytics", [message]);
// };

// exports.setCrashlyticsUserId = function (userId, success, error) {
//   exec(success, error, PLUGIN_NAME, "setCrashlyticsUserId", [userId]);
// };

//
// Performance
//
// exports.startTrace = function (name, success, error) {
//   exec(success, error, PLUGIN_NAME, "startTrace", [name]);
// };

// exports.incrementCounter = function (name, counterNamed, success, error) {
//   exec(success, error, PLUGIN_NAME, "incrementCounter", [name, counterNamed]);
// };

// exports.stopTrace = function (name, success, error) {
//   exec(success, error, PLUGIN_NAME, "stopTrace", [name]);
// };

// exports.addTraceAttribute = function (traceName, attribute, value, success, error) {
//   exec(success, error, PLUGIN_NAME, "addTraceAttribute", [traceName, attribute, value]);
// };

// exports.setPerformanceCollectionEnabled = function (enabled, success, error) {
//   exec(success, error, PLUGIN_NAME, "setPerformanceCollectionEnabled", [enabled]);
// };

//
// Remote configuration
//
// exports.activateFetched = function (success, error) {
//   exec(success, error, PLUGIN_NAME, "activateFetched", []);
// };

// exports.fetch = function (cacheExpirationSeconds, success, error) {
//   var args = [];
//   if (typeof cacheExpirationSeconds === 'number') {
//     args.push(cacheExpirationSeconds);
//   } else {
//     error = success;
//     success = cacheExpirationSeconds;
//   }
//   exec(success, error, PLUGIN_NAME, "fetch", args);
// };

// exports.getByteArray = function (key, namespace, success, error) {
//   var args = [key];
//   if (typeof namespace === 'string') {
//     args.push(namespace);
//   } else {
//     error = success;
//     success = namespace;
//   }
//   exec(success, error, PLUGIN_NAME, "getByteArray", args);
// };

// exports.getValue = function (key, namespace, success, error) {
//   var args = [key];
//   if (typeof namespace === 'string') {
//     args.push(namespace);
//   } else {
//     error = success;
//     success = namespace;
//   }
//   exec(success, error, PLUGIN_NAME, "getValue", args);
// };

// exports.getInfo = function (success, error) {
//   exec(success, error, PLUGIN_NAME, "getInfo", []);
// };

// exports.setConfigSettings = function (settings, success, error) {
//   exec(success, error, PLUGIN_NAME, "setConfigSettings", [settings]);
// };

// exports.setDefaults = function (defaults, namespace, success, error) {
//   var args = [defaults];
//   if (typeof namespace === 'string') {
//     args.push(namespace);
//   } else {
//     error = success;
//     success = namespace;
//   }
//   exec(success, error, PLUGIN_NAME, "setDefaults", args);
// };

// //
// // Dynamic Links
// //
// exports.onDynamicLink = function (success, error) {
//   exec(success, error, PLUGIN_NAME, "onDynamicLink", []);
// };

// exports.dynamicLinkCallback = function (dynamicLink) {
//   var ev = document.createEvent('HTMLEvents');
//   ev.dynamicLink = dynamicLink;
//   ev.initEvent('dynamic-link', true, true, arguments);
//   document.dispatchEvent(ev);
// };
