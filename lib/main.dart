import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/logging.dart';
import 'core/router.dart';
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();
  await setupServiceLocator();

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  runApp(const App());
}

final class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Lispinto Chat',
      darkTheme: ThemeData.dark().copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
        ),
      ),
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
