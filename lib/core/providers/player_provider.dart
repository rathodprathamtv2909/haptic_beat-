import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that describes the currently active playback state.
final playerStateProvider =
    StateNotifierProvider<PlayerStateNotifier, PlayerState>((ref) {
      return PlayerStateNotifier();
    });

/// Represents the current player state for the UI layer.
class PlayerState {
  const PlayerState({
    this.isPlaying = false,
    this.progress = 0.22,
    this.bpm = 128,
    this.hapticStrength = 0.8,
  });

  final bool isPlaying;
  final double progress;
  final int bpm;
  final double hapticStrength;

  PlayerState copyWith({
    bool? isPlaying,
    double? progress,
    int? bpm,
    double? hapticStrength,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      bpm: bpm ?? this.bpm,
      hapticStrength: hapticStrength ?? this.hapticStrength,
    );
  }
}

/// Riverpod notifier for playback interactions.
class PlayerStateNotifier extends StateNotifier<PlayerState> {
  PlayerStateNotifier() : super(const PlayerState());

  void togglePlayback() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void setProgress(double value) {
    state = state.copyWith(progress: value.clamp(0.0, 1.0));
  }
}
