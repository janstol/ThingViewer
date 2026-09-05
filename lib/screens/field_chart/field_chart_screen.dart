import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../api/thingspeak_api.dart';
import '../../export/csv_export.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../models/field_chart_settings.dart';
import '../../models/field_stats.dart';
import '../../storage/field_settings_storage.dart';
import '../../storage/pinned_fields_storage.dart';
import '../../widgets/motion.dart';
import '../field_settings/field_settings_screen.dart';
import '../settings/settings_notifier.dart';
import 'field_chart.dart';
import 'field_chart_notifier.dart';
import 'field_table.dart';
import 'filter_sheet.dart';
import 'range_chip.dart';

class FieldChartScreen extends StatefulWidget {
  final Channel channel;
  final Field field;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final VoidCallback? onPinnedChanged;
  // Field-label Hero flight tag from the row that opened this screen. Only
  // the channel detail screen's field rows pass one (see
  // FieldLabelHero) — left null for entries opened from the channel list's
  // pinned section, since that section and an embedded ChannelDetailScreen
  // can be co-mounted in the wide/tablet layout, and two Heroes sharing a
  // tag in one subtree is a hard assertion.
  final String? heroTag;

  const FieldChartScreen({
    super.key,
    required this.channel,
    required this.field,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    this.onPinnedChanged,
    this.heroTag,
  });

  @override
  State<FieldChartScreen> createState() => _FieldChartScreenState();
}

class _FieldChartScreenState extends State<FieldChartScreen> {
  late final FieldChartNotifier _notifier;
  late FieldChartSettings _chartSettings;
  late bool _pinned;
  bool _showTable = false;

