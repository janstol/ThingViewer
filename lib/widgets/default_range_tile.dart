import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/range_preset.dart';
import '../screens/field_chart/range_preset_label.dart';

// Wraps the result so null ("Default") can be told apart from a dismissed
// dialog.
class _DefaultRangeChoice {
  final RangePreset? preset;
  const _DefaultRangeChoice(this.preset);
}

/// Picks a [RangePreset] or "Default", which resolves to [fallback].
class DefaultRangeTile extends StatelessWidget {
  final RangePreset? current;
  final RangePreset fallback;
  final ValueChanged<RangePreset?> onChanged;

  /// Shown under the value, e.g. to explain how this default is overridden.
  final String Function(String label)? subtitleBuilder;

  const DefaultRangeTile({
    super.key,
    required this.current,
    required this.fallback,
    required this.onChanged,
    this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final defaultLabel = l10n.fieldSettingsDefaultRangeDefault(
      rangePresetLabel(l10n, fallback),
    );
    final current = this.current;
    final label = current == null
        ? defaultLabel
        : rangePresetLabel(l10n, current);

    return MergeSemantics(
      child: ListTile(
        leading: const Icon(Icons.date_range),
        title: Text(l10n.fieldSettingsDefaultRange),
        subtitle: Text(subtitleBuilder?.call(label) ?? label),
        onTap: () async {
          final selected = await showDialog<_DefaultRangeChoice>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(l10n.fieldSettingsDefaultRange),
              children: [
                RadioGroup<RangePreset?>(
                  groupValue: current,
                  onChanged: (v) =>
                      Navigator.pop(context, _DefaultRangeChoice(v)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<RangePreset?>(
                        title: Text(defaultLabel),
                        value: null,
                      ),
                      for (final preset in RangePreset.values)
                        RadioListTile<RangePreset?>(
                          title: Text(rangePresetLabel(l10n, preset)),
                          value: preset,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
          if (selected != null) onChanged(selected.preset);
        },
      ),
    );
  }
}
