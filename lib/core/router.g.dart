// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'router.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$initialRoute];

RouteBase get $initialRoute => GoRouteData.$route(
  path: '/',
  factory: $InitialRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'privacy-policy',
      factory: $InitialPrivacyPolicyRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'chat',
      factory: $ChatRoute._fromState,
      routes: [
        GoRouteData.$route(
          path: 'config',
          factory: $ConfigurationsRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'privacy-policy',
          factory: $PrivacyPolicyRoute._fromState,
        ),
        GoRouteData.$route(
          path: 'licenses',
          factory: $LicensesRoute._fromState,
        ),
      ],
    ),
  ],
);

mixin $InitialRoute on GoRouteData {
  static InitialRoute _fromState(GoRouterState state) => const InitialRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $InitialPrivacyPolicyRoute on GoRouteData {
  static InitialPrivacyPolicyRoute _fromState(GoRouterState state) =>
      const InitialPrivacyPolicyRoute();

  @override
  String get location => GoRouteData.$location('/privacy-policy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ChatRoute on GoRouteData {
  static ChatRoute _fromState(GoRouterState state) => const ChatRoute();

  @override
  String get location => GoRouteData.$location('/chat');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ConfigurationsRoute on GoRouteData {
  static ConfigurationsRoute _fromState(GoRouterState state) =>
      const ConfigurationsRoute();

  @override
  String get location => GoRouteData.$location('/chat/config');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $PrivacyPolicyRoute on GoRouteData {
  static PrivacyPolicyRoute _fromState(GoRouterState state) =>
      const PrivacyPolicyRoute();

  @override
  String get location => GoRouteData.$location('/chat/privacy-policy');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $LicensesRoute on GoRouteData {
  static LicensesRoute _fromState(GoRouterState state) => const LicensesRoute();

  @override
  String get location => GoRouteData.$location('/chat/licenses');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
