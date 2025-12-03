import 'package:flutter/foundation.dart';

/// Simple notifier to broadcast when sessions are updated
/// This allows different tabs to refresh their data when a session ends
class SessionNotifier extends ChangeNotifier {
  static final SessionNotifier instance = SessionNotifier._();
  SessionNotifier._();

  /// Call this when a session is created or ended
  void notifySessionsChanged() {
    notifyListeners();
  }
}
