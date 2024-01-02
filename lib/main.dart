import 'package:flutter/material.dart';
import 'package:my_todo/push_notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotification.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    PushNotification.getToken();

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
