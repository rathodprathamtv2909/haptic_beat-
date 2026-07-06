import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/features/player/player_view.dart';
import 'package:haptic_beat/features/player/player_view_model.dart';
import 'package:haptic_beat/features/player/widgets/player_artwork.dart';
import 'package:haptic_beat/features/settings/settings_view.dart';

/// Root application widget configured with navigation and theming.
class HapticBeatApp extends StatelessWidget {
  const HapticBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/player',
          builder: (context, state) => const PlayerView(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsView(),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        title: 'HapticBeat',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.buildTheme(),
        routerConfig: router,
      ),
    );
  }
}

/// The premium home experience presenting the main player surface.
class HomeScreen extends ConsumerWidget {
  /// Creates the home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerViewModelProvider);
    final playerViewModel = ref.read(playerViewModelProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.background, Color(0xFF0B0B12), Color(0xFF15151C)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good evening',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'HapticBeat',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: playerState.isImporting
                          ? null
                          : playerViewModel.importTrack,
                      icon: playerState.isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white70,
                              ),
                            )
                          : const Icon(
                              Icons.audiotrack_rounded,
                              color: Colors.white70,
                            ),
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      onPressed: () => context.push('/settings'),
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/player'),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(Icons.person, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GestureDetector(
                    key: const ValueKey('home-now-playing-card'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/player'),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(34),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F1622), Color(0xFF1B1B2A)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withValues(alpha: 0.16),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final artworkSize = constraints.maxHeight < 500
                                ? 150.0
                                : 210.0;

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Now Playing',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      playerState.track.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      playerState.track.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: PlayerArtwork(
                                        track: playerState.track,
                                        isPlaying: playerState.isPlaying,
                                        beatPulse: playerState.beatPulse,
                                        beatPhase: playerState.beatPhase,
                                        size: artworkSize,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          playerState.positionLabel,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Text(
                                          playerState.durationLabel,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: playerState.progress,
                                      minHeight: 6,
                                      backgroundColor: const Color(0x1FFFFFFF),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            AppTheme.accent,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        _HomeMetric(
                                          label: 'BPM',
                                          value: '${playerState.bpm}',
                                        ),
                                        const SizedBox(width: 10),
                                        _HomeMetric(
                                          label: 'Beat',
                                          value:
                                              '${(playerState.beatConfidence * 100).round()}%',
                                        ),
                                        const SizedBox(width: 10),
                                        _HomeMetric(
                                          label: 'Latency',
                                          value: '${playerState.latencyMs}ms',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          onPressed:
                                              playerViewModel.skipPrevious,
                                          icon: const Icon(
                                            Icons.skip_previous_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        GestureDetector(
                                          onTap: playerViewModel.togglePlayback,
                                          child: Container(
                                            width: 68,
                                            height: 68,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.accent,
                                            ),
                                            child: Icon(
                                              playerState.isPlaying
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              color: Colors.black,
                                              size: 34,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        IconButton(
                                          onPressed: playerViewModel.skipNext,
                                          icon: const Icon(
                                            Icons.skip_next_rounded,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact home metric tile.
class _HomeMetric extends StatelessWidget {
  const _HomeMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
