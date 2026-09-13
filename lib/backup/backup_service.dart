import 'dart:convert';

import '../models/channel.dart';
import '../models/field_chart_settings.dart';
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
///
/// [channels], [fieldChartSettings] and [pinnedFields] are validated and
/// salvaged entry-by-entry at parse time (mirroring how `storage_recovery.dart`
/// salvages corrupt prefs entries): an individually malformed entry is
/// dropped and counted in [skippedEntries] rather than failing the whole
/// file. Downstream code (`planImport`, `applyImport`) can then trust every
/// entry it sees.
class BackupContents {
  final List<Channel>? channels;
  final Map<String, dynamic>? settings;
  final Map<String, FieldChartSettings>? fieldChartSettings;
  final List<PinnedField>? pinnedFields;
  final DateTime? exportedAt;
  final String? appVersion;
  final bool apiKeysExcluded;

  /// Entries that failed to parse and were skipped — a malformed channel, a
  /// pin missing a required field, or a chart override with a value of the
  /// wrong type. Zero means every entry in the file parsed cleanly.
  final int skippedEntries;

  const BackupContents({
    this.channels,
    this.settings,
    this.fieldChartSettings,
    this.pinnedFields,
    this.exportedAt,
    this.appVersion,
    this.apiKeysExcluded = false,
    this.skippedEntries = 0,
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
      var skippedEntries = 0;

      final channelsJson = decoded['channels'];
      List<Channel>? channels;
      if (channelsJson is List) {
        channels = [];
        for (final entry in channelsJson) {
          if (entry is! Map<String, dynamic>) {
            skippedEntries++;
            continue;
          }
          try {
            channels.add(Channel.fromJson(entry));
          } catch (_) {
            skippedEntries++;
          }
        }
      }

      final pinnedFieldsJson = decoded['pinnedFields'];
      List<PinnedField>? pinnedFields;
      if (pinnedFieldsJson is List) {
        pinnedFields = [];
        for (final entry in pinnedFieldsJson) {
          if (entry is! Map<String, dynamic>) {
            skippedEntries++;
            continue;
          }
          try {
            pinnedFields.add(PinnedField.fromJson(entry));
          } catch (_) {
            skippedEntries++;
          }
        }
      }

      final fieldChartSettingsJson = decoded['fieldChartSettings'];
      Map<String, FieldChartSettings>? fieldChartSettings;
      if (fieldChartSettingsJson is Map<String, dynamic>) {
        fieldChartSettings = {};
        for (final entry in fieldChartSettingsJson.entries) {
          if (entry.value is! Map<String, dynamic>) {
            skippedEntries++;
            continue;
          }
          try {
            fieldChartSettings[entry.key] = FieldChartSettings.fromJson(
              entry.value as Map<String, dynamic>,
            );
          } catch (_) {
            skippedEntries++;
          }
        }
      }

      final settings = decoded['settings'];
      final exportedAtValue = decoded['exportedAt'];
      final appVersionValue = decoded['appVersion'];
      return BackupContents(
        channels: channels,
        settings: settings is Map<String, dynamic> ? settings : null,
        fieldChartSettings: fieldChartSettings,
        pinnedFields: pinnedFields,
        exportedAt: exportedAtValue is String
            ? DateTime.tryParse(exportedAtValue)
            : null,
        appVersion: appVersionValue is String && appVersionValue.isNotEmpty
            ? appVersionValue
            : null,
        apiKeysExcluded: decoded['apiKeysExcluded'] == true,
        skippedEntries: skippedEntries,
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
        contents.fieldChartSettings ?? const <String, FieldChartSettings>{};
    final filePins = contents.pinnedFields ?? const <PinnedField>[];

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
  ///
  /// Every prefs key this can touch is snapshotted first. If anything throws
  /// partway through — most likely a storage write failing — every touched
  /// key is restored to its pre-import value rather than left half-imported,
  /// and the failure surfaces as a [BackupException].
  Future<void> applyImport(
    BackupContents contents,
    ImportSelection selection,
  ) async {
    final channelsSnapshot = _channelStorage.rawJson;
    final fieldChartSettingsSnapshot = _fieldSettingsStorage.rawJson;
    final pinnedFieldsSnapshot = _pinnedFieldsStorage.rawJson;
    final settingsSnapshot = _settingsStorage.snapshotForImport();

    try {
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
        if (!existingByIdentity.containsKey(entry.key)) {
          result.add(entry.value);
        }
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
              entry.key: entry.value.toJson(),
        });
      }

      await _pinnedFieldsStorage.mergeJson(
        selection.pinnedFields.map((p) => p.toJson()).toList(),
      );
    } catch (e) {
      await _channelStorage.restoreRawJson(channelsSnapshot);
      await _fieldSettingsStorage.restoreRawJson(fieldChartSettingsSnapshot);
      _fieldSettingsStorage.reload();
      await _pinnedFieldsStorage.restoreRawJson(pinnedFieldsSnapshot);
      _pinnedFieldsStorage.reload();
      await _settingsStorage.restoreSnapshot(settingsSnapshot);
      throw BackupException(BackupErrorType.malformed, e.toString());
    }
  }
}
