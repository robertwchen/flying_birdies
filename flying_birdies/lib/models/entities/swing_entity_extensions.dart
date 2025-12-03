import 'swing_entity.dart';

/// Extension methods for SwingEntity to provide convenient metric access
extension SwingEntityMetrics on SwingEntity {
  /// Get swing speed in km/h (converted from m/s)
  double get maxVtipKmh => maxVtip * 3.6;

  /// Get swing force (using impactSeverity as proxy)
  double get swingForce => impactSeverity;

  /// Get acceleration (m/s²)
  double get acceleration => impactAmax;

  /// Get impact force (N)
  double get impactForce => estForceN;
}
