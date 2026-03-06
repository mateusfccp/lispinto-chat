import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/chat_provider.dart';
import '../services/image_upload_service.dart';
import '../services/imgbb_upload_service.dart';
import '../services/link_image_detector.dart';
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

  final config = await UserConfiguration.load();
  locator.registerSingleton<UserConfiguration>(config);

  final detector = LinkImageDetector();
  locator.registerSingleton<LinkImageDetector>(detector);

  locator.registerSingleton<MessageGrouper>(const MessageGrouper());

  locator.registerSingleton<WebSocketFactory>(
    DefaultWebSocketFactory(appVersion),
  );

  locator.registerSingleton<ChatProvider>(
    ChatProvider(config, appVersion: appVersion, websocketFactory: locator()),
  );

  locator.registerSingleton<ImageUploadService>(
    ImgBBImageUploadService(apiKey: config.imgbbApiKey),
  );
}
