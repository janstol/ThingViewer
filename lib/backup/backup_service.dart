import 'dart:convert';

import '../models/channel.dart';
import '../models/pinned_field.dart';
import '../storage/channel_storage.dart';
import '../storage/field_settings_storage.dart';
import '../storage/pinned_fields_storage.dart';
import '../storage/settings_storage.dart';
import 'import_plan.dart';

const _kBackupApp = 'thingviewer';
const _kBackupVersion = 2;

enum BackupExportMode { full, withoutApiKeys }

enum BackupErrorType { notABackup, newerVersion, malformed }

class BackupException implements Exception {
  final BackupErrorType type;
  final String message;

  BackupException(this.type, this.message);

  @override
  String toString() => 'BackupException($type): $message';
}

/// Result of successfully parsing a backup file. Every section is nullable —
/// `null` means the section was absent from the file, as opposed to an empty
/// (but present) section, so [BackupService.planImport] knows there is
/// nothing to show or import for that section.
class BackupContents {
  final List<Channel>? channels;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? fieldChartSettings;
  final List<dynamic>? pinnedFields;
  final DateTime? exportedAt;
  final String? appVersion;
  final bool apiKeysExcluded;

  const BackupContents({
    this.channels,
    this.settings,
    this.fieldChartSettings,
    this.pinnedFields,
    this.exportedAt,
    this.appVersion,
    this.apiKeysExcluded = false,
  });
}

/// Reads/writes the app's full backup format: a single pretty-printed JSON
/// document covering saved channels, settings, and per-field chart overrides.
///
/// Deliberately has no dependency on `file_picker` or any other plugin — it
/// works on plain strings, so it can be unit tested without plugin mocks. The
/// screen that uses this owns the file-picker dialogs.
class BackupService {
  final ChannelStorage _channelStorage;
  final SettingsStorage _settingsStorage;
  final FieldSettingsStorage _fieldSettingsStorage;
  final PinnedFieldsStorage _pinnedFieldsStorage;

  /// Resolved lazily, only when [export] actually needs it, so constructing
  /// a [BackupService] at app startup doesn't have to wait on a
  /// platform-channel round trip nobody may ever need.
  final Future<String> Function() appVersion;

  BackupService(
    this._channelStorage,
    this._settingsStorage,
    this._fieldSettingsStorage,
    this._pinnedFieldsStorage, {
    this.appVersion = _noAppVersion,
  });

  static Future<String> _noAppVersion() async => '';

  Future<String> export({BackupExportMode mode = BackupExportMode.full}) async {
    final version = await appVersion();
    final json = {
      'app': _kBackupApp,
      'version': _kBackupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      if (version.isNotEmpty) 'appVersion': version,
      if (mode == BackupExportMode.withoutApiKeys) 'apiKeysExcluded': true,
      'channels': _channelStorage.loadChannels().map((c) => c.toJson()).map((
        json,
      ) {
        if (mode == BackupExportMode.withoutApiKeys) json.remove('apiKey');
        return json;
      }).toList(),
      'settings': _settingsStorage.exportJson(),
      'fieldChartSettings': _fieldSettingsStorage.exportJson(),
      'pinnedFields': _pinnedFieldsStorage.exportJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  BackupContents parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw BackupException(BackupErrorType.malformed, 'Not valid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw BackupException(
        BackupErrorType.malformed,
        'Top-level JSON value is not an object',
      );
    }
    if (decoded['app'] != _kBackupApp) {
      throw BackupException(
        BackupErrorType.notABackup,
        'Missing or unrecognised "app" marker',
      );
    }
    final version = decoded['version'];
    if (version is int && version > _kBackupVersion) {
      throw BackupException(
        BackupErrorType.newerVersion,
        'Backup version $version is newer than supported version $_kBackupVersion',
      );
    }

    try {
      final channelsJson = decoded['channels'];
      final channels = channelsJson is List
          ? channelsJson
                .whereType<Map<String, dynamic>>()
                .map(Channel.fromJson)
                .toList()
          : null;
      final settings = decoded['settings'];
      final fieldChartSettings = decoded['fieldChartSettings'];
      final pinnedFields = decoded['pinnedFields'];
      final exportedAtValue = decoded['exportedAt'];
      final appVersionValue = decoded['appVersion'];
      return BackupContents(
        channels: channels,
        settings: settings is Map<String, dynamic> ? settings : null,
        fieldChartSettings: fieldChartSettings is Map<String, dynamic>
            ? fieldChartSettings
            : null,
        pinnedFields: pinnedFields is List ? pinnedFields : null,
        exportedAt: exportedAtValue is String
            ? DateTime.tryParse(exportedAtValue)
            : null,
        appVersion: appVersionValue is String && appVersionValue.isNotEmpty
            ? appVersionValue
            : null,
        apiKeysExcluded: decoded['apiKeysExcluded'] == true,
      );
    } catch (e) {
      throw BackupException(BackupErrorType.malformed, e.toString());
    }
  }

