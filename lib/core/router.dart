import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/core/user_configuration.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/screens/configurations_screen.dart';
import 'package:lispinto_chat/screens/initial_screen.dart';

part 'router.g.dart';

/// The global router instance for the application.
final router = GoRouter(
  routes: $appRoutes,
  initialLocation: '/',
  redirect: (context, state) {
    if (state.uri.path == '/') {
      final config = locator<UserConfiguration>();
      if (config.autoConnect && config.hasNickname) {
        locator<ChatProvider>().connect();
        return '/chat';
      }
    }
    return null;
  },
);

/// The initial route of the application, shown at the root path '/'.
@TypedGoRoute<InitialRoute>(
  path: '/',
  routes: [
    TypedGoRoute<ChatRoute>(
      path: 'chat',
      routes: [TypedGoRoute<ConfigurationsRoute>(path: 'config')],
    ),
  ],
)
final class InitialRoute extends GoRouteData with $InitialRoute {
  const InitialRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const InitialScreen();
}

/// The chat route, shown at the path '/chat'.
final class ChatRoute extends GoRouteData with $ChatRoute {
  const ChatRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const ChatScreen();
}

/// The configurations route, shown at the path '/chat/config'.
final class ConfigurationsRoute extends GoRouteData with $ConfigurationsRoute {
  const ConfigurationsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ConfigurationsScreen();
}
