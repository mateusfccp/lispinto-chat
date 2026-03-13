import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages user configuration such as nickname and server URL.
abstract class UserConfiguration with ChangeNotifier {
  /// Gets the nickname from shared preferences.
  abstract String nickname;

  /// Gets the server URL from shared preferences.
  abstract String serverUrl;

  /// Gets the ImgBB API key from shared preferences.
  abstract String imgbbApiKey;

  /// Returns true if the user has set a non-empty nickname.
  bool get hasNickname;

  /// Whether push notifications are enabled.
  abstract bool pushNotificationsEnabled;

  /// Whether mention notifications are enabled.
  abstract bool mentionNotificationsEnabled;

  /// Whether the user wants to automatically skip the initial screen on startup.
  abstract bool autoConnect;

  /// Whether to show seconds in message timestamps.
  abstract bool showTimeSeconds;

  /// Whether to show image previews for URLs.
  abstract bool showImagePreviews;

  /// Whether to show empty channels in the channel list.
  abstract bool showEmptyChannels;

  /// Whether to enable markdown-like styling.
  abstract bool showMarkdown;

  /// Whether to group sequential messages from the same user at the same time.
  abstract bool groupMessages;

  /// Gets the last joined channel.
  abstract String lastChannel;

  /// Loads the persistent user configuration.
  static Future<UserConfiguration> load() => PersistentUserConfiguration.load();

  /// Updates this configuration with values from another configuration.
  ///
  /// It avoids notifying listeners until all values are updated, which is
  /// useful when loading a new configuration from persistent storage or when
  /// applying a batch of changes at once.
  void updateWith(UserConfiguration other);
}

/// Persistent implementation of [UserConfiguration] using [SharedPreferences].
final class PersistentUserConfiguration extends UserConfiguration {
  /// Creates a [PersistentUserConfiguration].
  PersistentUserConfiguration({required SharedPreferences preferences})
    : _preferences = preferences,
      _nickname = preferences.getString(_keyNickname) ?? '',
      _serverUrl = preferences.getString(_keyServerUrl) ?? _defaultServerUrl,
      _pushNotificationsEnabled =
          preferences.getBool(_keyPushNotifications) ?? false,
      _mentionNotificationsEnabled =
          preferences.getBool(_keyMentionNotifications) ?? false,
      _autoConnect = preferences.getBool(_keyAutoConnect) ?? false,
      _showTimeSeconds = preferences.getBool(_keyShowTimeSeconds) ?? false,
      _showImagePreviews = preferences.getBool(_keyShowImagePreviews) ?? true,
      _showEmptyChannels = preferences.getBool(_keyShowEmptyChannels) ?? false,
      _showMarkdown = preferences.getBool(_keyShowMarkdown) ?? true,
      _groupMessages = preferences.getBool(_keyGroupMessages) ?? true,
      _lastChannel = preferences.getString(_keyLastChannel) ?? 'general',
      _imgbbApiKey = preferences.getString(_keyImgbbApiKey) ?? '';

  static const String _keyNickname = 'nickname';
  static const String _keyServerUrl = 'server_url';
  static const String _keyPushNotifications = 'push_notifications';
  static const String _keyMentionNotifications = 'mention_notifications';
  static const String _keyAutoConnect = 'auto_connect';
  static const String _keyShowTimeSeconds = 'show_time_seconds';
  static const String _keyShowImagePreviews = 'show_image_previews';
  static const String _keyShowEmptyChannels = 'show_empty_channels';
  static const String _keyShowMarkdown = 'show_markdown';
  static const String _keyGroupMessages = 'group_messages';
  static const String _keyLastChannel = 'last_channel';
  static const String _keyImgbbApiKey = 'imgbb_api_key';
  static const String _defaultServerUrl = 'https://chat.manoel.dev';

  final SharedPreferences _preferences;

