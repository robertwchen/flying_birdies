import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player settings event for stream
enum PlayerSettingsEventType { handednessChanged, nameChanged, avatarChanged }

class PlayerSettingsEvent {
  final PlayerSettingsEventType type;
  final DateTime timestamp;
  final dynamic data;

  PlayerSettingsEvent({
    required this.type,
    required this.timestamp,
    this.data,
  });
}

/// Manages player settings state and notifies listeners of changes
class PlayerSettingsNotifier extends ChangeNotifier {
  bool _isRightHanded = true;
  String? _playerName;
  int _avatarColorIndex = 0;

  bool get isRightHanded => _isRightHanded;
  String? get playerName => _playerName;
  int get avatarColorIndex => _avatarColorIndex;

  /// Load settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final handedness = prefs.getString('player_handedness') ?? 'right';
      final name = prefs.getString('player_name');
      final colorIndex = prefs.getInt('player_avatar_color') ?? 0;

      _isRightHanded = handedness == 'right';
      _playerName = name;
      _avatarColorIndex = colorIndex;

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load player settings: $e');
    }
  }

  /// Update handedness setting
  Future<void> setHandedness(bool isRightHanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'player_handedness',
        isRightHanded ? 'right' : 'left',
      );

      _isRightHanded = isRightHanded;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save handedness: $e');
    }
  }

  /// Update player name
  Future<void> setPlayerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_name', name);

      _playerName = name;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save player name: $e');
    }
  }

  /// Update avatar color
  Future<void> setAvatarColor(int colorIndex) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('player_avatar_color', colorIndex);

      _avatarColorIndex = colorIndex;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to save avatar color: $e');
    }
  }
}
