import 'package:flutter/material.dart';

import '../../entry_age.dart';
import '../../l10n/app_localizations.dart';
import '../../models/field.dart';
import '../../theme.dart';
import '../../widgets/section_header.dart';
import 'pinned_notifier.dart';

/// Dashboard section rendered above the channel list, showing the latest
/// value and age for every pinned field. Rendered via
/// `ReorderableListView.builder`'s `header:` parameter, so it is not itself
/// reorderable.
class PinnedSection extends StatelessWidget {
  final List<PinnedEntry> entries;
  final DateTime now;
  final VoidCallback onEdit;
  final ValueChanged<PinnedEntry> onTap;

  const PinnedSection({
    super.key,
    required this.entries,
    required this.now,
    required this.onEdit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: l10n.pinnedSectionTitle,
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.pinnedSectionEditTooltip,
            onPressed: onEdit,
          ),
        ),
        for (final entry in entries)
          _PinnedRow(entry: entry, now: now, onTap: () => onTap(entry)),
        const Divider(height: 1),
      ],
    );
  }
}

class _PinnedRow extends StatelessWidget {
  final PinnedEntry entry;
  final DateTime now;
  final VoidCallback onTap;

  const _PinnedRow({required this.entry, required this.now, required this.onTap});

  String _displayLabel(String? label, int fieldId) =>
      label?.isNotEmpty == true ? label! : 'Field $fieldId';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dataAccent = Theme.of(context).extension<BrandColors>()!.dataAccent;
    final valueStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: dataAccent, fontWeight: FontWeight.bold);
    final ageStyle = Theme.of(context).textTheme.bodySmall;
    final snapshot = entry.snapshot;

    final Widget trailing;
    switch (entry.state) {
      case PinnedEntryLoading():
        trailing = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: l10n.labelLoading,
          ),
        );
      case PinnedEntryError():
        trailing = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(l10n.labelNa, style: valueStyle),
            Text(l10n.pinnedFieldUnavailable, style: ageStyle),
          ],
        );
      case PinnedEntryValue():
        final value = snapshot.value;
        final valueAt = snapshot.valueAt;
        trailing = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value != null ? formatFieldValue(value) : l10n.labelNa,
              style: valueStyle,
            ),
            if (valueAt != null)
              Text(formatEntryAge(l10n, now.difference(valueAt)), style: ageStyle),
          ],
        );
    }

    return MergeSemantics(
      child: ListTile(
        title: Text(_displayLabel(snapshot.label, snapshot.fieldId)),
        subtitle: Text(entry.channel.displayName),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
