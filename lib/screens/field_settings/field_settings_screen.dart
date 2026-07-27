import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../models/field_chart_settings.dart';
import '../../widgets/section_header.dart';

const _unset = Object();

class FieldSettingsScreen extends StatefulWidget {
  final Channel channel;
  final Field field;
  final FieldChartSettings settings;
  final ValueChanged<FieldChartSettings> onChanged;

  const FieldSettingsScreen({
    super.key,
    required this.channel,
    required this.field,
    required this.settings,
    required this.onChanged,
  });

  @override
  State<FieldSettingsScreen> createState() => _FieldSettingsScreenState();
}

class _FieldSettingsScreenState extends State<FieldSettingsScreen> {
  late FieldChartSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
  }

  void _apply({
    ChartType? type,
    Object? title = _unset,
    Object? xAxisLabel = _unset,
    Object? yAxisLabel = _unset,
    Object? yMin = _unset,
    Object? yMax = _unset,
    Object? decimals = _unset,
    bool? showDelta,
    bool? gapOnInvalid,
  }) {
    final next = FieldChartSettings(
      type: type ?? _settings.type,
      title: identical(title, _unset) ? _settings.title : title as String?,
      xAxisLabel: identical(xAxisLabel, _unset)
          ? _settings.xAxisLabel
          : xAxisLabel as String?,
      yAxisLabel: identical(yAxisLabel, _unset)
          ? _settings.yAxisLabel
          : yAxisLabel as String?,
      yMin: identical(yMin, _unset) ? _settings.yMin : yMin as double?,
      yMax: identical(yMax, _unset) ? _settings.yMax : yMax as double?,
      decimals: identical(decimals, _unset)
          ? _settings.decimals
          : decimals as int?,
      showDelta: showDelta ?? _settings.showDelta,
      gapOnInvalid: gapOnInvalid ?? _settings.gapOnInvalid,
    );
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  void _setYMin(double? v) {
    final yMax = _settings.yMax;
    if (v != null && yMax != null && v >= yMax) return;
    _apply(yMin: v);
  }

  void _setYMax(double? v) {
    final yMin = _settings.yMin;
    if (v != null && yMin != null && v <= yMin) return;
    _apply(yMax: v);
  }

  void _reset() {
    setState(() => _settings = FieldChartSettings.defaults);
    widget.onChanged(FieldChartSettings.defaults);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.fieldSettingsTitle)),
      body: ListView(
        children: [
          SectionHeader(title: l10n.fieldSettingsSectionChart),
          _TypeTile(
            current: _settings.type,
            onChanged: (v) => _apply(type: v),
          ),
          _TextTile(
            icon: Icons.title,
            title: l10n.fieldSettingsChartTitle,
            value: _settings.title,
            placeholder: widget.field.displayLabel,
            onChanged: (v) => _apply(title: v),
          ),
          _TextTile(
            icon: Icons.swap_horiz,
            title: l10n.fieldSettingsXAxisLabel,
            value: _settings.xAxisLabel,
            placeholder: l10n.fieldSettingsAuto,
            onChanged: (v) => _apply(xAxisLabel: v),
          ),
          _TextTile(
            icon: Icons.swap_vert,
            title: l10n.fieldSettingsYAxisLabel,
            value: _settings.yAxisLabel,
            placeholder: l10n.fieldSettingsAuto,
            onChanged: (v) => _apply(yAxisLabel: v),
          ),
          SectionHeader(title: l10n.fieldSettingsSectionAxis),
          _NumberTile(
            icon: Icons.vertical_align_bottom,
            title: l10n.fieldSettingsYMin,
            value: _settings.yMin,
            placeholder: l10n.fieldSettingsAuto,
            onChanged: _setYMin,
          ),
          _NumberTile(
            icon: Icons.vertical_align_top,
            title: l10n.fieldSettingsYMax,
            value: _settings.yMax,
            placeholder: l10n.fieldSettingsAuto,
            onChanged: _setYMax,
          ),
          _RoundingTile(
            current: _settings.decimals,
            onChanged: (v) => _apply(decimals: v),
          ),
          SectionHeader(title: l10n.fieldSettingsSectionData),
          SwitchListTile(
            secondary: const Icon(Icons.trending_up),
            title: Text(l10n.fieldSettingsShowDelta),
            subtitle: Text(l10n.fieldSettingsShowDeltaSubtitle),
            value: _settings.showDelta,
            onChanged: (v) => _apply(showDelta: v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.timeline),
            title: Text(l10n.fieldSettingsGapOnInvalid),
            subtitle: Text(l10n.fieldSettingsGapOnInvalidSubtitle),
            value: _settings.gapOnInvalid,
            onChanged: (v) => _apply(gapOnInvalid: v),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(l10n.fieldSettingsReset),
            onTap: _reset,
          ),
        ],
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final ChartType current;
  final ValueChanged<ChartType> onChanged;

  const _TypeTile({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Scatter is implemented (see field_chart_screen.dart) but hidden from
    // this picker — janky on larger datasets and no real use case yet.
    // orElse covers a field already set to it before this change shipped.
    final options = [
      (ChartType.line, l10n.fieldSettingsTypeLine),
      (ChartType.spline, l10n.fieldSettingsTypeSpline),
      (ChartType.step, l10n.fieldSettingsTypeStep),
      (ChartType.column, l10n.fieldSettingsTypeColumn),
    ];
    final label = options
        .firstWhere(
          (e) => e.$1 == current,
          orElse: () => (current, l10n.fieldSettingsTypeScatter),
        )
        .$2;

    return ListTile(
      leading: const Icon(Icons.show_chart),
      title: Text(l10n.fieldSettingsType),
      subtitle: Text(label),
      onTap: () async {
        final selected = await showDialog<ChartType>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.fieldSettingsTypeChoose),
            children: [
              RadioGroup<ChartType>(
                groupValue: current,
                onChanged: (v) {
                  if (v != null) Navigator.pop(context, v);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options
                      .map(
                        (e) => RadioListTile<ChartType>(
                          title: Text(e.$2),
                          value: e.$1,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
        if (selected != null) onChanged(selected);
      },
    );
  }
}

class _TextTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final String placeholder;
  final ValueChanged<String?> onChanged;

  const _TextTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value ?? placeholder),
      onTap: () async {
        final controller = TextEditingController(text: value ?? '');
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.labelCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(l10n.labelApply),
              ),
            ],
          ),
        );
        if (result != null) {
          onChanged(result.trim().isEmpty ? null : result.trim());
        }
      },
    );
  }
}

