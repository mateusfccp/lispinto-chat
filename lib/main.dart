import 'package:flutter/material.dart';
import 'screens/configurations_screen.dart';
import 'screens/chat_screen.dart';
import 'core/user_configuration.dart';
import 'providers/chat_provider.dart';

import 'package:package_info_plus/package_info_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final packageInfo = await PackageInfo.fromPlatform();
  final appVersion = packageInfo.version;

  final config = await UserConfiguration.load();
  final chatProvider = ChatProvider(config, appVersion: appVersion);

  runApp(App(config: config, chatProvider: chatProvider));
}

class App extends StatelessWidget {
  final UserConfiguration config;
  final ChatProvider chatProvider;

  const App({super.key, required this.config, required this.chatProvider});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lispinto Chat',
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: config.hasNickname
          ? ChatScreen(provider: chatProvider)
          : ConfigurationsScreen(
              configuration: config,
              chatProvider: chatProvider,
            ),
    );
  }
}
