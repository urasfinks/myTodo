import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:push/push.dart' as push;
import 'package:push/push.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(fcm.RemoteMessage message) async {
  await Firebase.initializeApp();
  fcm.RemoteNotification? notification = message.notification;
  fcm.AndroidNotification? android = message.notification?.android;
  if (notification != null && android != null && notification.title != null && notification.body != null) {
    String payload = "";
    if (message.data.containsKey("message")) {
      payload = message.data["message"]!.toString();
    }
    PushNotification().openPush(notification.title!, notification.body!, payload);
  }
}

enum PushType { onToken, onNotificationTap, onMessageOpenedApp }

class PushNotification {
  static final PushNotification _singleton = PushNotification._internal();
  FlutterLocalNotificationsPlugin? _plugin;
  bool _isInit = false;
  AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  factory PushNotification() {
    if (_singleton._isInit == false) {
      _singleton._isInit = true;
      _singleton.init();
    }
    return _singleton;
  }

  PushNotification._internal();

  List<String> list = [];

  void onMessage(String? payload, PushType type) {
    list.add("type: ${type.name}; payload: $payload");
    print("onMessage($type) $payload");
  }

  init() {
    initPlugin().then((value) {
      _plugin = value;
    });
    if (Platform.isAndroid) {
      //Регистрация закрытого обработчика
      fcm.FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
          .createNotificationChannel(channel);
    }
    Push.instance.notificationTapWhichLaunchedAppFromTerminated.then((value) {
      if (value != null && value.containsKey("message") && value["message"] != "") {
        PushNotification().onMessage(value["message"].toString(), PushType.onMessageOpenedApp);
      }
    });
    Push.instance.onNewToken.listen((token) => onMessage(token, PushType.onToken));
    Push.instance.onNotificationTap.listen((data) => parseNotificationTap(data));
    Push.instance.onMessage.listen((message) => parseRemoteMessage(message));
    Push.instance.onBackgroundMessage.listen((message) => parseRemoteMessage(message));
  }

  void parseNotificationTap(Map<String?, Object?> data) {
    String payload = "";
    if (data.containsKey("message")) {
      payload = data["message"]!.toString();
    } else if (data.containsKey("payload")) {
      payload = data["payload"]!.toString();
    }
    if (payload != "") {
      onMessage(payload, PushType.onNotificationTap);
    }
  }

  void parseRemoteMessage(push.RemoteMessage message) {
    String title = "";
    String body = "";
    String payload = "";
    if (Platform.isIOS) {
      //message.data = {aps: {alert: You got the new message}, message: {"x1":1}}
      body = selector(message.data, "aps.alert", "");
      payload = selector(message.data, "message", "");
    } else if (Platform.isAndroid) {
      if (message.notification != null && message.notification!.title != null && message.notification!.body != null) {
        if (message.data != null && message.data!.containsKey("message")) {
          payload = message.data!["message"]!.toString();
        }
        title = message.notification!.title!;
        body = message.notification!.body!;
      }
    }
    if (body != "") {
      openPush(title, body, payload);
    }
  }

  void getToken() {
    if (Platform.isIOS) {
      Push.instance.getNotificationSettings().then((settings) {
        if (settings.authorizationStatus == UNAuthorizationStatus.authorized) {
          Push.instance.token.then((value) => onMessage(value, PushType.onToken));
        } else {
          onMessage(null, PushType.onToken);
        }
      });
    } else if (Platform.isAndroid) {
      Push.instance.areNotificationsEnabled().then((areNotificationsEnabled) {
        if (!areNotificationsEnabled) {
          Push.instance.requestPermission().then((value) {
            if (value == true) {
              Push.instance.token.then((value) => onMessage(value, PushType.onToken));
            }
          });
        } else {
          Push.instance.token.then((value) => onMessage(value, PushType.onToken));
        }
      });
    }
  }

  void openPush(String title, String body, String payload) async {
    final androidOptions = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
      ticker: "A manually-sent push notification.",
      styleInformation: const DefaultStyleInformation(
        false,
        false,
      ),
    );
    const iosOptions = DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true);
    final platformChannelSpecifics = NotificationDetails(android: androidOptions, iOS: iosOptions);
    await _plugin!.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<FlutterLocalNotificationsPlugin> initPlugin() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const DarwinInitializationSettings settingsApple = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    await flutterLocalNotificationsPlugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('mipmap/ic_launcher'),
      iOS: settingsApple,
      macOS: settingsApple,
    ));
    return flutterLocalNotificationsPlugin;
  }

  dynamic selector(Map? data, String path, [dynamic defaultValue]) {
    defaultValue ??= "[$path]";
    if (data == null) {
      return defaultValue;
    }
    bool find = true;
    if (path == ".") {
      return data;
    }
    dynamic cur = data;
    try {
      List<String> exp = path.split(".");
      for (String key in exp) {
        if (cur != null && cur[key] != null) {
          cur = cur[key];
        } else {
          find = false;
          break;
        }
      }
    } catch (e) {
      find = false;
    }
    if (!find) {
      return defaultValue;
    }
    return cur;
  }
}
