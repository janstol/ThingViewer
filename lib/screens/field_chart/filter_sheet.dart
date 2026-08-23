import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../settings/settings_notifier.dart';

class FilterSheet extends StatefulWidget {
  final DateTimeRange initialRange;
  final SettingsNotifier settings;

  const FilterSheet({
    super.key,
    required this.initialRange,
    required this.settings,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // showModalBottomSheet defaults to useSafeArea: false, so the sheet
    // paints to the window edge and the system nav bar would otherwise
    // cover the Cancel/Apply row. top: false since this is a bottom sheet.
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.filterTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(l10n.filterFrom),
              subtitle: Text(widget.settings.formatDateTime(_range.start)),
              onTap: () => _pickFrom(context),
            ),
            ListTile(
              title: Text(l10n.filterTo),
              subtitle: Text(widget.settings.formatDateTime(_range.end)),
              onTap: () => _pickTo(context),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.labelCancel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _range),
                    child: Text(l10n.labelApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFrom(BuildContext context) async {
    var dateTime = await _pickDateTime(
      context,
      initial: _range.start,
      firstDate: DateTime(2010),
      lastDate: _range.end,
    );
    if (dateTime == null) return;
    if (dateTime.isAfter(_range.end)) {
      dateTime = _range.end.subtract(const Duration(minutes: 1));
    }
    final picked = dateTime;
    setState(() => _range = DateTimeRange(start: picked, end: _range.end));
  }

  Future<void> _pickTo(BuildContext context) async {
    final now = DateTime.now();
    var dateTime = await _pickDateTime(
      context,
      initial: _range.end,
      firstDate: _range.start,
      lastDate: now,
    );
    if (dateTime == null) return;
    if (dateTime.isBefore(_range.start)) {
      dateTime = _range.start.add(const Duration(minutes: 1));
    }
    if (dateTime.isAfter(now)) dateTime = now;
    final picked = dateTime;
    setState(() => _range = DateTimeRange(start: _range.start, end: picked));
  }

  /// Combines a date picker and a time picker into a single [DateTime].
  /// Returns null if either dialog is cancelled.
  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}