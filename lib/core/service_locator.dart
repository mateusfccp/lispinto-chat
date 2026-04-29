import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/chat_provider.dart';
import '../services/chat_service.dart';
import '../services/image_upload_service.dart';
import '../services/imgbb_upload_service.dart';
import '../services/link_preview_service.dart';
import '../services/websocket_factory.dart';
import 'message_grouper.dart';
import 'user_configuration.dart';

/// The global service locator instance.
final locator = GetIt.instance;

/// Sets up the service locator with all necessary dependencies.
Future<void> setupServiceLocator() async {
  final logger = Logger('LispintoChat');
  locator.registerSingleton<Logger>(logger);

  final packageInfo = await PackageInfo.fromPlatform();
  locator.registerSingleton<PackageInfo>(packageInfo);
  final appVersion = packageInfo.version;

  final configuration = await UserConfiguration.load();
  locator.registerSingleton<UserConfiguration>(configuration);

  locator.registerSingleton<http.Client>(http.Client());

  locator.registerSingleton<LinkPreviewService>(
    LinkPreviewService(client: locator()),
  );

  locator.registerSingleton<MessageGrouper>(const MessageGrouper());

  locator.registerSingleton<WebSocketFactory>(
    DefaultWebSocketFactory(appVersion),
  );

  locator.registerSingleton<FlutterLocalNotificationsPlugin>(
    FlutterLocalNotificationsPlugin(),
  );

  locator.registerSingleton<ChatService>(
    ChatService(
      configuration: configuration,
      httpClient: locator(),
      initialChannel: configuration.lastChannel,
      nickname: configuration.nickname,
      url: Uri.parse(configuration.serverUrl),
      webSocketFactory: locator(),
    ),
  );

  locator.registerSingleton<ChatProvider>(
    ChatProvider(
      configuration,
      appVersion: appVersion,
      localNotifications: locator(),
      chatService: locator(),
    ),
  );

  locator.registerSingleton<ImageUploadService>(
    ImgBBImageUploadService(apiKey: configuration.imgbbApiKey),
  );
}
