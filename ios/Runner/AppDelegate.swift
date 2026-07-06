import CoreHaptics
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(
      name: "com.example.haptic_beat/haptics",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      let intensity = HapticFeedback.intensity(from: call.arguments)

      switch call.method {
      case "triggerKick":
        HapticFeedback.shared.triggerKick(intensity: intensity); result(nil)
      case "triggerBass":
        HapticFeedback.shared.triggerBass(intensity: intensity); result(nil)
      case "triggerSnare":
        HapticFeedback.shared.triggerSnare(intensity: intensity); result(nil)
      case "triggerImpact":
        HapticFeedback.shared.triggerImpact(intensity: intensity); result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Native haptic performer backed by Core Haptics with UIKit fallback support.
final class HapticFeedback {
  static let shared = HapticFeedback()

  private var engine: CHHapticEngine?
  private let supportsCoreHaptics: Bool

  private init() {
    if #available(iOS 13.0, *) {
      supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
      prepareEngine()
    } else {
      supportsCoreHaptics = false
    }
  }

  /// Extracts a normalized intensity argument from Flutter method calls.
  static func intensity(from arguments: Any?) -> Float {
    guard
      let arguments = arguments as? [String: Any],
      let value = arguments["intensity"] as? NSNumber
    else {
      return 1
    }

    return min(max(value.floatValue, 0), 1)
  }

  /// Plays a kick-style low transient with a short resonant tail.
  func triggerKick(intensity: Float) {
    play(.kick, intensity: intensity)
  }

  /// Plays a rounded bass pulse with low sharpness.
  func triggerBass(intensity: Float) {
    play(.bass, intensity: intensity)
  }

  /// Plays a sharp snare-like double transient.
  func triggerSnare(intensity: Float) {
    play(.snare, intensity: intensity)
  }

  /// Plays a strong confirmation impact.
  func triggerImpact(intensity: Float) {
    play(.impact, intensity: intensity)
  }

  private func play(_ pattern: HapticPattern, intensity: Float) {
    guard supportsCoreHaptics else {
      playFallback(pattern, intensity: intensity)
      return
    }

    do {
      try startEngineIfNeeded()
      let player = try engine?.makePlayer(with: pattern.corePattern(intensity: intensity))
      try player?.start(atTime: CHHapticTimeImmediate)
    } catch {
      playFallback(pattern, intensity: intensity)
      prepareEngine()
    }
  }

  private func prepareEngine() {
    guard supportsCoreHaptics else {
      return
    }

    do {
      let engine = try CHHapticEngine()
      engine.isAutoShutdownEnabled = true
      engine.stoppedHandler = { [weak self] _ in
        self?.engine = nil
      }
      engine.resetHandler = { [weak self] in
        try? self?.engine?.start()
      }
      self.engine = engine
      try engine.start()
    } catch {
      engine = nil
    }
  }

  private func startEngineIfNeeded() throws {
    if engine == nil {
      prepareEngine()
    }
    try engine?.start()
  }

  private func playFallback(_ pattern: HapticPattern, intensity: Float) {
    let generator = UIImpactFeedbackGenerator(style: pattern.fallbackStyle)
    generator.prepare()
    generator.impactOccurred(intensity: CGFloat(intensity))
  }
}

/// Musical haptic pattern descriptions mapped to Core Haptics events.
private enum HapticPattern {
  case kick
  case bass
  case snare
  case impact

  var fallbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
    switch self {
    case .kick:
      return .heavy
    case .bass:
      return .soft
    case .snare:
      return .medium
    case .impact:
      return .rigid
    }
  }

  func corePattern(intensity: Float) throws -> CHHapticPattern {
    let safeIntensity = min(max(intensity, 0), 1)

    switch self {
    case .kick:
      return try CHHapticPattern(
        events: [
          transient(time: 0, intensity: safeIntensity, sharpness: 0.18),
          continuous(
            time: 0.018,
            duration: 0.075,
            intensity: safeIntensity * 0.42,
            sharpness: 0.08
          ),
        ],
        parameters: [
          dynamic(.hapticIntensityControl, time: 0, value: safeIntensity),
          dynamic(.hapticIntensityControl, time: 0.08, value: 0),
        ]
      )
    case .bass:
      return try CHHapticPattern(
        events: [
          continuous(
            time: 0,
            duration: 0.14,
            intensity: safeIntensity * 0.72,
            sharpness: 0.04
          ),
        ],
        parameters: [
          dynamic(.hapticIntensityControl, time: 0, value: safeIntensity * 0.72),
          dynamic(.hapticIntensityControl, time: 0.12, value: safeIntensity * 0.18),
        ]
      )
    case .snare:
      return try CHHapticPattern(
        events: [
          transient(time: 0, intensity: safeIntensity * 0.86, sharpness: 0.78),
          transient(time: 0.035, intensity: safeIntensity * 0.48, sharpness: 0.92),
        ],
        parameters: []
      )
    case .impact:
      return try CHHapticPattern(
        events: [
          transient(time: 0, intensity: safeIntensity, sharpness: 0.52),
          continuous(
            time: 0.025,
            duration: 0.11,
            intensity: safeIntensity * 0.52,
            sharpness: 0.24
          ),
        ],
        parameters: [
          dynamic(.hapticIntensityControl, time: 0, value: safeIntensity),
          dynamic(.hapticIntensityControl, time: 0.13, value: 0),
        ]
      )
    }
  }

  private func transient(
    time: TimeInterval,
    intensity: Float,
    sharpness: Float
  ) -> CHHapticEvent {
    return CHHapticEvent(
      eventType: .hapticTransient,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: time
    )
  }

  private func continuous(
    time: TimeInterval,
    duration: TimeInterval,
    intensity: Float,
    sharpness: Float
  ) -> CHHapticEvent {
    return CHHapticEvent(
      eventType: .hapticContinuous,
      parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
      ],
      relativeTime: time,
      duration: duration
    )
  }

  private func dynamic(
    _ parameterID: CHHapticDynamicParameter.ID,
    time: TimeInterval,
    value: Float
  ) -> CHHapticDynamicParameter {
    return CHHapticDynamicParameter(
      parameterID: parameterID,
      value: value,
      relativeTime: time
    )
  }
}
