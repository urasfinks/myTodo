import 'dart:async';

import 'package:flutter/material.dart';

import 'package:my_todo/push_notification.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PushNotification();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  final bool _running = true;

  Stream<String> _clock() async* {
    // This loop will run forever because _running is always true
    while (_running) {
      await Future<void>.delayed(const Duration(seconds: 1));

      yield PushNotification().list.join("\n\n");
    }
  }

  @override
  Widget build(BuildContext context) {
    PushNotification().getToken();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Push Example App'),
        ),
        body: StreamBuilder(
          stream: _clock(),
          builder: (context, AsyncSnapshot<String> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            return Text(
              snapshot.data!,
              style: const TextStyle(fontSize: 14, color: Colors.blue),
            );
          },
        ),
      ),
    );
  }
}
