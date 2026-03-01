import 'package:flutter/material.dart';
import 'screens/initial_screen.dart';
import 'core/service_locator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lispinto Chat',
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const InitialScreen(),
    );
  }
}
