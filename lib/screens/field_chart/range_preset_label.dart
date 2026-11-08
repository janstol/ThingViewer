import '../../l10n/app_localizations.dart';
import '../../models/range_preset.dart';

String rangePresetLabel(AppLocalizations l10n, RangePreset preset) =>
    switch (preset) {
      RangePreset.lastHour => l10n.rangePresetLastHour,
      RangePreset.last24Hours => l10n.rangePresetLast24Hours,
      RangePreset.last7Days => l10n.rangePresetLast7Days,
      RangePreset.last30Days => l10n.rangePresetLast30Days,
    };

String rangePresetShortLabel(AppLocalizations l10n, RangePreset preset) =>
    switch (preset) {
      RangePreset.lastHour => l10n.rangePresetShortLastHour,
      RangePreset.last24Hours => l10n.rangePresetShortLast24Hours,
      RangePreset.last7Days => l10n.rangePresetShortLast7Days,
      RangePreset.last30Days => l10n.rangePresetShortLast30Days,
    };
