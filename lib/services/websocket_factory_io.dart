import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri, String appVersion) {
  String osName;
  if (Platform.isIOS) {
    osName = 'iOS';
  } else if (Platform.isMacOS) {
    osName = 'macOS';
  } else if (Platform.isAndroid) {
    osName = 'Android';
  } else if (Platform.isWindows) {
    osName = 'Windows';
  } else if (Platform.isLinux) {
    osName = 'Linux';
  } else {
    osName = Platform.operatingSystem;
  }

  return IOWebSocketChannel.connect(
    uri,
    headers: {'User-Agent': 'Lispinto/$appVersion $osName'},
  );
}
