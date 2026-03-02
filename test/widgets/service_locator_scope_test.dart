import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/widgets/service_locator_scope.dart';

abstract interface class TestService {
  String get name;
}

class OriginalService implements TestService {
  @override
  String get name => 'Original';
}

class MockService implements TestService {
  @override
  String get name => 'Mock';
}

void main() {
  setUp(() async {
    await locator.reset();
  });

  testWidgets('ServiceLocatorScope pushes and pops scopes', (tester) async {
    locator.registerSingleton<TestService>(OriginalService());

    expect(locator<TestService>().name, 'Original');

    await tester.pumpWidget(
      ServiceLocatorScope(
        overrides: (locator) {
          locator.registerSingleton<TestService>(MockService());
        },
        child: Container(),
      ),
    );

    expect(locator<TestService>().name, 'Mock');

    await tester.pumpWidget(Container()); // Dispose the scope

    expect(locator<TestService>().name, 'Original');
  });

  testWidgets('ServiceLocatorScope allows multiple overrides', (tester) async {
    locator.registerSingleton<String>('Base', instanceName: 'base');

    await tester.pumpWidget(
      ServiceLocatorScope(
        overrides: (locator) {
          locator.registerSingleton<String>('Override', instanceName: 'base');
        },
        child: ServiceLocatorScope(
          overrides: (locator) {
            locator.registerSingleton<String>('Nested', instanceName: 'base');
          },
          child: Container(),
        ),
      ),
    );

    expect(locator<String>(instanceName: 'base'), 'Nested');

    await tester.pumpWidget(
      ServiceLocatorScope(
        overrides: (locator) {
          locator.registerSingleton<String>('Override', instanceName: 'base');
        },
        child: Container(),
      ),
    );

    expect(locator<String>(instanceName: 'base'), 'Override');

    await tester.pumpWidget(Container());

    expect(locator<String>(instanceName: 'base'), 'Base');
  });
}
