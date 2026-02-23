import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/user_configuration.dart';
import 'chat_service.dart';

/// Initializes the service that maintains the connection and shows notifications.
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'lisp_chat_foreground',
    'Lisp Chat Background Service',
    description: 'Keeps the Lisp Chat connection alive in the background.',
    importance: Importance.low,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'lisp_chat_foreground',
      initialNotificationTitle: 'Lisp Chat',
      initialNotificationContent: 'Running in background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

/// The iOS entrypoint.
///
/// iOS requires a separate entry point for background execution. This is where
/// you can perform any necessary setup before the service starts.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// The main entry point for the background service.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final config = await UserConfiguration.load();
  if (!config.hasNickname) {
    service.stopSelf();
    return;
  }

  // Headless chat service
  final chatService = ChatService(
    serverUrl: Uri.parse(config.serverUrl),
    nickname: config.nickname,
  );

  final FlutterLocalNotificationsPlugin nfy = FlutterLocalNotificationsPlugin();

  chatService.notifications.listen((message) {
    nfy.show(
      id: 100,
      title: 'Lisp Chat',
      body: message,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'lisp_chat_foreground',
          'Lisp Chat Background',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  });

  chatService.connect();

  service.on('stopService').listen((event) {
    chatService.dispose();
    service.stopSelf();
  });
}
