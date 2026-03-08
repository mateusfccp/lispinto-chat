import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lispinto_chat/core/service_locator.dart';
import 'package:lispinto_chat/providers/chat_provider.dart';
import 'package:lispinto_chat/screens/chat_screen.dart';
import 'package:lispinto_chat/screens/configurations_screen.dart';
import 'package:lispinto_chat/screens/initial_screen.dart';
import 'package:lispinto_chat/screens/licenses_screen.dart';
import 'package:lispinto_chat/screens/privacy_policy_screen.dart';
import 'package:logging/logging.dart';

part 'router.g.dart';

/// Creates the router for the application.
GoRouter createRouter() {
  return GoRouter(
    routes: $appRoutes,
    initialLocation: '/',
    refreshListenable: locator<ChatProvider>(),
    redirect: (context, state) {
      final provider = locator<ChatProvider>();
      final logger = locator<Logger>();
      final isAtInitial = state.uri.path == '/';
      final isAtChat = state.uri.path.startsWith('/chat');

      // 1. Logged in state -> Navigate to Chat
      if (isAtInitial && provider.isLoggedIn) {
        logger.info('Redirecting to /chat (User is already connected)');
        return '/chat';
      }

      // 1b. Auto-connect enabled -> Navigate to Chat on startup
      if (isAtInitial &&
          provider.configuration.autoConnect &&
          provider.configuration.hasNickname) {
        logger.info('Redirecting to /chat (Auto-connect is enabled)');
        return '/chat';
      }

      // 2. Logged out state -> Navigate to Initial
      if (!provider.isLoggedIn && isAtChat) {
        if (provider.isConnecting) {
          return null;
        }

        // Only redirect to Initial if at the root chat screen.
        // This allows remaining on utility screens (config, licenses, etc.)
        // while the connection is resetting.
        if (state.uri.path == '/chat') {
          logger.info('Redirecting to / (User disconnected)');
          return '/';
        }
      }

      return null;
    },
  );
}

/// The initial route of the application, shown at the root path '/'.
@TypedGoRoute<InitialRoute>(
  path: '/',
  routes: [
    TypedGoRoute<InitialPrivacyPolicyRoute>(path: 'privacy-policy'),
    TypedGoRoute<ChatRoute>(
      path: 'chat',
      routes: [
        TypedGoRoute<ConfigurationsRoute>(path: 'config'),
        TypedGoRoute<PrivacyPolicyRoute>(path: 'privacy-policy'),
        TypedGoRoute<LicensesRoute>(path: 'licenses'),
      ],
    ),
  ],
)
final class InitialRoute extends GoRouteData with $InitialRoute {
  const InitialRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const InitialScreen();
  }
}

/// The privacy policy route accessible from the initial screen.
final class InitialPrivacyPolicyRoute extends GoRouteData
    with $InitialPrivacyPolicyRoute {
  const InitialPrivacyPolicyRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PrivacyPolicyScreen();
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
  Widget build(BuildContext context, GoRouterState state) {
    return const ConfigurationsScreen();
  }
}

/// The privacy policy route, shown at the path '/chat/privacy-policy'.
final class PrivacyPolicyRoute extends GoRouteData with $PrivacyPolicyRoute {
  const PrivacyPolicyRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const PrivacyPolicyScreen();
  }
}

/// The licenses route, shown at the path '/chat/licenses'.
final class LicensesRoute extends GoRouteData with $LicensesRoute {
  const LicensesRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const LicensesScreen();
  }
}
