// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<bool> requestWebNotificationPermissions() async {
  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

void showWebNotification(String title, String body) {
  if (html.Notification.permission == 'granted') {
    html.Notification(title, body: body);
  }
}
