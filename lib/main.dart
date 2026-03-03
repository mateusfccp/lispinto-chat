import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/router.dart';
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  if (kIsWeb) {
    BrowserContextMenu.disableContextMenu();
  }

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
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