  /// Fills a keyless incoming private channel's API key from the currently
  /// saved copy, if there is one, rather than either losing a key the app
  /// cannot recover or silently leaving the channel unable to authenticate.
  Channel _withKey(Channel incoming, Channel? existing) {
    if (incoming.isPublic || incoming.apiKey?.isNotEmpty == true) {
      return incoming;
    }
    final key = existing?.apiKey;
    if (key != null && key.isNotEmpty) return incoming.copyWith(apiKey: key);
    return incoming.copyWith(authError: true);
  }

  /// Builds a diff of [contents] against everything currently saved, for the
  /// import preview screen to render and the user to select from.
  ImportPlan planImport(BackupContents contents) {
    final savedChannels = _channelStorage.loadChannels();
    final existingByIdentity = {for (final c in savedChannels) c: c};
    final incoming = contents.channels ?? const <Channel>[];
    final incomingIdentities = incoming.toSet();

    final fileChartSettings =
        contents.fieldChartSettings ?? const <String, dynamic>{};
    final filePins = (contents.pinnedFields ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(PinnedField.fromJson)
        .toList();

    String prefixFor(Channel c) => '${c.serverUrl}|${c.id}|';

    final channelDiffs = <ChannelDiff>[];
    for (final c in incoming) {
      final existing = existingByIdentity[c];
      final effective = _withKey(c, existing);
      final changes = <ChannelFieldChange>{};
      if (existing != null) {
        if (effective.name != existing.name) {
          changes.add(ChannelFieldChange.name);
        }
        if (effective.apiKey != existing.apiKey) {
          changes.add(ChannelFieldChange.apiKey);
        }
        if (effective.isPublic != existing.isPublic) {
          changes.add(ChannelFieldChange.visibility);
        }
      }
      final change = existing == null
          ? ChannelChange.added
          : (changes.isEmpty ? ChannelChange.unchanged : ChannelChange.updated);
      final needsApiKey =
          !effective.isPublic &&
          (effective.apiKey == null || effective.apiKey!.isEmpty);
      final prefix = prefixFor(c);
      channelDiffs.add(
        ChannelDiff(
          incoming: c,
          existing: existing,
          change: change,
          changes: changes,
          needsApiKey: needsApiKey,
          chartSettingKeys: fileChartSettings.keys
              .where((k) => k.startsWith(prefix))
              .toList(),
          pinnedFields: filePins.where((p) => p.matches(c)).toList(),
        ),
      );
    }

    final orphanChartSettingKeys = fileChartSettings.keys
        .where((k) => !incoming.any((c) => k.startsWith(prefixFor(c))))
        .toList();
    final orphanPinnedFields = filePins
        .where((p) => !incoming.any((c) => p.matches(c)))
        .toList();
    final onlyOnDevice = savedChannels
        .where((c) => !incomingIdentities.contains(c))
        .toList();

    final incomingSettings = contents.settings;
    final settingsDiffs = <SettingDiff>[];
    if (incomingSettings != null) {
      final savedSettings = _settingsStorage.exportJson();
      for (final key in BackupSettingKey.values) {
        settingsDiffs.add(
          SettingDiff.compute(key, savedSettings, incomingSettings),
        );
      }
    }

    return ImportPlan(
      contents: contents,
      channels: channelDiffs,
      settings: settingsDiffs,
      orphanChartSettingKeys: orphanChartSettingKeys,
      orphanPinnedFields: orphanPinnedFields,
      onlyOnDevice: onlyOnDevice,
    );
  }

  /// Applies [selection] from a previously built [ImportPlan]: selected
  /// channels are merged into the saved list (through [_withKey], so a
  /// locally saved API key survives a keyless backup), unselected saved data
  /// is left alone, and [ImportSelection.removeChannelsNotInBackup] controls
  /// whether saved channels absent from [contents] are dropped.
  Future<void> applyImport(
    BackupContents contents,
    ImportSelection selection,
  ) async {
    final saved = _channelStorage.loadChannels();
    final existingByIdentity = {for (final c in saved) c: c};
    final reconciledByIdentity = {
      for (final c in selection.channels)
        c: _withKey(c, existingByIdentity[c]),
    };
    final incomingIdentities = (contents.channels ?? const <Channel>[])
        .toSet();

    final result = <Channel>[];
    for (final c in saved) {
      if (selection.removeChannelsNotInBackup &&
          !incomingIdentities.contains(c)) {
        continue;
      }
      result.add(reconciledByIdentity[c] ?? c);
    }
    for (final entry in reconciledByIdentity.entries) {
      if (!existingByIdentity.containsKey(entry.key)) result.add(entry.value);
    }
    await _channelStorage.saveChannels(result);

    final settings = contents.settings;
    if (settings != null) {
      final allowedKeys = {
        for (final key in selection.settingKeys) ...key.prefsKeys,
      };
      await _settingsStorage.importJson({
        for (final entry in settings.entries)
          if (allowedKeys.contains(entry.key)) entry.key: entry.value,
      });
    }

    final fieldChartSettings = contents.fieldChartSettings;
    if (fieldChartSettings != null) {
      await _fieldSettingsStorage.mergeJson({
        for (final entry in fieldChartSettings.entries)
          if (selection.fieldChartSettingsKeys.contains(entry.key))
            entry.key: entry.value,
      });
    }

    await _pinnedFieldsStorage.mergeJson(
      selection.pinnedFields.map((p) => p.toJson()).toList(),
    );
  }
}
