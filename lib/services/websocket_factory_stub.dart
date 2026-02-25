import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri, String appVersion) {
  throw UnsupportedError(
    'Cannot create websocket without proper platform implementation',
  );
}
