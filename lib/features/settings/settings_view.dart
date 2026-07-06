import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haptic_beat/core/theme/app_theme.dart';
import 'package:haptic_beat/features/player/player_view_model.dart';
import 'package:haptic_beat/shared/widgets/glass_card.dart';

/// A polished settings surface for playback and visual personalization.
class SettingsView extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerViewModelProvider);
    final playerViewModel = ref.read(playerViewModelProvider.notifier);

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
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _SettingsHeader(
                onBack: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }

                  context.go('/');
                },
              ),
              const SizedBox(height: 22),
              _SettingsSection(
                title: 'Playback',
                children: [
                  _SettingSlider(
                    title: 'Haptic Strength',
                    value: playerState.hapticStrength,
                    valueLabel:
                        '${(playerState.hapticStrength * 100).round()}%',
                    onChanged: playerViewModel.setHapticStrength,
                  ),
                  _SettingSwitch(
                    title: 'Shuffle',
                    value: playerState.shuffleEnabled,
                    onChanged: (_) => playerViewModel.toggleShuffle(),
                  ),
                  _SettingSwitch(
                    title: 'Repeat',
                    value: playerState.repeatEnabled,
                    onChanged: (_) => playerViewModel.toggleRepeat(),
                  ),
                  _SettingRow(
                    title: 'Latency Calibration',
                    value: '${playerState.latencyMs}ms',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Visuals',
                children: [
                  _SettingRow(
                    title: 'Visualizer Mode',
                    value: playerState.visualizerMode.label,
                  ),
                  const _SettingRow(
                    title: 'Visualizer Quality',
                    value: 'Ultra',
                  ),
                  const _SettingRow(title: 'FPS Limit', value: '120'),
                  const _SettingRow(title: 'Animation Speed', value: 'Fluid'),
                ],
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: 'Device',
                children: [
                  _SettingRow(
                    title: 'Battery Impact',
                    value: '${(playerState.batteryImpact * 100).round()}%',
                  ),
                  _SettingRow(
                    title: 'Beat Confidence',
                    value: '${(playerState.beatConfidence * 100).round()}%',
                  ),
                  _SettingRow(
                    title: 'Source',
                    value: playerState.track.sourceLabel,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top settings navigation row.
class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Back',
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded),
            color: Colors.white,
            style: IconButton.styleFrom(
              fixedSize: const Size.square(46),
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              shape: const CircleBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Grouped settings card.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// Read-only settings row.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider settings row for normalized numeric values.
class _SettingSlider extends StatelessWidget {
  const _SettingSlider({
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.onChanged,
  });

  final String title;
  final double value;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              thumbColor: Colors.white,
              overlayColor: AppTheme.accent.withValues(alpha: 0.12),
              trackHeight: 5,
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

/// Switch settings row for boolean playback options.
class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
