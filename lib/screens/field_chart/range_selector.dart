import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/range_preset.dart';
import '../settings/settings_notifier.dart';
import 'range_preset_label.dart';

/// Preset buttons plus a custom-range button, with a readout of the window
/// on screen underneath. Presets apply on a single tap; only the custom
/// range goes through a sheet.
///
/// The calendar is a separate button rather than a fifth segment because a
/// selected segment ignores taps, and a custom range must stay editable
/// while it is active.
class RangeSelector extends StatelessWidget {
  final DateTimeRange range;

  /// Null when a custom range is active.
  final RangePreset? activePreset;
  final SettingsNotifier settings;
  final ValueChanged<RangePreset> onPreset;
  final VoidCallback onCustom;

  const RangeSelector({
    super.key,
    required this.range,
    required this.activePreset,
    required this.settings,
    required this.onPreset,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activePreset = this.activePreset;
    final start = settings.formatDateTime(range.start);
    final end = settings.formatDateTime(range.end);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<RangePreset>(
                  segments: [
                    for (final preset in RangePreset.values)
                      ButtonSegment(
                        value: preset,
                        tooltip: rangePresetLabel(l10n, preset),
                        label: Text(
                          rangePresetShortLabel(l10n, preset),
                          semanticsLabel: rangePresetLabel(l10n, preset),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                  ],
                  selected: {?activePreset},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) onPreset(selection.single);
                  },
                ),
              ),
              IconButton(
                isSelected: activePreset == null,
                icon: const Icon(Icons.edit_calendar_outlined),
                selectedIcon: const Icon(Icons.edit_calendar),
                tooltip: l10n.rangeCustom,
                onPressed: onCustom,
              ),
            ],
          ),
          const SizedBox(height: 4),
          // The visible label uses a dash separator, which reads badly
          // aloud, so the spoken label is overridden separately.
          Text(
            l10n.fieldChartRangeLabel(start, end),
            semanticsLabel: l10n.fieldChartRangeSemantics(start, end),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
