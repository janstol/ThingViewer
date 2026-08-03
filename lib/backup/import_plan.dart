import '../models/channel.dart';
import '../models/pinned_field.dart';
import 'backup_service.dart';

enum ChannelChange { added, updated, unchanged }

enum ChannelFieldChange { name, apiKey, visibility }

/// A single app setting tracked by the import preview, together with the
/// SharedPreferences key(s) it reads/writes. Must stay in sync with the
/// private key constants in `settings_storage.dart` — there is no public
/// symbol to import instead, since those keys are only ever meant to be
/// read/written through [SettingsStorage] itself.
enum BackupSettingKey {
  themeMode,
  dateFormat,
  timeFormat,
  timezoneDisplay,
  entryTimeDisplay,
  startChannel;

  List<String> get prefsKeys => switch (this) {
    BackupSettingKey.themeMode => const ['themeMode'],
    BackupSettingKey.dateFormat => const ['dateFormat'],
    BackupSettingKey.timeFormat => const ['timeFormat'],
    BackupSettingKey.timezoneDisplay => const ['timezoneDisplay'],
    BackupSettingKey.entryTimeDisplay => const ['entryTimeDisplay'],
    BackupSettingKey.startChannel => const [
      'startChannelId',
      'startChannelServerUrl',
    ],
  };
}

int? _asInt(Object? v) => v is int ? v : null;
String? _asString(Object? v) => v is String ? v : null;

(int, String)? _startChannelPair(Map<String, dynamic> json) {
  final id = _asInt(json['startChannelId']);
  final serverUrl = _asString(json['startChannelServerUrl']);
  if (id == null || serverUrl == null) return null;
  return (id, serverUrl);
}

/// One channel from the backup file, together with how it compares to the
/// currently saved channel of the same identity (id + serverUrl), if any.
class ChannelDiff {
  /// The channel as parsed from the backup file — not yet reconciled against
  /// [existing]'s API key. [BackupService.applyImport] does that
  /// reconciliation itself, at apply time, against whatever is saved then.
  final Channel incoming;
  final Channel? existing;
  final ChannelChange change;
  final Set<ChannelFieldChange> changes;
  final bool needsApiKey;
  final List<String> chartSettingKeys;
  final List<PinnedField> pinnedFields;

  const ChannelDiff({
    required this.incoming,
    required this.existing,
    required this.change,
    required this.changes,
    required this.needsApiKey,
    required this.chartSettingKeys,
    required this.pinnedFields,
  });
}

/// One app setting, comparing the currently saved value to what the backup
/// file would set it to. For [BackupSettingKey.startChannel], values are
/// `(int id, String serverUrl)?` records rather than a raw channel, since
/// resolving that identity to a channel name is a UI concern.
class SettingDiff {
  final BackupSettingKey key;
  final Object? current;
  final Object? incoming;

  const SettingDiff({
    required this.key,
    required this.current,
    required this.incoming,
  });

  bool get changed => current != incoming;

  /// Absent keys in the file mean "keep the current value" (mirrors
  /// [SettingsStorage.importJson]'s per-key skip-if-absent behaviour), so
  /// they compute the same way as an explicit value that happens to match.
  factory SettingDiff.compute(
    BackupSettingKey key,
    Map<String, dynamic> saved,
    Map<String, dynamic> incoming,
  ) {
    switch (key) {
      case BackupSettingKey.themeMode:
        final current = _asInt(saved['themeMode']);
        return SettingDiff(
          key: key,
          current: current,
          incoming: _asInt(incoming['themeMode']) ?? current,
        );
      case BackupSettingKey.dateFormat:
        final current = _asString(saved['dateFormat']);
        return SettingDiff(
          key: key,
          current: current,
          incoming: _asString(incoming['dateFormat']) ?? current,
        );
      case BackupSettingKey.timeFormat:
        final current = _asString(saved['timeFormat']);
        return SettingDiff(
          key: key,
          current: current,
          incoming: _asString(incoming['timeFormat']) ?? current,
        );
      case BackupSettingKey.timezoneDisplay:
        final current = _asInt(saved['timezoneDisplay']);
        return SettingDiff(
          key: key,
          current: current,
          incoming: _asInt(incoming['timezoneDisplay']) ?? current,
        );
      case BackupSettingKey.entryTimeDisplay:
        final current = _asInt(saved['entryTimeDisplay']);
        return SettingDiff(
          key: key,
          current: current,
          incoming: _asInt(incoming['entryTimeDisplay']) ?? current,
        );
      case BackupSettingKey.startChannel:
        final current = _startChannelPair(saved);
        final incomingValue = incoming.containsKey('startChannelId')
            ? (_startChannelPair(incoming) ?? current)
            : current;
        return SettingDiff(key: key, current: current, incoming: incomingValue);
    }
  }
}

/// The full result of comparing a parsed backup file against everything
/// currently saved on this device, ready for the import preview screen to
/// render and the user to select from.
class ImportPlan {
  final BackupContents contents;
  final List<ChannelDiff> channels;
  final List<SettingDiff> settings;
  final List<String> orphanChartSettingKeys;
  final List<PinnedField> orphanPinnedFields;
  final List<Channel> onlyOnDevice;

  const ImportPlan({
    required this.contents,
    required this.channels,
    required this.settings,
    required this.orphanChartSettingKeys,
    required this.orphanPinnedFields,
    required this.onlyOnDevice,
  });
}

/// What the user has chosen to actually import, built by the preview screen
/// from an [ImportPlan] and passed to [BackupService.applyImport].
class ImportSelection {
  final Set<Channel> channels;
  final Set<String> fieldChartSettingsKeys;
  final Set<PinnedField> pinnedFields;
  final Set<BackupSettingKey> settingKeys;
  final bool removeChannelsNotInBackup;

  const ImportSelection({
    required this.channels,
    required this.fieldChartSettingsKeys,
    required this.pinnedFields,
    required this.settingKeys,
    this.removeChannelsNotInBackup = false,
  });

  bool get isEmpty =>
      channels.isEmpty &&
      fieldChartSettingsKeys.isEmpty &&
      pinnedFields.isEmpty &&
      settingKeys.isEmpty &&
      !removeChannelsNotInBackup;
}
