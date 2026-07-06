import 'package:flutter/services.dart';

/// A bridge for triggering lightweight haptic feedback from Flutter.
class HapticService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.haptic_beat/haptics',
  );

  /// Triggers a kick-style haptic transient.
  static Future<void> triggerKick({double intensity = 1}) async {
    await _invoke('triggerKick', intensity: intensity);
  }

  /// Triggers a rounded bass haptic pulse.
  static Future<void> triggerBass({double intensity = 1}) async {
    await _invoke('triggerBass', intensity: intensity);
  }

  /// Triggers a sharper snare-style haptic transient.
  static Future<void> triggerSnare({double intensity = 1}) async {
    await _invoke('triggerSnare', intensity: intensity);
  }

  /// Triggers a strong confirmation haptic.
  static Future<void> triggerImpact({double intensity = 1}) async {
    await _invoke('triggerImpact', intensity: intensity);
  }

  static Future<void> _invoke(
    String method, {
    required double intensity,
  }) async {
    try {
      final normalizedIntensity = intensity.clamp(0.0, 1.0).toDouble();
      await _channel.invokeMethod<void>(method, {
        'intensity': normalizedIntensity,
      });
    } on MissingPluginException {
      return;
    }
  }
}
