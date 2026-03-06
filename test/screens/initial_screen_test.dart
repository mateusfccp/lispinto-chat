import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/models/chat_message.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/initial_screen.dart';
import 'package:lispinto_chat/services/chat_service.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockChatProvider extends ChangeNotifier implements ChatProvider {
  @override
  ChatConnectionState connectionState = ChatConnectionState.disconnected;

  @override
  bool get isConnected =>
      connectionState == ChatConnectionState.connected ||
      connectionState == ChatConnectionState.loggedIn;

  @override
  bool get isConnecting => connectionState == ChatConnectionState.connecting;

  Completer<void>? connectCompleter;

  @override
  Future<void> connect() async {
    connectionState = ChatConnectionState.connecting;
    notifyListeners();
    if (connectCompleter != null) {
      await connectCompleter!.future;
    }
  }

  @override
  Future<void> updateConfiguration(String nickname, String serverUrl) async {
    // Just a stub
  }

  @override
  void autoConnect() {}

  @override
  UnmodifiableListView<ChatMessage> get messages => UnmodifiableListView([]);

  @override
  UnmodifiableListView<String> get onlineUsers => UnmodifiableListView([]);

  @override
  UnmodifiableMapView<String, int> get channels => UnmodifiableMapView({});

  @override
  String get activeChannel => '#general';

  @override
  bool get isCurrentChannelPrivate => false;

  @override
  String? get currentDmNickname => null;

  @override
  String get searchQuery => '';

  @override
  Stream<String> get notifications => const Stream.empty();

  @override
  UserConfiguration get configuration => locator<UserConfiguration>();

  @override
  String get appVersion => '1.0.0';

  @override
  Future<bool> requestPermissions() async => true;

  @override
  void sendMessage(String message) {}

  @override
  void setDmMode(String? user) {}

  @override
  void joinChannel(String channel) {}

  @override
  void setPrivateChannel(bool isPrivate) {}

  @override
  void search(String query) {}

  @override
  void clearMessages() {}

  @override
  void disconnect() {}
}

void main() {
  late MockChatProvider mockProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await locator.reset();
    final config = await UserConfiguration.load();
    locator.registerSingleton<UserConfiguration>(config);

    mockProvider = MockChatProvider();
    locator.registerSingleton<ChatProvider>(mockProvider);
    locator.registerSingleton<Logger>(Logger('Test'));

    locator.registerSingleton<PackageInfo>(
      PackageInfo(
        appName: 'Lispinto Chat',
        packageName: 'com.example.lispinto_chat',
        version: '1.0.0',
        buildNumber: '1',
      ),
    );
  });

  testWidgets('InitialScreen renders form items, privacy policy and version', (
    WidgetTester tester,
  ) async {
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

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  testWidgets('InitialScreen shows loading state when connecting', (
    WidgetTester tester,
  ) async {
    mockProvider.connectCompleter = Completer<void>();

    await tester.pumpWidget(const MaterialApp(home: InitialScreen()));

    // Fill in nickname and server URL
    await tester.enterText(find.byType(TextFormField).first, 'TestUser');
    await tester.enterText(find.byType(TextFormField).last, 'ws://test');

    // Click connect
    await tester.tap(find.text('Connect'));
    await tester.pump(); // Start navigation/logic
    await tester
        .pump(); // Second pump for providers to notify and UI to rebuild

    // Verify loading state
    expect(find.text('Connecting'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify fields are disabled
    final nicknameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    final serverUrlField = tester.widget<TextFormField>(
      find.byType(TextFormField).last,
    );
    expect(nicknameField.enabled, isFalse);
    expect(serverUrlField.enabled, isFalse);

    // Complete connection
    mockProvider.connectionState = ChatConnectionState.loggedIn;
    mockProvider.connectCompleter!.complete();
    await tester.pump();
    await tester.pump();
  });
}
