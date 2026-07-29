import 'l10n/app_localizations.dart';
import 'screens/settings/settings_notifier.dart';
import 'storage/settings_storage.dart';

/// Formats [age] as a coarse, human-readable relative time, e.g. "5 min ago".
///
/// A negative [age] (device clock behind the server, or a future-dated
/// entry) clamps to "just now" rather than showing a nonsensical value.
String formatEntryAge(AppLocalizations l10n, Duration age) {
  if (age.inSeconds < 60) return l10n.entryAgeJustNow;
  if (age.inMinutes < 60) return l10n.entryAgeMinutes(age.inMinutes);
  if (age.inHours < 24) return l10n.entryAgeHours(age.inHours);
  if (age.inDays < 30) return l10n.entryAgeDays(age.inDays);
  if (age.inDays < 365) return l10n.entryAgeMonths(age.inDays ~/ 30);
  return l10n.entryAgeYears(age.inDays ~/ 365);
}

/// Formats [timestamp] per the user's "Last entry time" setting: absolute,
/// relative age, or both.
String formatTimestamp(
  AppLocalizations l10n,
  SettingsNotifier settings,
  DateTime timestamp,
  DateTime now,
) {
  final absolute = settings.formatDateTime(timestamp);
  final age = formatEntryAge(l10n, now.difference(timestamp));
  return switch (settings.entryTimeDisplay) {
    EntryTimeDisplay.absolute => absolute,
    EntryTimeDisplay.age => age,
    EntryTimeDisplay.both => '$absolute ($age)',
  };
}
