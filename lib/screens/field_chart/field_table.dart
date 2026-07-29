import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/field.dart';
import '../../models/field_chart_settings.dart';
import '../../theme.dart';
import '../settings/settings_notifier.dart';

const _pageSize = 50;

class FieldTable extends StatefulWidget {
  final List<FieldValue> values;
  final SettingsNotifier settings;
  final FieldChartSettings chartSettings;

  const FieldTable({
    super.key,
    required this.values,
    required this.settings,
    required this.chartSettings,
  });

  @override
  State<FieldTable> createState() => _FieldTableState();
}

class _FieldTableState extends State<FieldTable> {
  late List<FieldValue> _displayValues;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _recomputeDisplayValues();
  }

  @override
  void didUpdateWidget(covariant FieldTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final valuesChanged =
        oldWidget.values != widget.values ||
        oldWidget.chartSettings.showDelta != widget.chartSettings.showDelta;
    if (valuesChanged) {
      _recomputeDisplayValues();
      _page = 0;
    } else if (_page >= _pageCount) {
      _page = _pageCount == 0 ? 0 : _pageCount - 1;
    }
  }

  void _recomputeDisplayValues() {
    final base = widget.chartSettings.showDelta
        ? deltaValues(widget.values)
        : widget.values;
    _displayValues = base.reversed.toList();
  }

  int get _pageCount => (_displayValues.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dataAccent = Theme.of(context).extension<BrandColors>()!.dataAccent;
    final start = _page * _pageSize;
    final end = (start + _pageSize).clamp(0, _displayValues.length);
    final pageValues = _displayValues.sublist(start, end);
    final pageCount = _pageCount;

    return Column(
      children: [
        Semantics(
          header: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.fieldTableColumnTime,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.fieldTableColumnValue,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            interactive: true,
            child: ListView.separated(
              itemCount: pageValues.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final v = pageValues[i];
                return MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.settings.formatDateTime(v.createdAt),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            formatFieldValue(
                              v.value,
                              decimals: widget.chartSettings.decimals,
                            ),
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: dataAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.fieldTablePreviousPage,
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
              ),
              Text(
                l10n.fieldTablePage(_page + 1, pageCount == 0 ? 1 : pageCount),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.fieldTableNextPage,
                onPressed: _page < pageCount - 1
                    ? () => setState(() => _page++)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