  /// Loads the user configuration from shared preferences.
  static Future<PersistentUserConfiguration> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return PersistentUserConfiguration(preferences: preferences);
    } catch (exception, stackTrace) {
      Logger(
        'UserConfiguration',
      ).severe('Failed to load SharedPreferences', exception, stackTrace);
      rethrow;
    }
  }

  @override
  String get nickname => _nickname;
  String _nickname;

  @override
  set nickname(String value) {
    _nickname = value;
    unawaited(_preferences.setString(_keyNickname, value));
    notifyListeners();
  }

  @override
  String get serverUrl => _serverUrl;
  String _serverUrl;

  @override
  set serverUrl(String value) {
    _serverUrl = value;
    unawaited(_preferences.setString(_keyServerUrl, value));
    notifyListeners();
  }

  @override
  String get imgbbApiKey => _imgbbApiKey;
  String _imgbbApiKey;

  @override
  set imgbbApiKey(String value) {
    _imgbbApiKey = value;
    unawaited(_preferences.setString(_keyImgbbApiKey, value));
    notifyListeners();
  }

  @override
  bool get hasNickname => nickname.trim().isNotEmpty;

  @override
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;
  bool _pushNotificationsEnabled;

  @override
  set pushNotificationsEnabled(bool value) {
    _pushNotificationsEnabled = value;
    unawaited(_preferences.setBool(_keyPushNotifications, value));
    notifyListeners();
  }

  @override
  bool get mentionNotificationsEnabled => _mentionNotificationsEnabled;
  bool _mentionNotificationsEnabled;

  @override
  set mentionNotificationsEnabled(bool value) {
    _mentionNotificationsEnabled = value;
    unawaited(_preferences.setBool(_keyMentionNotifications, value));
    notifyListeners();
  }

  @override
  bool get autoConnect => _autoConnect;
  bool _autoConnect;

  @override
  set autoConnect(bool value) {
    _autoConnect = value;
    unawaited(_preferences.setBool(_keyAutoConnect, value));
    notifyListeners();
  }

  @override
  bool get showTimeSeconds => _showTimeSeconds;
  bool _showTimeSeconds;

  @override
  set showTimeSeconds(bool value) {
    _showTimeSeconds = value;
    unawaited(_preferences.setBool(_keyShowTimeSeconds, value));
    notifyListeners();
  }

  @override
  bool get showImagePreviews => _showImagePreviews;
  bool _showImagePreviews;

  @override
  set showImagePreviews(bool value) {
    _showImagePreviews = value;
    unawaited(_preferences.setBool(_keyShowImagePreviews, value));
    notifyListeners();
  }

  @override
  bool get showEmptyChannels => _showEmptyChannels;
  bool _showEmptyChannels;

  @override
  set showEmptyChannels(bool value) {
    _showEmptyChannels = value;
    unawaited(_preferences.setBool(_keyShowEmptyChannels, value));
    notifyListeners();
  }

  @override
  bool get showMarkdown => _showMarkdown;
  bool _showMarkdown;

  @override
  set showMarkdown(bool value) {
    _showMarkdown = value;
    unawaited(_preferences.setBool(_keyShowMarkdown, value));
    notifyListeners();
  }

  @override
  bool get groupMessages => _groupMessages;
  bool _groupMessages;

  @override
  set groupMessages(bool value) {
    _groupMessages = value;
    unawaited(_preferences.setBool(_keyGroupMessages, value));
    notifyListeners();
  }

  @override
  String get lastChannel => _lastChannel;
  String _lastChannel;

  @override
  set lastChannel(String value) {
    _lastChannel = value;
    unawaited(_preferences.setString(_keyLastChannel, value));
    notifyListeners();
  }

  @override
  void updateWith(UserConfiguration other) {
    _nickname = other.nickname;
    unawaited(_preferences.setString(_keyNickname, _nickname));

    _serverUrl = other.serverUrl;
    unawaited(_preferences.setString(_keyServerUrl, _serverUrl));

    _imgbbApiKey = other.imgbbApiKey;
    unawaited(_preferences.setString(_keyImgbbApiKey, _imgbbApiKey));

    _pushNotificationsEnabled = other.pushNotificationsEnabled;
    unawaited(
      _preferences.setBool(_keyPushNotifications, _pushNotificationsEnabled),
    );

    _mentionNotificationsEnabled = other.mentionNotificationsEnabled;
    unawaited(
      _preferences.setBool(
        _keyMentionNotifications,
        _mentionNotificationsEnabled,
      ),
    );

    _autoConnect = other.autoConnect;
    unawaited(_preferences.setBool(_keyAutoConnect, _autoConnect));

    _showTimeSeconds = other.showTimeSeconds;
    unawaited(_preferences.setBool(_keyShowTimeSeconds, _showTimeSeconds));

    _showImagePreviews = other.showImagePreviews;
    unawaited(_preferences.setBool(_keyShowImagePreviews, _showImagePreviews));

    _showEmptyChannels = other.showEmptyChannels;
    unawaited(_preferences.setBool(_keyShowEmptyChannels, _showEmptyChannels));

    _showMarkdown = other.showMarkdown;
    unawaited(_preferences.setBool(_keyShowMarkdown, _showMarkdown));

    _groupMessages = other.groupMessages;
    unawaited(_preferences.setBool(_keyGroupMessages, _groupMessages));

    _lastChannel = other.lastChannel;
    unawaited(_preferences.setString(_keyLastChannel, _lastChannel));

    notifyListeners();
  }
}
