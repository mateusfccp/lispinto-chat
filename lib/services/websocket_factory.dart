import 'package:web_socket_channel/web_socket_channel.dart';

import 'websocket_factory_stub.dart'
    if (dart.library.io) 'websocket_factory_io.dart'
    if (dart.library.html) 'websocket_factory_web.dart';

/// A factory that creates [WebSocketChannel] instances.
abstract interface class WebSocketFactory {
  /// Creates a [WebSocketChannel] connected to the given [uri].
  WebSocketChannel create(Uri uri);
}

/// The default implementation of [WebSocketFactory] that uses platform-specific
/// connection logic.
class DefaultWebSocketFactory implements WebSocketFactory {
  /// Creates a [DefaultWebSocketFactory].
  const DefaultWebSocketFactory(this.appVersion);

  /// The version of the app, used for the User-Agent header.
  final String appVersion;

  @override
  WebSocketChannel create(Uri uri) {
    return createWebSocketChannel(uri, appVersion);
  }
}
