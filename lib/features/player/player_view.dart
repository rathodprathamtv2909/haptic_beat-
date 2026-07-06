import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/features/player/player_view_model.dart';
import 'package:haptic_beat/features/player/widgets/player_artwork.dart';
import 'package:haptic_beat/features/player/widgets/player_control_bar.dart';
import 'package:haptic_beat/features/player/widgets/player_metrics_panel.dart';
import 'package:haptic_beat/features/player/widgets/player_visualizer.dart';
import 'package:haptic_beat/shared/widgets/glass_card.dart';

/// Immersive player screen with synchronized visuals, metrics, and haptics.
class PlayerView extends ConsumerWidget {
  /// Creates the player screen.
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerViewModelProvider);
    final viewModel = ref.read(playerViewModelProvider.notifier);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.background, Color(0xFF09090D), Color(0xFF15151C)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final artworkSize = (constraints.maxWidth * 0.72)
                  .clamp(220.0, 304.0)
                  .toDouble();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    sliver: SliverList.list(
                      children: [
                        _PlayerHeader(
                          isImporting: state.isImporting,
                          onBack: () => Navigator.of(context).maybePop(),
                          onImport: viewModel.importTrack,
                          onSettings: () => context.push('/settings'),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: PlayerArtwork(
                            track: state.track,
                            isPlaying: state.isPlaying,
                            beatPulse: state.beatPulse,
                            beatPhase: state.beatPhase,
                            size: artworkSize,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _TrackHeader(state: state),
                        if (state.importError != null) ...[
                          const SizedBox(height: 12),
                          _ImportError(message: state.importError!),
                        ],
                        const SizedBox(height: 22),
                        _ProgressPanel(
                          progress: state.progress,
                          positionLabel: state.positionLabel,
                          durationLabel: state.durationLabel,
                          onChanged: viewModel.setProgress,
                        ),
                        const SizedBox(height: 18),
                        PlayerControlBar(
                          isPlaying: state.isPlaying,
                          shuffleEnabled: state.shuffleEnabled,
                          repeatEnabled: state.repeatEnabled,
                          onPrevious: viewModel.skipPrevious,
                          onPlayPause: () {
                            viewModel.togglePlayback();
                          },
                          onNext: viewModel.skipNext,
                          onShuffle: viewModel.toggleShuffle,
                          onRepeat: viewModel.toggleRepeat,
                        ),
                        const SizedBox(height: 22),
                        _ModeSelector(
                          selectedMode: state.visualizerMode,
                          onChanged: viewModel.selectVisualizerMode,
                        ),
                        const SizedBox(height: 14),
                        PlayerVisualizer(
                          mode: state.visualizerMode,
                          waveform: state.waveform,
                          spectrum: state.spectrum,
                          isPlaying: state.isPlaying,
                          beatPhase: state.beatPhase,
                        ),
                        const SizedBox(height: 16),
                        PlayerMetricsPanel(
                          metrics: state.metrics,
                          hapticStrength: state.hapticStrength,
                          onHapticStrengthChanged: viewModel.setHapticStrength,
                        ),
                        const SizedBox(height: 16),
                        _LyricsPanel(lyrics: state.lyrics),
                        const SizedBox(height: 16),
                        _QueuePanel(queue: state.queue),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Top player navigation and import actions.
class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader({
    required this.isImporting,
    required this.onBack,
    required this.onImport,
    required this.onSettings,
  });

  final bool isImporting;
  final VoidCallback onBack;
  final VoidCallback onImport;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HeaderButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Back',
          onPressed: onBack,
        ),
        const Spacer(),
        Text(
          'Now Playing',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _HeaderButton(
          icon: Icons.library_music_rounded,
          tooltip: 'Import',
          isLoading: isImporting,
          onPressed: isImporting ? null : onImport,
        ),
        const SizedBox(width: 8),
        _HeaderButton(
          icon: Icons.tune_rounded,
          tooltip: 'Settings',
          onPressed: onSettings,
        ),
      ],
    );
  }
}

/// Circular icon button used in the player header.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        color: Colors.white,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(46),
          backgroundColor: Colors.white.withValues(alpha: 0.07),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

/// Track title, artist, album, and source metadata.
class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.state});

  final PlayerViewState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          state.track.title,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${state.track.artist} · ${state.track.album}',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          state.track.sourceLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: state.track.accentColor.withValues(alpha: 0.86),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Friendly import failure surface.
class _ImportError extends StatelessWidget {
  const _ImportError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppTheme.danger.withValues(alpha: 0.11),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Playback progress panel with timestamps and scrubber.
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.progress,
    required this.positionLabel,
    required this.durationLabel,
    required this.onChanged,
  });

  final double progress;
  final String positionLabel;
  final String durationLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: Colors.white,
            overlayColor: AppTheme.accent.withValues(alpha: 0.12),
            trackHeight: 5,
          ),
          child: Slider(value: progress, onChanged: onChanged),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                positionLabel,
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                durationLabel,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Segmented control for choosing the visualizer mode.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selectedMode, required this.onChanged});

  final VisualizerMode selectedMode;
  final ValueChanged<VisualizerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(8),
      borderRadius: const BorderRadius.all(Radius.circular(22)),
      child: CupertinoSlidingSegmentedControl<VisualizerMode>(
        groupValue: selectedMode,
        backgroundColor: Colors.transparent,
        thumbColor: AppTheme.accent.withValues(alpha: 0.22),
        onValueChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
        children: {
          for (final mode in VisualizerMode.values)
            mode: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(
                mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mode == selectedMode ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        },
      ),
    );
  }
}

/// Lyrics panel for synced lyric lines.
class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.lyrics});

  final List<LyricLine> lyrics;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lyrics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final line in lyrics) _LyricRow(line: line),
        ],
      ),
    );
  }
}

/// Single synced lyric row.
class _LyricRow extends StatelessWidget {
  const _LyricRow({required this.line});

  final LyricLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              line.timestamp,
              style: TextStyle(
                color: line.isActive ? AppTheme.accent : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.text,
              style: TextStyle(
                color: line.isActive ? Colors.white : Colors.white60,
                fontSize: line.isActive ? 16 : 14,
                fontWeight: line.isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Queue panel showing the next playback items.
class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.queue});

  final List<QueueItem> queue;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Queue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in queue) _QueueRow(item: item),
        ],
      ),
    );
  }
}

/// Single queue row.
class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item});

  final QueueItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.isCurrent
                  ? AppTheme.accent.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(
              item.isCurrent
                  ? Icons.equalizer_rounded
                  : Icons.music_note_rounded,
              size: 18,
              color: item.isCurrent ? AppTheme.accent : Colors.white54,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item.duration,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
