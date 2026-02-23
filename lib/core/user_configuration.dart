import 'package:shared_preferences/shared_preferences.dart';

/// Manages user configuration such as nickname and server URL.
///
/// This class provides methods to load and save user preferences using
/// the `shared_preferences` package. It abstracts away the details of how the
/// configuration is stored and provides a simple API for the rest of the app to
/// access and modify user settings.
final class UserConfiguration {
  /// Creates a [UserConfiguration].
  const UserConfiguration({required SharedPreferences preferences})
    : _preferences = preferences;

  static const String _keyNickname = 'nickname';
  static const String _keyServerUrl = 'server_url';
  static const String _defaultServerUrl = 'wss://chat.manoel.dev/ws';

  final SharedPreferences _preferences;

  /// Loads the user configuration from shared preferences.
  static Future<UserConfiguration> load() async {
    final preferences = await SharedPreferences.getInstance();
    return UserConfiguration(preferences: preferences);
  }

  /// Gets the nickname from shared preferences.
  String get nickname => _preferences.getString(_keyNickname) ?? '';

  /// Saves the nickname to shared preferences.
  Future<void> setNickname(String value) async {
    await _preferences.setString(_keyNickname, value);
  }

  /// Gets the server URL from shared preferences.
  ///
  /// If not set, returns the default server URL.
  String get serverUrl {
    return _preferences.getString(_keyServerUrl) ?? _defaultServerUrl;
  }

  /// Saves the server URL to shared preferences.
  Future<void> setServerUrl(String value) async {
    await _preferences.setString(_keyServerUrl, value);
  }

  /// Returns true if the user has set a non-empty nickname.
  bool get hasNickname => nickname.trim().isNotEmpty;
}
