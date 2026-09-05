library belive.widgets.stream_quality_sheet;

import 'package:flutter/material.dart';

import '../utils/log.dart';

/// Enum representing the available video stream quality options.
enum StreamQuality {
  auto('Auto', 'Adaptive', 0),
  hd('HD', '720p', 2500),
  sd('SD', '480p', 1200),
  low('Low', '240p', 400);

  const StreamQuality(this.label, this.resolution, this.bitrateKbps);

  /// Display label shown in the UI.
  final String label;

  /// Human-readable resolution string.
  final String resolution;

  /// Approximate bitrate in kilobits per second. 0 means adaptive.
  final int bitrateKbps;

  /// Returns the key name used for persistence/comparison.
  String get key => name;

  /// Parses a [StreamQuality] from a string key. Falls back to [auto].
  static StreamQuality fromKey(String? key) {
    switch (key) {
      case 'hd':
        return StreamQuality.hd;
      case 'sd':
        return StreamQuality.sd;
      case 'low':
        return StreamQuality.low;
      default:
        return StreamQuality.auto;
    }
  }

  /// Estimated data usage per minute in megabytes.
  double get dataPerMinuteMb => (bitrateKbps / 1024) * 60 / 8;
}

const String _tag = 'StreamQualitySheet';

/// Shows a modal bottom sheet that lets the user select a video stream
/// quality. The currently selected quality is highlighted and an estimated
/// data-usage value is displayed for each option.
///
/// [currentQuality] is the string key of the currently active quality
/// (one of: "auto", "hd", "sd", "low").
/// [onQualitySelected] is invoked with the selected quality key when the
/// user taps an option.
void showStreamQualitySheet(
  BuildContext context,
  String currentQuality,
  Function(String) onQualitySelected,
) {
  Log.d(_tag, 'showStreamQualitySheet: currentQuality=$currentQuality');
  final StreamQuality current = StreamQuality.fromKey(currentQuality);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return _StreamQualitySheet(
        current: current,
        onQualitySelected: (StreamQuality quality) {
          Log.d(_tag, 'showStreamQualitySheet: selected=${quality.key}');
          onQualitySelected(quality.key);
          Navigator.of(sheetContext).pop();
        },
      );
    },
  );
}

class _StreamQualitySheet extends StatelessWidget {
  const _StreamQualitySheet({
    required this.current,
    required this.onQualitySelected,
  });

  final StreamQuality current;
  final ValueChanged<StreamQuality> onQualitySelected;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Stream Quality',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose a quality to balance clarity and data usage.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final StreamQuality quality in StreamQuality.values)
              _QualityTile(
                quality: quality,
                selected: quality == current,
                onTap: () => onQualitySelected(quality),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.quality,
    required this.selected,
    required this.onTap,
  });

  final StreamQuality quality;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final String dataUsage = quality.bitrateKbps == 0
        ? 'Adaptive data usage'
        : '~${quality.dataPerMinuteMb.toStringAsFixed(1)} MB / min';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        quality.label,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? colorScheme.primary
                              : textTheme.titleMedium?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          quality.resolution,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dataUsage,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: colorScheme.primary, size: 22)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
