import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/services/audio_analysis_service.dart';
import 'package:haptic_beat/services/audio_service.dart';
import 'package:haptic_beat/services/haptic_service.dart';
import 'package:haptic_beat/services/music_import_service.dart';

/// Provides the player view model that drives the immersive playback surfaces.
final playerViewModelProvider =
    StateNotifierProvider<PlayerViewModel, PlayerViewState>((ref) {
      return PlayerViewModel();
    });

/// Visualizer layouts available in the player experience.
enum VisualizerMode { waveform, circular, spectrum, particles }

/// User-facing metadata for a visualizer mode.
extension VisualizerModeLabel on VisualizerMode {
  /// Short label sized for segmented controls.
  String get label {
    return switch (this) {
      VisualizerMode.waveform => 'Wave',
      VisualizerMode.circular => 'Circle',
      VisualizerMode.spectrum => 'Bars',
      VisualizerMode.particles => 'Field',
    };
  }
}

/// Describes the currently loaded track shown across home and player screens.
class PlayerTrack {
  /// Creates an immutable track descriptor.
  const PlayerTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.sourceLabel,
    this.accentColor = AppTheme.accent,
  });

  /// Track title displayed as the primary label.
  final String title;

  /// Artist name displayed below the title.
  final String artist;

  /// Album or collection name.
  final String album;

  /// Source label, such as Local File or HapticBeat Session.
  final String sourceLabel;

  /// Dominant artwork color used by glowing UI elements.
  final Color accentColor;

  /// Returns a copy with selected fields changed.
  PlayerTrack copyWith({
    String? title,
    String? artist,
    String? album,
    String? sourceLabel,
    Color? accentColor,
  }) {
    return PlayerTrack(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

/// Compact realtime metric shown in the player dashboard.
class PlayerMetric {
  /// Creates an immutable metric chip.
  const PlayerMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  /// Short metric label.
  final String label;

  /// Formatted metric value.
  final String value;

  /// Color used to emphasize the metric value.
  final Color accent;
}

/// Item displayed in the upcoming queue.
class QueueItem {
  /// Creates an immutable queue row.
  const QueueItem({
    required this.title,
    required this.artist,
    required this.duration,
    this.isCurrent = false,
  });

  /// Track title.
  final String title;

  /// Artist name.
  final String artist;

  /// Formatted duration.
  final String duration;

  /// Whether the item is currently selected.
  final bool isCurrent;

  /// Returns a copy with selected fields changed.
  QueueItem copyWith({bool? isCurrent}) {
    return QueueItem(
      title: title,
      artist: artist,
      duration: duration,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }
}

/// Lyric line synchronized with a playback timestamp.
class LyricLine {
  /// Creates an immutable lyric line.
  const LyricLine({
    required this.timestamp,
    required this.text,
    this.isActive = false,
  });

  /// Timestamp label for the line.
  final String timestamp;

  /// Lyric text.
  final String text;

  /// Whether this line is currently emphasized.
  final bool isActive;

  /// Returns a copy with selected fields changed.
  LyricLine copyWith({bool? isActive}) {
    return LyricLine(
      timestamp: timestamp,
      text: text,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Complete immutable state for the player view.
class PlayerViewState {
  /// Creates immutable state consumed by the player UI.
  const PlayerViewState({
    required this.track,
    required this.queue,
    required this.lyrics,
    required this.waveform,
    required this.spectrum,
    this.isPlaying = false,
    this.isImporting = false,
    this.shuffleEnabled = false,
    this.repeatEnabled = true,
    this.visualizerMode = VisualizerMode.circular,
    this.progress = 0.22,
    this.position = const Duration(seconds: 42),
    this.duration = const Duration(minutes: 3, seconds: 18),
    this.bpm = 128,
    this.beatConfidence = 0.91,
    this.hapticStrength = 0.92,
    this.bassEnergy = 0.72,
    this.batteryImpact = 0.18,
    this.latencyMs = 14,
    this.beatPulse = 1,
    this.beatPhase = 0,
    this.importError,
  });

  /// Builds the initial reference session used before the user imports audio.
  factory PlayerViewState.initial() {
    return const PlayerViewState(
      track: PlayerDefaults.track,
      queue: PlayerDefaults.queue,
      lyrics: PlayerDefaults.lyrics,
      waveform: PlayerDefaults.waveform,
      spectrum: PlayerDefaults.spectrum,
    );
  }

  /// Currently selected track.
  final PlayerTrack track;

  /// Upcoming queue items.
  final List<QueueItem> queue;

  /// Synchronized lyric lines.
  final List<LyricLine> lyrics;

  /// Waveform samples normalized to 0..1.
  final List<double> waveform;

  /// Spectrum bins normalized to 0..1.
  final List<double> spectrum;

  /// Whether playback is active.
  final bool isPlaying;

  /// Whether an import operation is running.
  final bool isImporting;

  /// Whether shuffle mode is enabled.
  final bool shuffleEnabled;

  /// Whether repeat mode is enabled.
  final bool repeatEnabled;

  /// Active visualizer mode.
  final VisualizerMode visualizerMode;

  /// Playback progress normalized to 0..1.
  final double progress;

  /// Current playback position.
  final Duration position;

  /// Current track duration.
  final Duration duration;

  /// Estimated beats per minute.
  final int bpm;

  /// Beat confidence normalized to 0..1.
  final double beatConfidence;

  /// Haptic strength normalized to 0..1.
  final double hapticStrength;

  /// Bass energy normalized to 0..1.
  final double bassEnergy;

  /// Estimated battery impact normalized to 0..1.
  final double batteryImpact;

  /// Estimated haptic/audio latency in milliseconds.
  final int latencyMs;

  /// Artwork and ring pulse scalar.
  final double beatPulse;

  /// Phase used by visualizers and artwork rotation.
  final double beatPhase;

  /// Friendly import error shown to the user.
  final String? importError;

  /// Current position formatted as m:ss.
  String get positionLabel => _formatDuration(position);

  /// Current duration formatted as m:ss.
  String get durationLabel => _formatDuration(duration);

  /// Dashboard metrics derived from the player state.
  List<PlayerMetric> get metrics {
    return [
      PlayerMetric(label: 'BPM', value: '$bpm', accent: AppTheme.accent),
      PlayerMetric(
        label: 'Beat',
        value: '${(beatConfidence * 100).round()}%',
        accent: Colors.white,
      ),
      PlayerMetric(
        label: 'Latency',
        value: '${latencyMs}ms',
        accent: AppTheme.secondary,
      ),
      PlayerMetric(
        label: 'Battery',
        value: '${(batteryImpact * 100).round()}%',
        accent: const Color(0xFF42F58D),
      ),
      PlayerMetric(
        label: 'Bass',
        value: '${(bassEnergy * 100).round()}%',
        accent: AppTheme.glow,
      ),
      PlayerMetric(
        label: 'Haptic',
        value: '${(hapticStrength * 100).round()}%',
        accent: AppTheme.danger,
      ),
    ];
  }

  /// Returns a copy with selected fields changed.
  PlayerViewState copyWith({
    PlayerTrack? track,
    List<QueueItem>? queue,
    List<LyricLine>? lyrics,
    List<double>? waveform,
    List<double>? spectrum,
    bool? isPlaying,
    bool? isImporting,
    bool? shuffleEnabled,
    bool? repeatEnabled,
    VisualizerMode? visualizerMode,
    double? progress,
    Duration? position,
    Duration? duration,
    int? bpm,
    double? beatConfidence,
    double? hapticStrength,
    double? bassEnergy,
    double? batteryImpact,
    int? latencyMs,
    double? beatPulse,
    double? beatPhase,
    String? importError,
    bool clearImportError = false,
  }) {
    return PlayerViewState(
      track: track ?? this.track,
      queue: queue ?? this.queue,
      lyrics: lyrics ?? this.lyrics,
      waveform: waveform ?? this.waveform,
      spectrum: spectrum ?? this.spectrum,
      isPlaying: isPlaying ?? this.isPlaying,
      isImporting: isImporting ?? this.isImporting,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatEnabled: repeatEnabled ?? this.repeatEnabled,
      visualizerMode: visualizerMode ?? this.visualizerMode,
      progress: progress ?? this.progress,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bpm: bpm ?? this.bpm,
      beatConfidence: beatConfidence ?? this.beatConfidence,
      hapticStrength: hapticStrength ?? this.hapticStrength,
      bassEnergy: bassEnergy ?? this.bassEnergy,
      batteryImpact: batteryImpact ?? this.batteryImpact,
      latencyMs: latencyMs ?? this.latencyMs,
      beatPulse: beatPulse ?? this.beatPulse,
      beatPhase: beatPhase ?? this.beatPhase,
      importError: clearImportError ? null : importError ?? this.importError,
    );
  }
}

/// Curated baseline data used before a local audio file is imported.
class PlayerDefaults {
  const PlayerDefaults._();

  /// Default track displayed on first launch.
  static const track = PlayerTrack(
    title: 'Midnight Echo',
    artist: 'Aurora Lane',
    album: 'HapticBeat Session',
    sourceLabel: 'Reference Mix',
  );

  /// Default waveform samples.
  static const waveform = <double>[
    0.18,
    0.42,
    0.28,
    0.68,
    0.34,
    0.74,
    0.55,
    0.88,
    0.46,
    0.72,
    0.31,
    0.61,
    0.39,
    0.83,
    0.52,
    0.77,
    0.25,
    0.57,
    0.44,
    0.69,
    0.35,
    0.91,
    0.63,
    0.73,
  ];

  /// Default spectrum bins.
  static const spectrum = <double>[
    0.74,
    0.91,
    0.66,
    0.83,
    0.48,
    0.72,
    0.55,
    0.64,
    0.38,
    0.58,
    0.47,
    0.76,
    0.42,
    0.61,
    0.33,
    0.52,
    0.29,
    0.44,
  ];

  /// Default queue items for the reference session.
  static const queue = <QueueItem>[
    QueueItem(
      title: 'Midnight Echo',
      artist: 'Aurora Lane',
      duration: '3:18',
      isCurrent: true,
    ),
    QueueItem(title: 'Neon Drift', artist: 'Signal Vale', duration: '4:04'),
    QueueItem(title: 'Glass Pulse', artist: 'Noir Atlas', duration: '2:56'),
  ];

  /// Default lyric timing for the reference session.
  static const lyrics = <LyricLine>[
    LyricLine(timestamp: '0:42', text: 'Feel the low end move the room.'),
    LyricLine(
      timestamp: '0:58',
      text: 'Every shadow turns to blue.',
      isActive: true,
    ),
    LyricLine(timestamp: '1:14', text: 'Hold the rhythm, let it bloom.'),
  ];
}

/// State notifier coordinating audio, imports, haptics, and realtime metrics.
class PlayerViewModel extends StateNotifier<PlayerViewState> {
  /// Creates the player view model with injectable services for testing.
  PlayerViewModel({
    AudioService? audioService,
    AudioAnalysisService? analysisService,
    MusicImportService? importService,
    Duration pulseInterval = const Duration(milliseconds: 40),
  }) : _audioService = audioService ?? AudioService(),
       _analysisService = analysisService ?? AudioAnalysisService(),
       _importService = importService ?? MusicImportService(),
       _pulseInterval = pulseInterval,
       super(PlayerViewState.initial()) {
    _playbackSubscription = _audioService.playbackState.listen(
      _handlePlaybackEvent,
    );
    _pulseTimer = Timer.periodic(pulseInterval, (_) => _tick());
  }

  final AudioService _audioService;
  final AudioAnalysisService _analysisService;
  final MusicImportService _importService;
  final Duration _pulseInterval;
  StreamSubscription<AudioPlaybackState>? _playbackSubscription;
  Timer? _pulseTimer;
  DateTime? _lastBeatHapticAt;
  DateTime? _audioClockWallTime;
  Duration _audioClockPosition = Duration.zero;
  int _lastHapticBeatNumber = -1;
  int _beatIndex = 0;
  List<HapticCue> _hapticCues = const [];
  int _nextHapticCueIndex = 0;
  Duration _nativeHapticScheduledUntil = Duration.zero;
  bool _nativeHapticPatternActive = false;
  bool _isSchedulingNativeHaptics = false;

  /// Imports an audio file, starts playback, and updates shared player state.
  Future<void> importTrack() async {
    final previousState = state;
    state = state.copyWith(isImporting: true, clearImportError: true);

    try {
      final path = await _importService.pickAudioFile();
      if (path == null) {
        state = state.copyWith(isImporting: false);
        return;
      }

      final title = _titleFromPath(path);
      final displayTitle = title.isEmpty ? 'Imported Track' : title;

      state = state.copyWith(
        track: state.track.copyWith(
          title: displayTitle,
          artist: 'Local Library',
          album: 'Imported Audio',
          sourceLabel: 'Local File',
          accentColor: AppTheme.glow,
        ),
        queue: _queueForImportedTrack(title),
        lyrics: _lyricsForImportedTrack(),
        isPlaying: false,
        position: Duration.zero,
        progress: 0,
        clearImportError: true,
      );

      await _analyzeImportedTrack(path);

      await _audioService.prepareFromFile(path);
      final preparedDuration = _audioService.duration ?? state.duration;
      state = state.copyWith(duration: preparedDuration);

      await _startPreparedPlayback();

      state = state.copyWith(
        isPlaying: true,
        isImporting: false,
        position: Duration.zero,
        duration: _audioService.duration ?? preparedDuration,
        progress: 0,
        clearImportError: true,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Audio import failed: $error\n$stackTrace');
      state = previousState.copyWith(
        isImporting: false,
        importError: _audioImportErrorMessage(error),
      );
    }
  }

  Future<void> _analyzeImportedTrack(String path) async {
    try {
      final analysis = await _analysisService.analyzeFile(path);
      if (analysis != null && analysis.hasCues) {
        _hapticCues = analysis.cues;
        _nextHapticCueIndex = 0;
        state = state.copyWith(
          bpm: analysis.bpm,
          beatConfidence: analysis.confidence,
          waveform: _waveformFromCues(analysis.cues),
          spectrum: _spectrumFromCues(analysis.cues),
        );
        return;
      }
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Audio analysis failed, continuing without beat map: $error\n$stackTrace',
      );
    }

    _hapticCues = const [];
    _nextHapticCueIndex = 0;
  }

  /// Toggles playback and emits a matching haptic response.
  Future<void> togglePlayback() async {
    if (_audioService.hasSource) {
      if (state.isPlaying || _audioService.isPlaying) {
        await _audioService.pause();
        await HapticService.cancelPattern();
        _nativeHapticPatternActive = false;
        _nativeHapticScheduledUntil = Duration.zero;
        _audioClockWallTime = null;
        _audioClockPosition = state.position;
        state = state.copyWith(isPlaying: false);
        await HapticService.triggerBass(
          intensity: _effectiveHapticStrength(state.hapticStrength) * 0.58,
        );
        return;
      }

      await _startPreparedPlayback();
      state = state.copyWith(isPlaying: true);
      return;
    }

    final nextIsPlaying = !state.isPlaying;
    state = state.copyWith(isPlaying: nextIsPlaying);
    if (nextIsPlaying) {
      await _triggerStartBeat(position: state.position);
    } else {
      await HapticService.triggerBass(
        intensity: _effectiveHapticStrength(state.hapticStrength) * 0.58,
      );
    }
  }

  /// Selects the next queue item.
  void skipNext() {
    _selectQueueOffset(1);
    unawaited(
      HapticService.triggerKick(
        intensity: _effectiveHapticStrength(state.hapticStrength),
      ),
    );
  }

  /// Selects the previous queue item.
  void skipPrevious() {
    _selectQueueOffset(-1);
    unawaited(
      HapticService.triggerSnare(
        intensity: _effectiveHapticStrength(state.hapticStrength),
      ),
    );
  }

  /// Toggles shuffle mode.
  void toggleShuffle() {
    state = state.copyWith(shuffleEnabled: !state.shuffleEnabled);
  }

  /// Toggles repeat mode.
  void toggleRepeat() {
    state = state.copyWith(repeatEnabled: !state.repeatEnabled);
  }

  /// Updates playback progress and seeks the audio engine when available.
  void setProgress(double value) {
    final progress = value.clamp(0.0, 1.0);
    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * progress).round(),
    );

    state = state.copyWith(progress: progress, position: position);
    _audioClockPosition = position;
    _audioClockWallTime = state.isPlaying ? DateTime.now() : null;
    _resetHapticScheduler(position);
    unawaited(HapticService.cancelPattern());
    _nativeHapticPatternActive = false;
    _nativeHapticScheduledUntil = Duration.zero;
    if (_audioService.hasSource) {
      unawaited(_audioService.seekTo(position));
    }
  }

  /// Updates haptic strength.
  void setHapticStrength(double value) {
    state = state.copyWith(hapticStrength: value.clamp(0.0, 1.0));
  }

  /// Selects a visualizer rendering mode.
  void selectVisualizerMode(VisualizerMode mode) {
    state = state.copyWith(visualizerMode: mode);
  }

  void _handlePlaybackEvent(AudioPlaybackState event) {
    _audioClockPosition = event.position;
    _audioClockWallTime = event.isPlaying ? DateTime.now() : null;

    final duration = event.duration == Duration.zero
        ? state.duration
        : event.duration;
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : (event.position.inMilliseconds / duration.inMilliseconds).clamp(
            0.0,
            1.0,
          );

    state = state.copyWith(
      isPlaying: event.isPlaying,
      position: event.position,
      duration: duration,
      progress: progress,
      clearImportError: true,
    );
  }

  void _tick() {
    var effectivePosition = state.position;
    var effectiveIsPlaying = state.isPlaying;
    var effectiveProgress = state.progress;

    if (state.isPlaying && _audioService.hasSource) {
      effectivePosition = _estimatedAudioPosition();
      effectiveProgress = state.duration.inMilliseconds == 0
          ? 0
          : effectivePosition.inMilliseconds / state.duration.inMilliseconds;
    } else if (state.isPlaying && !_audioService.hasSource) {
      final nextPosition = state.position + _pulseInterval;
      final shouldLoop = nextPosition >= state.duration;
      effectivePosition = shouldLoop ? Duration.zero : nextPosition;
      effectiveProgress = state.duration.inMilliseconds == 0
          ? 0
          : effectivePosition.inMilliseconds / state.duration.inMilliseconds;
      effectiveIsPlaying = state.repeatEnabled || !shouldLoop;
    }

    final phase = _phaseForPosition(effectivePosition, state.bpm);
    final pulse = effectiveIsPlaying
        ? 1 + (math.sin(phase * math.pi * 2).abs() * 0.045)
        : 1.0;
    final energy = 0.58 + (math.sin(phase * math.pi * 2) + 1) * 0.18;

    final nextState = state.copyWith(
      beatPhase: phase,
      beatPulse: pulse,
      bassEnergy: energy.clamp(0.0, 1.0),
      beatConfidence: (0.88 + math.sin(phase * math.pi) * 0.08).clamp(0.0, 1.0),
      latencyMs: 7 + (math.sin(phase * math.pi * 4).abs() * 4).round(),
      waveform: _generateWaveform(phase, energy),
      spectrum: _generateSpectrum(phase, energy),
      position: effectivePosition,
      progress: effectiveProgress,
      isPlaying: effectiveIsPlaying,
    );

    if (nextState.isPlaying) {
      if (_hapticCues.isNotEmpty) {
        unawaited(_scheduleNativeHaptics(nextState.position));
      }
      _emitBeatHaptic(nextState);
    }

    if (state.isPlaying || phase != state.beatPhase) {
      state = nextState;
    }
  }

  void _emitBeatHaptic(PlayerViewState beatState) {
    if (beatState.hapticStrength <= 0.04) {
      return;
    }

    if (_hapticCues.isNotEmpty) {
      if (_nativeHapticPatternActive) {
        return;
      }

      _emitAnalyzedHaptic(beatState);
      return;
    }

    final beatNumber = _beatNumberForPosition(
      beatState.position,
      beatState.bpm,
    );
    if (beatNumber == _lastHapticBeatNumber) {
      return;
    }

    final now = DateTime.now();
    final lastBeat = _lastBeatHapticAt;
    if (lastBeat != null && now.difference(lastBeat).inMilliseconds < 150) {
      return;
    }

    _lastHapticBeatNumber = beatNumber;
    _lastBeatHapticAt = now;
    _beatIndex = beatNumber;

    final intensity =
        (_effectiveHapticStrength(beatState.hapticStrength) *
                (0.62 + beatState.bassEnergy * 0.38) *
                beatState.beatConfidence)
            .clamp(0.0, 1.0)
            .toDouble();

    if (_beatIndex % 8 == 0) {
      unawaited(HapticService.triggerImpact(intensity: intensity));
    } else if (_beatIndex % 4 == 0) {
      unawaited(HapticService.triggerSnare(intensity: intensity * 0.82));
    } else if (beatState.bassEnergy >= 0.72 || _beatIndex.isOdd) {
      unawaited(HapticService.triggerKick(intensity: intensity));
    } else {
      unawaited(HapticService.triggerBass(intensity: intensity * 0.76));
    }
  }

  void _emitAnalyzedHaptic(PlayerViewState beatState) {
    final lateCutoff = beatState.position - const Duration(milliseconds: 90);
    while (_nextHapticCueIndex < _hapticCues.length &&
        _hapticCues[_nextHapticCueIndex].position < lateCutoff) {
      _nextHapticCueIndex += 1;
    }

    if (_nextHapticCueIndex >= _hapticCues.length) {
      return;
    }

    final cue = _hapticCues[_nextHapticCueIndex];
    final leadMs = beatState.latencyMs.clamp(6, 24);
    final triggerPoint = beatState.position + Duration(milliseconds: leadMs);
    if (cue.position > triggerPoint) {
      return;
    }

    final cueIntensity =
        (_effectiveHapticStrength(beatState.hapticStrength) *
                _sensitiveCueIntensity(cue.intensity) *
                (0.7 + beatState.beatConfidence * 0.3))
            .clamp(0.0, 1.0)
            .toDouble();
    _nextHapticCueIndex += 1;
    _beatIndex += 1;

    if (cueIntensity >= 0.86 && _beatIndex % 4 == 0) {
      unawaited(HapticService.triggerImpact(intensity: cueIntensity));
    } else if (cueIntensity >= 0.74 && _beatIndex.isEven) {
      unawaited(HapticService.triggerSnare(intensity: cueIntensity));
    } else if (cueIntensity >= 0.52) {
      unawaited(HapticService.triggerKick(intensity: cueIntensity));
    } else {
      unawaited(HapticService.triggerBass(intensity: cueIntensity));
    }
  }

  Future<void> _startPreparedPlayback() async {
    await HapticService.prepare();
    final startPosition = state.position;
    _nextHapticCueIndex = _firstCueIndexAt(startPosition);
    final hapticStart = _hapticCues.isEmpty
        ? HapticService.triggerKick(intensity: _startBeatIntensity(state))
        : _scheduleNativeHaptics(startPosition, force: true);
    await Future.wait<void>([_audioService.play(), hapticStart]);
    _audioClockPosition = startPosition;
    _audioClockWallTime = DateTime.now();
    _markHapticBeat(startPosition);
  }

  Future<void> _triggerStartBeat({required Duration position}) async {
    await HapticService.prepare();
    await HapticService.triggerKick(intensity: _startBeatIntensity(state));
    _markHapticBeat(position);
  }

  void _markHapticBeat(Duration position) {
    _lastHapticBeatNumber = _beatNumberForPosition(position, state.bpm);
    _lastBeatHapticAt = DateTime.now();
    _beatIndex = _lastHapticBeatNumber;
  }

  void _resetHapticScheduler(Duration position) {
    _lastHapticBeatNumber = _beatNumberForPosition(position, state.bpm) - 1;
    _lastBeatHapticAt = null;
    _nextHapticCueIndex = _firstCueIndexAt(position);
  }

  Future<void> _scheduleNativeHaptics(
    Duration position, {
    bool force = false,
  }) async {
    if (_hapticCues.isEmpty || _isSchedulingNativeHaptics) {
      return;
    }

    if (!force &&
        _nativeHapticPatternActive &&
        _nativeHapticScheduledUntil - position > const Duration(seconds: 7)) {
      return;
    }

    _isSchedulingNativeHaptics = true;
    try {
      final windowEnd = position + const Duration(seconds: 22);
      final offsetsMs = <int>[];
      final intensities = <double>[];

      for (
        var index = _firstCueIndexAt(position);
        index < _hapticCues.length;
        index++
      ) {
        final cue = _hapticCues[index];
        if (cue.position > windowEnd) {
          break;
        }

        final offset = cue.position - position;
        offsetsMs.add(offset.inMilliseconds.clamp(0, 22000));
        intensities.add(_sensitiveCueIntensity(cue.intensity));
      }

      if (offsetsMs.isEmpty) {
        _nativeHapticPatternActive = false;
        return;
      }

      final accepted = await HapticService.startPattern(
        offsetsMs: offsetsMs,
        intensities: intensities,
        strength: _effectiveHapticStrength(state.hapticStrength),
      );
      _nativeHapticPatternActive = accepted;
      if (accepted) {
        _nativeHapticScheduledUntil = windowEnd;
      }
    } finally {
      _isSchedulingNativeHaptics = false;
    }
  }

  int _firstCueIndexAt(Duration position) {
    var low = 0;
    var high = _hapticCues.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_hapticCues[mid].position < position) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  Duration _estimatedAudioPosition() {
    final wallTime = _audioClockWallTime;
    final estimated = wallTime == null
        ? _audioClockPosition
        : _audioClockPosition + DateTime.now().difference(wallTime);

    if (state.duration == Duration.zero) {
      return estimated;
    }

    if (estimated < Duration.zero) {
      return Duration.zero;
    }

    if (estimated > state.duration) {
      return state.duration;
    }

    return estimated;
  }

  void _selectQueueOffset(int offset) {
    final currentIndex = state.queue.indexWhere((item) => item.isCurrent);
    final safeIndex = currentIndex == -1 ? 0 : currentIndex;
    final nextIndex = (safeIndex + offset) % state.queue.length;
    final normalizedIndex = nextIndex < 0 ? state.queue.length - 1 : nextIndex;
    final nextItem = state.queue[normalizedIndex];

    state = state.copyWith(
      track: PlayerTrack(
        title: nextItem.title,
        artist: nextItem.artist,
        album: state.track.album,
        sourceLabel: state.track.sourceLabel,
        accentColor: normalizedIndex.isEven ? AppTheme.accent : AppTheme.danger,
      ),
      queue: [
        for (var i = 0; i < state.queue.length; i++)
          state.queue[i].copyWith(isCurrent: i == normalizedIndex),
      ],
      progress: 0,
      position: Duration.zero,
      clearImportError: true,
    );
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    unawaited(_playbackSubscription?.cancel());
    unawaited(_audioService.dispose());
    super.dispose();
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _audioImportErrorMessage(Object error) {
  final detail = error.toString().toLowerCase();
  if (detail.contains('permission') ||
      detail.contains('not available') ||
      detail.contains('cannot open') ||
      detail.contains('operation not permitted')) {
    return 'Unable to access this audio file. Save it locally, then import it again.';
  }

  if (detail.contains('unsupported') ||
      detail.contains('format') ||
      detail.contains('codec') ||
      detail.contains('source error')) {
    return 'This audio format is not supported or is protected. Try MP3, M4A, or WAV.';
  }

  return 'Unable to load this audio file. Try MP3, M4A, or WAV saved locally.';
}

double _phaseForPosition(Duration position, int bpm) {
  final beatMicros = _beatMicrosForBpm(bpm);
  return (position.inMicroseconds % beatMicros) / beatMicros;
}

int _beatNumberForPosition(Duration position, int bpm) {
  return position.inMicroseconds ~/ _beatMicrosForBpm(bpm);
}

int _beatMicrosForBpm(int bpm) {
  final safeBpm = bpm.clamp(40, 240);
  return (Duration.microsecondsPerMinute / safeBpm).round();
}

double _startBeatIntensity(PlayerViewState state) {
  return (_effectiveHapticStrength(state.hapticStrength) * state.beatConfidence)
      .clamp(0.0, 1.0)
      .toDouble();
}

double _effectiveHapticStrength(double strength) {
  final value = strength.clamp(0.0, 1.0);
  if (value <= 0.04) {
    return 0;
  }

  return (0.14 + math.pow(value, 0.72) * 0.86).clamp(0.0, 1.0).toDouble();
}

double _sensitiveCueIntensity(double intensity) {
  final value = intensity.clamp(0.0, 1.0);
  return (0.18 + math.pow(value, 0.78) * 0.82).clamp(0.0, 1.0).toDouble();
}

String _titleFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final fileName = normalized.split('/').last;
  final extensionIndex = fileName.lastIndexOf('.');
  final title = extensionIndex > 0
      ? fileName.substring(0, extensionIndex)
      : fileName;

  return title.replaceAll(RegExp(r'[_-]+'), ' ').trim();
}

List<QueueItem> _queueForImportedTrack(String title) {
  final displayTitle = title.isEmpty ? 'Imported Track' : title;
  return [
    QueueItem(
      title: displayTitle,
      artist: 'Local Library',
      duration: '--:--',
      isCurrent: true,
    ),
    const QueueItem(
      title: 'Midnight Echo',
      artist: 'Aurora Lane',
      duration: '3:18',
    ),
    const QueueItem(
      title: 'Glass Pulse',
      artist: 'Noir Atlas',
      duration: '2:56',
    ),
  ];
}

List<LyricLine> _lyricsForImportedTrack() {
  return const [
    LyricLine(timestamp: 'Live', text: 'Imported audio ready for haptics.'),
    LyricLine(
      timestamp: 'DSP',
      text: 'Realtime beat analysis will drive this surface.',
      isActive: true,
    ),
    LyricLine(timestamp: 'Mix', text: 'Use the haptic strength control below.'),
  ];
}

List<double> _waveformFromCues(List<HapticCue> cues) {
  if (cues.isEmpty) {
    return PlayerDefaults.waveform;
  }

  return List<double>.unmodifiable(
    List<double>.generate(28, (index) {
      final cueIndex = (index * cues.length / 28).floor().clamp(
        0,
        cues.length - 1,
      );
      final nextCueIndex = (cueIndex + 1).clamp(0, cues.length - 1);
      final current = cues[cueIndex].intensity;
      final next = cues[nextCueIndex].intensity;
      return (0.18 + current * 0.56 + next * 0.22).clamp(0.08, 1.0);
    }),
  );
}

List<double> _spectrumFromCues(List<HapticCue> cues) {
  if (cues.isEmpty) {
    return PlayerDefaults.spectrum;
  }

  return List<double>.unmodifiable(
    List<double>.generate(22, (index) {
      var peak = 0.0;
      for (var cueIndex = index; cueIndex < cues.length; cueIndex += 22) {
        peak = math.max(peak, cues[cueIndex].intensity);
      }
      final rolloff = 1 - (index / 22) * 0.38;
      return (0.16 + peak * 0.62 * rolloff).clamp(0.08, 1.0);
    }),
  );
}

List<double> _generateWaveform(double phase, double energy) {
  return List<double>.unmodifiable(
    List<double>.generate(28, (index) {
      final t = index / 28;
      final carrier = math.sin((t + phase) * math.pi * 4).abs();
      final transient = math.sin((t * 7 + phase * 3) * math.pi).abs();
      return (0.18 + carrier * 0.48 + transient * energy * 0.34).clamp(
        0.08,
        1.0,
      );
    }),
  );
}

List<double> _generateSpectrum(double phase, double energy) {
  return List<double>.unmodifiable(
    List<double>.generate(22, (index) {
      final band = index / 22;
      final bassBias = 1 - band * 0.45;
      final movement = math.sin((phase * 5 + band * 3.5) * math.pi).abs();
      return (0.18 + bassBias * energy * 0.5 + movement * 0.32).clamp(
        0.08,
        1.0,
      );
    }),
  );
}
