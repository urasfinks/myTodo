import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:push/push.dart' as push;

import 'package:push/push.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationGroup.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    NotificationGroup.getToken();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Push Example App'),
        ),
        body: const SizedBox(),
      ),
    );
  }
}

enum PushType { onToken, onNotificationTap, onMessage, onBackgroundMessage }

class NotificationGroup {
  static FlutterLocalNotificationsPlugin? plugin;

  static AndroidNotificationChannel mainChannel = const AndroidNotificationChannel(
    'main',
    'main',
    description: 'Main chanel',
    importance: Importance.max,
  );

  static Future<void> init() async {
    plugin = await NotificationGroup.initPlugin();

    Push.instance.onNewToken.listen((token) => onMessage({"token": token}, PushType.onToken));
    Push.instance.onNotificationTap.listen((data) => onMessage(parseNotificationTap(data), PushType.onNotificationTap));
    Push.instance.onMessage.listen((message) => onMessage(parseRemoteMessage(message), PushType.onMessage));
    Push.instance.onBackgroundMessage.listen((message) => onMessage(parseRemoteMessage(message), PushType.onBackgroundMessage));

    if (!Platform.isAndroid) {
      return;
    }

    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()!
        .createNotificationChannel(mainChannel);
  }

  static void displayForegroundNotification(push.Notification notification) async {
    final androidOptions = AndroidNotificationDetails(
      mainChannel.id,
      mainChannel.name,
      channelDescription: mainChannel.description,
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
    await plugin!.show(0, notification.title, notification.body, platformChannelSpecifics);
  }

  static void getToken() {
    if (Platform.isIOS) {
      Push.instance.getNotificationSettings().then((settings) {
        if (settings.authorizationStatus == UNAuthorizationStatus.authorized) {
          Push.instance.token.then((value) => onMessage({"token": value}, PushType.onToken));
        } else {
          onMessage({"token": null}, PushType.onToken);
        }
      });
    } else if (Platform.isAndroid) {
      Push.instance.areNotificationsEnabled().then((areNotificationsEnabled) {
        if (!areNotificationsEnabled) {
          Push.instance.requestPermission().then((value) {
            if (value == true) {
              Push.instance.token.then((value) => onMessage({"token": value}, PushType.onToken));
            }
          });
        } else {
          Push.instance.token.then((value) => onMessage({"token": value}, PushType.onToken));
        }
      });
    }
  }

  static void onMessage(Map<String?, Object?>? data, PushType type) {
    print("onMessage($type) $data");
  }

  static Future<FlutterLocalNotificationsPlugin> initPlugin() async {
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

  static Map<String, Object> parseNotificationTap(Map<String?, Object?> data) {
    Map<String, Object> result = {"title": "", "message": ""};
    if (Platform.isIOS) {
      result["title"] = selector(data, "aps.alert", "");
      result["message"] = selector(data, "message", "");
    }
    return result;
  }

  static Map<String, Object> parseRemoteMessage(RemoteMessage message) {
    Map<String, Object> result = {"title": "", "message": ""};
    if (message.notification != null) {
      displayForegroundNotification(message.notification!);
    }
    if (Platform.isIOS) {
      result["title"] = selector(message.data, "aps.alert", "");
      result["message"] = selector(message.data, "message", "");
    } else if (Platform.isAndroid) {}
    return result;
  }

  static dynamic selector(Map<String?, dynamic>? data, String path, [dynamic defaultValue]) {
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
    } catch (e, stacktrace) {
      find = false;
    }
    if (!find) {
      return defaultValue;
    }
    return cur;
  }
}
