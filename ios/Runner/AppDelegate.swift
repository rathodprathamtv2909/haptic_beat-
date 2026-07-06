import AVFoundation
import CoreHaptics
import Flutter
import Foundation
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

    configureHapticChannel(controller)
    configureAudioAnalysisChannel(controller)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureHapticChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.example.haptic_beat/haptics",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      let arguments = call.arguments as? [String: Any]
      let intensity = HapticFeedback.intensity(from: arguments)

      switch call.method {
      case "prepare":
        HapticFeedback.shared.prepare()
        result(nil)
      case "startPattern":
        let offsetsMs = HapticFeedback.intList(from: arguments?["offsetsMs"])
        let intensities = HapticFeedback.floatList(from: arguments?["intensities"])
        let strength = HapticFeedback.float(
          from: arguments?["strength"],
          defaultValue: 1
        )
        let accepted = HapticFeedback.shared.startPattern(
          offsetsMs: offsetsMs,
          intensities: intensities,
          strength: strength
        )
        result(accepted)
      case "cancelPattern":
        HapticFeedback.shared.cancelPattern()
        result(nil)
      case "triggerKick":
        HapticFeedback.shared.triggerKick(intensity: intensity)
        result(nil)
      case "triggerBass":
        HapticFeedback.shared.triggerBass(intensity: intensity)
        result(nil)
      case "triggerSnare":
        HapticFeedback.shared.triggerSnare(intensity: intensity)
        result(nil)
      case "triggerImpact":
        HapticFeedback.shared.triggerImpact(intensity: intensity)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func configureAudioAnalysisChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "com.example.haptic_beat/audio_analysis",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "analyzeFile":
        guard
          let arguments = call.arguments as? [String: Any],
          let path = arguments["path"] as? String,
          !path.isEmpty
        else {
          result(
            FlutterError(
              code: "invalid_path",
              message: "No audio file path was provided.",
              details: nil
            )
          )
          return
        }

        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let analysis = try AudioAnalyzer().analyzeFile(path: path)
            DispatchQueue.main.async {
              result(analysis.toMap())
            }
          } catch {
            DispatchQueue.main.async {
              result(
                FlutterError(
                  code: "analysis_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Native haptic performer backed by Core Haptics with UIKit fallback support.
final class HapticFeedback {
  static let shared = HapticFeedback()

  private var engine: CHHapticEngine?
  private var activePatternPlayer: CHHapticPatternPlayer?
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
  static func intensity(from arguments: [String: Any]?) -> Float {
    return float(from: arguments?["intensity"], defaultValue: 1)
  }

  static func float(from value: Any?, defaultValue: Float) -> Float {
    let rawValue: Float
    if let number = value as? NSNumber {
      rawValue = number.floatValue
    } else if let value = value as? Float {
      rawValue = value
    } else if let value = value as? Double {
      rawValue = Float(value)
    } else if let value = value as? Int {
      rawValue = Float(value)
    } else {
      rawValue = defaultValue
    }

    return min(max(rawValue, 0), 1)
  }

  static func intList(from value: Any?) -> [Int] {
    guard let values = value as? [Any] else {
      return []
    }

    return values.compactMap { item in
      if let number = item as? NSNumber {
        return number.intValue
      }
      return item as? Int
    }
  }

  static func floatList(from value: Any?) -> [Float] {
    guard let values = value as? [Any] else {
      return []
    }

    return values.compactMap { item in
      if let number = item as? NSNumber {
        return number.floatValue
      }
      if let value = item as? Float {
        return value
      }
      if let value = item as? Double {
        return Float(value)
      }
      return nil
    }
  }

  static func shapedIntensity(_ intensity: Float) -> Float {
    let value = min(max(intensity, 0), 1)
    if value <= 0.04 {
      return 0
    }

    let shaped = 0.14 + pow(Double(value), 0.68) * 0.86
    return Float(min(max(shaped, 0), 1))
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

  /// Warms the Core Haptics engine before starting audio playback.
  func prepare() {
    prepareEngine()
  }

  func startPattern(
    offsetsMs: [Int],
    intensities: [Float],
    strength: Float
  ) -> Bool {
    guard supportsCoreHaptics, !offsetsMs.isEmpty else {
      return false
    }

    do {
      try startEngineIfNeeded()
      cancelPattern()
      let pattern = try scheduledCorePattern(
        offsetsMs: offsetsMs,
        intensities: intensities,
        strength: strength
      )
      guard let player = try engine?.makePlayer(with: pattern) else {
        return false
      }

      activePatternPlayer = player
      try player.start(atTime: CHHapticTimeImmediate)
      return true
    } catch {
      activePatternPlayer = nil
      prepareEngine()
      return false
    }
  }

  func cancelPattern() {
    do {
      try activePatternPlayer?.stop(atTime: CHHapticTimeImmediate)
    } catch {
    }
    activePatternPlayer = nil
  }

  private func play(_ pattern: HapticPattern, intensity: Float) {
    let effectiveIntensity = HapticFeedback.shapedIntensity(intensity)
    guard supportsCoreHaptics else {
      playFallback(pattern, intensity: effectiveIntensity)
      return
    }

    do {
      try startEngineIfNeeded()
      let player = try engine?.makePlayer(
        with: pattern.corePattern(intensity: effectiveIntensity)
      )
      try player?.start(atTime: CHHapticTimeImmediate)
    } catch {
      playFallback(pattern, intensity: effectiveIntensity)
      prepareEngine()
    }
  }

  private func prepareEngine() {
    guard supportsCoreHaptics else {
      return
    }

    do {
      let nextEngine = try CHHapticEngine()
      nextEngine.isAutoShutdownEnabled = false
      nextEngine.stoppedHandler = { [weak self] _ in
        self?.activePatternPlayer = nil
        self?.engine = nil
      }
      nextEngine.resetHandler = { [weak self] in
        self?.activePatternPlayer = nil
        try? self?.engine?.start()
      }
      engine = nextEngine
      try nextEngine.start()
    } catch {
      activePatternPlayer = nil
      engine = nil
    }
  }

  private func startEngineIfNeeded() throws {
    if engine == nil {
      prepareEngine()
    }

    guard let engine = engine else {
      throw HapticRuntimeError.engineUnavailable
    }

    try engine.start()
  }

  private func scheduledCorePattern(
    offsetsMs: [Int],
    intensities: [Float],
    strength: Float
  ) throws -> CHHapticPattern {
    let safeStrength = HapticFeedback.shapedIntensity(strength)
    var events = [CHHapticEvent]()

    for index in offsetsMs.indices {
      let rawIntensity = index < intensities.count ? intensities[index] : 0.62
      let intensity = HapticFeedback.shapedIntensity(rawIntensity * safeStrength)
      if intensity <= 0.04 {
        continue
      }

      let time = TimeInterval(max(offsetsMs[index], 0)) / 1000.0
      let tailDuration: TimeInterval
      if intensity >= 0.84 {
        tailDuration = 0.07
      } else if intensity >= 0.62 {
        tailDuration = 0.052
      } else {
        tailDuration = 0.038
      }

      let sharpness = min(max(Float(0.18) + intensity * Float(0.48), 0), 1)
      events.append(
        CHHapticEvent(
          eventType: .hapticTransient,
          parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
          ],
          relativeTime: time
        )
      )
      events.append(
        CHHapticEvent(
          eventType: .hapticContinuous,
          parameters: [
            CHHapticEventParameter(
              parameterID: .hapticIntensity,
              value: min(intensity * Float(0.62), 1)
            ),
            CHHapticEventParameter(
              parameterID: .hapticSharpness,
              value: max(sharpness * Float(0.42), Float(0.08))
            ),
          ],
          relativeTime: time + 0.012,
          duration: tailDuration
        )
      )
    }

    if events.isEmpty {
      throw HapticRuntimeError.emptyPattern
    }

    return try CHHapticPattern(
      events: events,
      parameters: [CHHapticDynamicParameter]()
    )
  }

  private func playFallback(_ pattern: HapticPattern, intensity: Float) {
    let generator = UIImpactFeedbackGenerator(style: pattern.fallbackStyle)
    generator.prepare()
    generator.impactOccurred(intensity: CGFloat(intensity))
  }
}

private enum HapticRuntimeError: Error {
  case engineUnavailable
  case emptyPattern
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
            duration: 0.09,
            intensity: safeIntensity * 0.58,
            sharpness: 0.08
          ),
        ],
        parameters: [
          dynamic(.hapticIntensityControl, time: 0, value: safeIntensity),
          dynamic(.hapticIntensityControl, time: 0.1, value: 0),
        ]
      )
    case .bass:
      return try CHHapticPattern(
        events: [
          continuous(
            time: 0,
            duration: 0.16,
            intensity: safeIntensity * 0.82,
            sharpness: 0.04
          ),
        ],
        parameters: [
          dynamic(.hapticIntensityControl, time: 0, value: safeIntensity * 0.82),
          dynamic(.hapticIntensityControl, time: 0.14, value: safeIntensity * 0.24),
        ]
      )
    case .snare:
      return try CHHapticPattern(
        events: [
          transient(time: 0, intensity: safeIntensity * 0.94, sharpness: 0.78),
          transient(time: 0.032, intensity: safeIntensity * 0.6, sharpness: 0.92),
        ],
        parameters: [CHHapticDynamicParameter]()
      )
    case .impact:
      return try CHHapticPattern(
        events: [
          transient(time: 0, intensity: safeIntensity, sharpness: 0.52),
          continuous(
            time: 0.025,
            duration: 0.13,
            intensity: safeIntensity * 0.66,
            sharpness: 0.24
          ),
        ],
        parameters: [
          dynamic(.hapticIntensityControl, time: 0, value: safeIntensity),
          dynamic(.hapticIntensityControl, time: 0.15, value: 0),
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

private final class AudioAnalyzer {
  func analyzeFile(path: String) throws -> AudioAnalysisResult {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .audio).first else {
      return .empty()
    }

    let sampleRate = Self.sampleRate(for: track)
    let channelCount = Self.channelCount(for: track)
    let reader = try AVAssetReader(asset: asset)
    let outputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVLinearPCMIsFloatKey: true,
      AVLinearPCMBitDepthKey: 32,
      AVLinearPCMIsNonInterleaved: false,
      AVLinearPCMIsBigEndianKey: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
    output.alwaysCopiesSampleData = false

    guard reader.canAdd(output) else {
      return .empty()
    }
    reader.add(output)

    let collector = EnergyCollector(sampleRate: sampleRate)
    guard reader.startReading() else {
      throw reader.error ?? AudioAnalysisError.readerFailed
    }

    while reader.status == .reading {
      guard let sampleBuffer = output.copyNextSampleBuffer() else {
        break
      }

      collector.consume(sampleBuffer: sampleBuffer, channelCount: channelCount)
      CMSampleBufferInvalidate(sampleBuffer)
    }

    if reader.status == .failed {
      throw reader.error ?? AudioAnalysisError.readerFailed
    }

    collector.finish()
    let durationSeconds = CMTimeGetSeconds(asset.duration)
    let durationMs = durationSeconds.isFinite && durationSeconds > 0
      ? Int64(durationSeconds * 1000)
      : collector.durationMs()

    return buildBeatMap(
      energies: collector.energies,
      frameMs: EnergyCollector.frameDurationMs,
      durationMs: durationMs
    )
  }

  private static func sampleRate(for track: AVAssetTrack) -> Int {
    guard
      let format = track.formatDescriptions.first as? CMAudioFormatDescription,
      let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)
    else {
      return 44_100
    }

    return max(Int(description.pointee.mSampleRate.rounded()), 8_000)
  }

  private static func channelCount(for track: AVAssetTrack) -> Int {
    guard
      let format = track.formatDescriptions.first as? CMAudioFormatDescription,
      let description = CMAudioFormatDescriptionGetStreamBasicDescription(format)
    else {
      return 1
    }

    return max(Int(description.pointee.mChannelsPerFrame), 1)
  }
}

private enum AudioAnalysisError: LocalizedError {
  case readerFailed

  var errorDescription: String? {
    return "Audio analysis failed."
  }
}

private func buildBeatMap(
  energies: [Double],
  frameMs: Int,
  durationMs: Int64
) -> AudioAnalysisResult {
  if energies.count < 24 {
    return .empty()
  }

  var smooth = Array(repeating: 0.0, count: energies.count)
  for index in energies.indices {
    let previous = index > 0 ? energies[index - 1] : energies[index]
    let current = energies[index]
    let next = index < energies.count - 1 ? energies[index + 1] : energies[index]
    smooth[index] = (previous + current * 2.0 + next) / 4.0
  }

  var onset = Array(repeating: 0.0, count: smooth.count)
  for index in 1..<smooth.count {
    onset[index] = max(0.0, smooth[index] - smooth[index - 1])
  }

  let candidates = pickTransientCandidates(
    onset: onset,
    smoothEnergy: smooth,
    frameMs: frameMs
  )
  if candidates.count < 4 {
    return fallbackBeatMap(durationMs: durationMs, bpm: 128)
  }

  let bpm = min(max(estimateBpm(candidates: candidates), 55), 190)
  let confidence = estimateConfidence(candidates: candidates, bpm: bpm)
  let strongCandidates = thinCandidates(candidates: candidates, minSpacingMs: 160)
  let beatTimes = strongCandidates.map { $0.timeMs }
  let beatIntensities = strongCandidates.map { $0.intensity }

  return AudioAnalysisResult(
    bpm: bpm,
    confidence: confidence,
    beatTimesMs: beatTimes,
    beatIntensities: beatIntensities
  )
}

private func pickTransientCandidates(
  onset: [Double],
  smoothEnergy: [Double],
  frameMs: Int
) -> [BeatCandidate] {
  let mean = onset.reduce(0.0, +) / Double(onset.count)
  let variance = onset.reduce(0.0) { sum, value in
    sum + (value - mean) * (value - mean)
  } / Double(onset.count)
  let deviation = sqrt(variance)
  let maxOnset = onset.max() ?? 0.0
  let threshold = max(mean + deviation * 0.48, maxOnset * 0.12)
  var candidates = [BeatCandidate]()

  if onset.count <= 4 {
    return candidates
  }

  for index in 2..<(onset.count - 2) {
    let value = onset[index]
    if value < threshold {
      continue
    }

    if value < onset[index - 1] || value < onset[index + 1] {
      continue
    }

    let localEnergy = smoothEnergy[index]
    let normalized = maxOnset <= 0 ? 0 : value / maxOnset
    let intensity = min(max(0.42 + normalized * 0.56 + localEnergy * 0.28, 0.38), 1.0)
    candidates.append(
      BeatCandidate(timeMs: index * frameMs, intensity: intensity)
    )
  }

  return thinCandidates(candidates: candidates, minSpacingMs: 140)
}

private func thinCandidates(
  candidates: [BeatCandidate],
  minSpacingMs: Int
) -> [BeatCandidate] {
  var thinned = [BeatCandidate]()

  for candidate in candidates {
    if
      let last = thinned.last,
      candidate.timeMs - last.timeMs < minSpacingMs
    {
      if candidate.intensity > last.intensity {
        thinned[thinned.count - 1] = candidate
      }
    } else {
      thinned.append(candidate)
    }
  }

  return thinned
}

private func estimateBpm(candidates: [BeatCandidate]) -> Int {
  var histogram = [Int: Double]()

  for outer in candidates.indices {
    let upperBound = min(candidates.count, outer + 18)
    if outer + 1 >= upperBound {
      continue
    }

    for inner in (outer + 1)..<upperBound {
      let interval = candidates[inner].timeMs - candidates[outer].timeMs
      if interval > 2600 {
        break
      }

      for division in 1...4 {
        let baseInterval = Double(interval) / Double(division)
        if baseInterval < 315 || baseInterval > 1090 {
          continue
        }

        let bpm = min(max(Int((60_000.0 / baseInterval).rounded()), 55), 190)
        let weight = candidates[outer].intensity * candidates[inner].intensity / Double(division)
        histogram[bpm] = (histogram[bpm] ?? 0) + weight
      }
    }
  }

  return histogram.max { $0.value < $1.value }?.key ?? 128
}

private func estimateConfidence(
  candidates: [BeatCandidate],
  bpm: Int
) -> Double {
  let beatMs = 60_000.0 / Double(bpm)
  var aligned = 0.0
  var total = 0.0

  for index in 1..<candidates.count {
    let interval = candidates[index].timeMs - candidates[index - 1].timeMs
    if interval <= 0 {
      continue
    }

    let nearest = max(Int((Double(interval) / beatMs).rounded()), 1)
    let expected = beatMs * Double(nearest)
    let error = abs(Double(interval) - expected) / beatMs
    let score = (1.0 - min(max(error, 0), 1)) * candidates[index].intensity
    aligned += score
    total += candidates[index].intensity
  }

  if total <= 0 {
    return 0.55
  }

  return min(max(aligned / total, 0.42), 0.97)
}

private func fallbackBeatMap(durationMs: Int64, bpm: Int) -> AudioAnalysisResult {
  let beatMs = Int((60_000.0 / Double(bpm)).rounded())
  var beatTimes = [Int]()
  var beatIntensities = [Double]()
  var timeMs = 0
  var index = 0
  let safeDurationMs = Int(max(durationMs, 180_000))

  while timeMs <= safeDurationMs {
    beatTimes.append(timeMs)
    beatIntensities.append(index % 4 == 0 ? 0.76 : 0.52)
    timeMs += beatMs
    index += 1
  }

  return AudioAnalysisResult(
    bpm: bpm,
    confidence: 0.38,
    beatTimesMs: beatTimes,
    beatIntensities: beatIntensities
  )
}

private final class EnergyCollector {
  static let frameDurationMs = 20

  private var frameSamples: Int
  private var frameEnergy = 0.0
  private var frameSampleCount = 0
  private var totalSamples: Int64 = 0
  private let sampleRate: Int
  var energies = [Double]()

  init(sampleRate: Int) {
    self.sampleRate = max(sampleRate, 8_000)
    frameSamples = max(256, self.sampleRate * Self.frameDurationMs / 1000)
  }

  func consume(sampleBuffer: CMSampleBuffer, channelCount: Int) {
    guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
      return
    }

    let length = CMBlockBufferGetDataLength(blockBuffer)
    if length <= 0 {
      return
    }

    var data = Data(count: length)
    let status = data.withUnsafeMutableBytes { buffer -> OSStatus in
      guard let baseAddress = buffer.baseAddress else {
        return OSStatus(-1)
      }
      return CMBlockBufferCopyDataBytes(
        blockBuffer,
        atOffset: 0,
        dataLength: length,
        destination: baseAddress
      )
    }

    guard status == kCMBlockBufferNoErr else {
      return
    }

    let safeChannelCount = max(channelCount, 1)
    data.withUnsafeBytes { buffer in
      let samples = buffer.bindMemory(to: Float.self)
      var index = 0

      while index + safeChannelCount <= samples.count {
        var mixed = 0.0
        for channel in 0..<safeChannelCount {
          let sample = Double(samples[index + channel])
          mixed += min(max(sample, -1), 1)
        }

        addMonoSample(mixed / Double(safeChannelCount))
        index += safeChannelCount
      }
    }
  }

  func finish() {
    if frameSampleCount > 0 {
      energies.append(
        min(max(sqrt(frameEnergy / Double(frameSampleCount)), 0), 1)
      )
    }
  }

  func durationMs() -> Int64 {
    return (totalSamples * 1000) / Int64(sampleRate)
  }

  private func addMonoSample(_ sample: Double) {
    let shaped = min(max(abs(sample), 0), 1)
    frameEnergy += shaped * shaped
    frameSampleCount += 1
    totalSamples += 1

    if frameSampleCount >= frameSamples {
      energies.append(
        min(max(sqrt(frameEnergy / Double(frameSampleCount)), 0), 1)
      )
      frameEnergy = 0
      frameSampleCount = 0
    }
  }
}

private struct BeatCandidate {
  let timeMs: Int
  let intensity: Double
}

private struct AudioAnalysisResult {
  let bpm: Int
  let confidence: Double
  let beatTimesMs: [Int]
  let beatIntensities: [Double]

  func toMap() -> [String: Any] {
    return [
      "bpm": bpm,
      "confidence": confidence,
      "beatTimesMs": beatTimesMs,
      "beatIntensities": beatIntensities,
    ]
  }

  static func empty() -> AudioAnalysisResult {
    return AudioAnalysisResult(
      bpm: 128,
      confidence: 0,
      beatTimesMs: [],
      beatIntensities: []
    )
  }
}
