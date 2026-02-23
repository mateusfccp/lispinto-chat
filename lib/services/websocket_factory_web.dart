import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel createWebSocketChannel(Uri uri, String appVersion) {
  // Browsers do not allow setting User-Agent headers natively on websockets
  return HtmlWebSocketChannel.connect(uri);
}
