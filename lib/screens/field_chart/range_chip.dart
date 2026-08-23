import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_notifier.dart';

/// Header chip showing the currently active date range, above the stats bar.
/// Replaces the old bottom-pinned Filter button — it now doubles as the
/// filter entry point and as a permanent readout of what window is on
/// screen, which previously required opening the filter sheet to see.
///
/// The visible label uses a dash separator ("12/01/2024 - 12/08/2024"),
/// which reads badly aloud, so the spoken label is overridden separately —
/// the same visible-vs-spoken split the stats bar and chart semantics
/// summary already use.
class RangeChip extends StatelessWidget {
  final DateTimeRange range;
  final SettingsNotifier settings;
  final VoidCallback onPressed;

  const RangeChip({
    super.key,
    required this.range,
    required this.settings,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final start = settings.formatDate(range.start);
    final end = settings.formatDate(range.end);
    return Center(
      child: Semantics(
        label: l10n.fieldChartRangeSemantics(start, end),
        button: true,
        onTap: onPressed,
        excludeSemantics: true,
        child: ActionChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(l10n.fieldChartRangeLabel(start, end)),
          tooltip: l10n.filterTitle,
          onPressed: onPressed,
        ),
      ),
    );
  }
}