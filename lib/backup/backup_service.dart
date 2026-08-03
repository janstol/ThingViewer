import 'dart:convert';

import '../models/channel.dart';
import '../storage/channel_storage.dart';
import '../storage/field_settings_storage.dart';
import '../storage/pinned_fields_storage.dart';
import '../storage/settings_storage.dart';

const _kBackupApp = 'thingviewer';
const _kBackupVersion = 2;

enum ImportMode { replace, addChannels }

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
/// (but present) section, so [BackupService.restore] knows what to leave
/// untouched in [ImportMode.replace].
class BackupContents {
  final List<Channel>? channels;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? fieldChartSettings;
  final List<dynamic>? pinnedFields;
  final DateTime? exportedAt;
  final bool apiKeysExcluded;

  const BackupContents({
    this.channels,
    this.settings,
    this.fieldChartSettings,
    this.pinnedFields,
    this.exportedAt,
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

  /// Counts private channels in [contents] that will actually end up
  /// needing an API key re-entered after import: no key in the file, and no
  /// already-saved channel to recover one from. A plain count of keyless
  /// channels in the file overstates this whenever a channel being restored
  /// already has a usable (or even just non-empty) key saved locally, since
  /// [restore] preserves it.
  int channelsNeedingApiKey(BackupContents contents) {
    final channels = contents.channels;
    if (channels == null) return 0;
    final existingByIdentity = {
      for (final c in _channelStorage.loadChannels()) c: c,
    };
    return channels.where((c) {
      if (c.isPublic || (c.apiKey?.isNotEmpty ?? false)) return false;
      final key = existingByIdentity[c]?.apiKey;
      return key == null || key.isEmpty;
    }).length;
  }

  Future<void> restore(BackupContents contents, ImportMode mode) async {
    switch (mode) {
      case ImportMode.replace:
        final channels = contents.channels;
        if (channels != null) {
          final existingByIdentity = {
            for (final c in _channelStorage.loadChannels()) c: c,
          };
          await _channelStorage.saveChannels(
            channels.map((c) => _withKey(c, existingByIdentity[c])).toList(),
          );
        }
        final settings = contents.settings;
        if (settings != null) {
          await _settingsStorage.importJson(settings);
        }
        final fieldChartSettings = contents.fieldChartSettings;
        if (fieldChartSettings != null) {
          await _fieldSettingsStorage.importJson(fieldChartSettings);
        }
        final pinnedFields = contents.pinnedFields;
        if (pinnedFields != null) {
          await _pinnedFieldsStorage.importJson(pinnedFields);
        }
      case ImportMode.addChannels:
        final incoming = contents.channels;
        if (incoming == null || incoming.isEmpty) return;
        final existing = _channelStorage.loadChannels();
        final existingSet = existing.toSet();
        final merged = [
          ...existing,
          ...incoming
              .where((c) => !existingSet.contains(c))
              .map((c) => _withKey(c, null)),
        ];
        await _channelStorage.saveChannels(merged);
    }
  }
}