class _NumberTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final double? value;
  final String placeholder;
  final ValueChanged<double?> onChanged;

  const _NumberTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.placeholder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value != null ? _formatNumber(value!) : placeholder),
      onTap: () async {
        final controller = TextEditingController(
          text: value != null ? _formatNumber(value!) : '',
        );
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.labelCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(l10n.labelApply),
              ),
            ],
          ),
        );
        if (result == null) return;
        final trimmed = result.trim();
        if (trimmed.isEmpty) {
          onChanged(null);
          return;
        }
        final parsed = double.tryParse(trimmed);
        if (parsed != null) onChanged(parsed);
      },
    );
  }

  String _formatNumber(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

// showDialog<int?> can't tell "user picked auto" (null) apart from "user
// dismissed the dialog" (also null), so wrap the choice.
class _RoundingChoice {
  final int? decimals;
  const _RoundingChoice(this.decimals);
}

class _RoundingTile extends StatelessWidget {
  final int? current;
  final ValueChanged<int?> onChanged;

  const _RoundingTile({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = current == null ? l10n.fieldSettingsRoundingAuto : '$current';

    return ListTile(
      leading: const Icon(Icons.pin_outlined),
      title: Text(l10n.fieldSettingsRounding),
      subtitle: Text(label),
      onTap: () async {
        final selected = await showDialog<_RoundingChoice>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.fieldSettingsRounding),
            children: [
              RadioGroup<int?>(
                groupValue: current,
                onChanged: (v) => Navigator.pop(context, _RoundingChoice(v)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<int?>(
                      title: Text(l10n.fieldSettingsRoundingAuto),
                      value: null,
                    ),
                    for (var i = 0; i <= 6; i++)
                      RadioListTile<int?>(title: Text('$i'), value: i),
                  ],
                ),
              ),
            ],
          ),
        );
        if (selected != null) onChanged(selected.decimals);
      },
    );
  }
}
