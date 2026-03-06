import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/initial_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mockito/mockito.dart';

class MockChatProvider extends Mock implements ChatProvider {
  Future<void> Function()? onConnect;

  @override
  Future<void> connect() async {
    if (onConnect != null) {
      await onConnect!();
    }
  }

  @override
  Future<void> updateConfiguration(String nickname, String serverUrl) async {}

  @override
  bool isConnected = false;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await locator.reset();
    final config = await UserConfiguration.load();
    locator.registerSingleton<UserConfiguration>(config);
    locator.registerSingleton<ChatProvider>(MockChatProvider());
    locator.registerSingleton<PackageInfo>(PackageInfo(
      appName: 'Lispinto Chat',
      packageName: 'com.example.lispinto_chat',
      version: '1.0.0',
      buildNumber: '1',
    ));
  });

  testWidgets('InitialScreen renders form items, privacy policy and version', (WidgetTester tester) async {
    // Set a predictable viewport size
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const MaterialApp(home: InitialScreen()));

    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    
    // Check for CustomScrollView and SliverFillRemaining
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.byType(SliverFillRemaining), findsOneWidget);

    // Verify Privacy Policy is at the bottom using offset
    final privacyPolicyFinder = find.text('Privacy Policy');
    final privacyPolicyOffset = tester.getCenter(privacyPolicyFinder);
    
    final connectButtonFinder = find.text('Connect');
    final connectButtonOffset = tester.getCenter(connectButtonFinder);

    expect(privacyPolicyOffset.dy, greaterThan(connectButtonOffset.dy));
    
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('InitialScreen shows loading state when connecting', (WidgetTester tester) async {
    final mockProvider = MockChatProvider();
    
    // Stub connect to take some time
    final completer = Completer<void>();
    mockProvider.onConnect = () => completer.future;
    mockProvider.isConnected = false;

    await locator.reset();
    final config = await UserConfiguration.load();
    locator.registerSingleton<UserConfiguration>(config);
    locator.registerSingleton<ChatProvider>(mockProvider);
    locator.registerSingleton<PackageInfo>(PackageInfo(
      appName: 'Lispinto Chat',
      packageName: 'com.example.lispinto_chat',
      version: '1.0.0',
      buildNumber: '1',
    ));

    await tester.pumpWidget(const MaterialApp(home: InitialScreen()));

    // Fill in nickname and server URL
    await tester.enterText(find.byType(TextFormField).first, 'TestUser');
    await tester.enterText(find.byType(TextFormField).last, 'ws://test');
    
    // Click connect
    await tester.tap(find.text('Connect'));
    await tester.pump();

    // Verify loading state
    expect(find.text('Connecting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Verify fields are disabled
    final nicknameField = tester.widget<TextFormField>(find.byType(TextFormField).first);
    final serverUrlField = tester.widget<TextFormField>(find.byType(TextFormField).last);
    expect(nicknameField.enabled, isFalse);
    expect(serverUrlField.enabled, isFalse);

    // Complete connection
    completer.complete();
    await tester.pumpAndSettle();
  });
}