  @override
  void initState() {
    super.initState();
    _notifier = FieldChartNotifier(widget.api, widget.channel, widget.field);
    _chartSettings = widget.fieldSettingsStorage.settingsFor(
      widget.channel,
      widget.field.id,
    );
    _pinned = widget.pinnedFieldsStorage.isPinned(
      widget.channel,
      widget.field.id,
    );
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _togglePin() async {
    await widget.pinnedFieldsStorage.toggle(widget.channel, widget.field.id);
    if (!mounted) return;
    setState(() => _pinned = !_pinned);
    widget.onPinnedChanged?.call();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldSettingsScreen(
          channel: widget.channel,
          field: widget.field,
          settings: _chartSettings,
          onChanged: (next) {
            widget.fieldSettingsStorage.save(
              widget.channel,
              widget.field.id,
              next,
            );
            setState(() => _chartSettings = next);
          },
        ),
      ),
    );
  }

  /// The series currently shown for [values] — delta-adjusted if
  /// [FieldChartSettings.showDelta] is on, unchanged otherwise. The single
  /// place that decision is made outside `FieldChart`'s own
  /// `_recomputeDisplayValues`, so CSV export and the stats bar can't drift
  /// from what the chart and table actually display.
  List<FieldValue> _seriesFor(List<FieldValue> values) =>
      _chartSettings.showDelta ? deltaValues(values) : values;

  /// The values currently shown in the table, delta-adjusted if
  /// [FieldChartSettings.showDelta] is on — the same series the table
  /// itself displays, just not reversed to newest-first. Null when there
  /// is nothing to export (loading, empty, or no cached data on error).
  List<FieldValue>? _exportableValues() {
    final values = switch (_notifier.state) {
      FieldChartLoaded(:final values) => values,
      FieldChartError(:final cachedValues) => cachedValues,
      FieldChartEmpty() => null,
      FieldChartLoading() => null,
    };
    if (values == null || values.isEmpty) return null;
    return _seriesFor(values);
  }

  Future<void> _exportCsv(BuildContext context) async {
    final values = _exportableValues();
    if (values == null) return;

    final mode = await showDialog<CsvExportMode>(
      context: context,
      builder: (_) => const _CsvExportDialog(),
    );
    if (mode == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context)!;
    final csv = buildFieldCsv(
      values,
      mode: mode,
      formatTimestamp: widget.settings.formatDateTime,
      decimals: _chartSettings.decimals,
    );
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final fileName =
        'thingviewer-${widget.channel.id}-field${widget.field.id}-'
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv';

    final Uri? uri;
    try {
      uri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'text/csv',
      );
    } on PlatformException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupErrorFilePicker)));
      return;
    }
    if (uri == null || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.csvExportSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final chartTitle = _chartSettings.title ?? widget.field.displayLabel;
    // Skip the flight for a custom chart title: morphing one string into a
    // different one reads as a glitch, not a transition. The condition
    // lives only on this end deliberately — an orphaned source Hero with
    // no partner is harmless, so the two ends can never drift out of
    // agreement with each other.
    final heroTag = widget.heroTag;
    final title = heroTag != null && chartTitle == widget.field.displayLabel
        ? FieldLabelHero(
            tag: heroTag,
            label: chartTitle,
            style: theme.textTheme.titleLarge!.copyWith(
              color: theme.appBarTheme.foregroundColor,
            ),
          )
        : Text(chartTitle);
    return Scaffold(
      appBar: AppBar(
        title: title,
        actions: [
          IconButton(
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: _pinned ? l10n.unpinFieldTooltip : l10n.pinFieldTooltip,
            onPressed: _togglePin,
          ),
          IconButton(
            icon: Icon(_showTable ? Icons.show_chart : Icons.table_rows),
            tooltip: _showTable
                ? l10n.fieldChartTooltip
                : l10n.fieldTableTooltip,
            onPressed: () => setState(() => _showTable = !_showTable),
          ),
          if (_showTable)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: l10n.csvExportTooltip,
              onPressed: () => _exportCsv(context),
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.fieldSettingsTooltip,
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) => MotionSwitcher(
          child: switch (_notifier.state) {
            FieldChartLoading() => Center(
              key: const ValueKey('loading'),
              child: CircularProgressIndicator(
                semanticsLabel: l10n.labelLoading,
              ),
            ),
            FieldChartEmpty() => Center(
              key: const ValueKey('empty'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.fieldChartNoValues),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showFilterSheet(context),
                    icon: const Icon(Icons.filter_list),
                    label: Text(l10n.filterTitle),
                  ),
                ],
              ),
            ),
            FieldChartError(
              :final cachedValues,
              :final errorCode,
              :final serverMessage,
              :final range,
            ) =>
              Builder(
                key: const ValueKey('error'),
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  final message = switch (errorCode) {
                    ApiErrorCode.network => l10n.errorNetwork,
                    ApiErrorCode.credentials => l10n.errorApiCredentials,
                    ApiErrorCode.general => serverMessage ?? l10n.errorGeneral,
                  };
                  if (cachedValues.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => _showFilterSheet(context),
                            icon: const Icon(Icons.filter_list),
                            label: Text(l10n.filterTitle),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RangeChip(
                          range: range,
                          settings: widget.settings,
                          onPressed: () => _showFilterSheet(context),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _StatsBar(
                          count: cachedValues.length,
                          stats: computeFieldStats(_seriesFor(cachedValues)),
                          chartSettings: _chartSettings,
                        ),
                      ),
                      Expanded(
                        child: MotionSwitcher(
                          child: _showTable
                              ? FieldTable(
                                  key: const ValueKey('table'),
                                  values: cachedValues,
                                  settings: widget.settings,
                                  chartSettings: _chartSettings,
                                )
                              : FieldChart(
                                  key: const ValueKey('chart'),
                                  values: cachedValues,
                                  invalidAt: const [],
                                  settings: widget.settings,
                                  chartSettings: _chartSettings,
                                  title: chartTitle,
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            FieldChartLoaded(
              :final values,
              :final invalidAt,
              :final truncated,
              :final range,
            ) =>
              Column(
                key: const ValueKey('loaded'),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RangeChip(
                      range: range,
                      settings: widget.settings,
                      onPressed: () => _showFilterSheet(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _StatsBar(
                      count: values.length,
                      stats: computeFieldStats(_seriesFor(values)),
                      chartSettings: _chartSettings,
                    ),
                  ),
                  if (truncated)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Text(
                        l10n.fieldChartTruncated,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: MotionSwitcher(
                      child: _showTable
                          ? FieldTable(
                              key: const ValueKey('table'),
                              values: values,
                              settings: widget.settings,
                              chartSettings: _chartSettings,
                            )
                          : FieldChart(
                              key: const ValueKey('chart'),
                              values: values,
                              invalidAt: invalidAt,
                              settings: widget.settings,
                              chartSettings: _chartSettings,
                              title: chartTitle,
                            ),
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final currentState = _notifier.state;
    final currentRange = switch (currentState) {
      FieldChartLoaded(:final range) => range,
      FieldChartEmpty(:final range) => range,
      FieldChartError(:final range) => range,
      FieldChartLoading() => DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    };

    final range = await showModalBottomSheet<DateTimeRange>(
      context: context,
      builder: (context) =>
          FilterSheet(initialRange: currentRange, settings: widget.settings),
    );

    if (range != null) _notifier.applyFilter(range);
  }
}

/// Aggregate stats strip shown above the chart/table content (and above the
/// truncation warning, when present). [stats] is computed over the series
/// currently on screen — the delta series when
/// [FieldChartSettings.showDelta] is on, same as the chart and table — so a
/// sum over a counter field reads as "pulses in this window" rather than the
/// raw counter total. [count] stays the raw number of readings loaded,
/// unaffected by [FieldChartSettings.showDelta], matching what this row
/// replaced, and is always shown — only the sum/average/min/max entries are
/// individually toggleable, via [FieldChartSettings.showSum] and friends.
///
/// In auto mode ([FieldChartSettings.decimals] unset), min/max always carry
/// the field's real reading precision — sum, being just an addition of the
/// same readings, naturally shares it too, but average is a division and
/// almost never terminates that early. Left to trim independently (as
/// [formatFieldValue] does everywhere else), the average reads as
/// oddly over-precise next to the rest of the row, so this widget rounds
/// the whole row to whatever min/max need instead of trimming each entry on
/// its own. A fixed [FieldChartSettings.decimals] override already forces
/// one shared count for every entry, so this only applies in auto mode.
///
/// "Avg"/"Min"/"Max" are compact abbreviations kept short so the row fits
/// several entries per line — fine to read, but with no guaranteed TTS
/// pronunciation. Each entry that abbreviates carries its own spoken label
/// ("Average"/"Minimum"/"Maximum") via `Semantics.excludeSemantics`, the
/// same visible-vs-spoken split `FieldChart` already uses for its own summary.
///
/// Uses [Wrap] rather than a fixed-width [Row] so the strip doesn't clip at
/// large system text sizes — it wraps onto more lines instead. Each
/// label/value pair is a single [Text], wrapped in [MergeSemantics] so it
/// announces as one node.
class _StatsBar extends StatelessWidget {
  final int count;
  final FieldStats? stats;
  final FieldChartSettings chartSettings;

  const _StatsBar({
    required this.count,
    required this.stats,
    required this.chartSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = Theme.of(context).textTheme.bodySmall;
    final stats = this.stats;
    final rowDecimals = stats == null
        ? chartSettings.decimals
        : sharedDecimals(stats, chartSettings.decimals);
    String valueText(double value) =>
        formatFieldValue(value, decimals: rowDecimals);

    Widget entry(String text, {String? spokenLabel}) => Semantics(
      label: spokenLabel ?? text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text, style: style),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 2,
      children: [
        entry(l10n.fieldChartShowingValues(count)),
        if (stats != null) ...[
          if (chartSettings.showSum)
            entry('${l10n.fieldChartStatSum} ${valueText(stats.sum)}'),
          if (chartSettings.showAverage)
            entry(
              '${l10n.fieldChartStatAverage} ${valueText(stats.average)}',
              spokenLabel:
                  '${l10n.fieldChartStatAverageSpoken} ${valueText(stats.average)}',
            ),
          if (chartSettings.showMin)
            entry(
              '${l10n.fieldChartStatMin} ${valueText(stats.min)}',
              spokenLabel:
                  '${l10n.fieldChartStatMinSpoken} ${valueText(stats.min)}',
            ),
          if (chartSettings.showMax)
            entry(
              '${l10n.fieldChartStatMax} ${valueText(stats.max)}',
              spokenLabel:
                  '${l10n.fieldChartStatMaxSpoken} ${valueText(stats.max)}',
            ),
        ],
      ],
    );
  }
}

class _CsvExportDialog extends StatefulWidget {
  const _CsvExportDialog();

  @override
  State<_CsvExportDialog> createState() => _CsvExportDialogState();
}

class _CsvExportDialogState extends State<_CsvExportDialog> {
  CsvExportMode _selected = CsvExportMode.raw;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.csvExportTitle),
      content: SingleChildScrollView(
        child: RadioGroup<CsvExportMode>(
          groupValue: _selected,
          onChanged: (v) => setState(() => _selected = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<CsvExportMode>(
                value: CsvExportMode.raw,
                title: Text(l10n.csvExportModeRaw),
                subtitle: Text(l10n.csvExportModeRawSubtitle),
              ),
              RadioListTile<CsvExportMode>(
                value: CsvExportMode.formatted,
                title: Text(l10n.csvExportModeFormatted),
                subtitle: Text(l10n.csvExportModeFormattedSubtitle),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.labelCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l10n.csvExportAction),
        ),
      ],
    );
  }
}
