import 'dart:convert';

import '../models/channel.dart';
import '../storage/channel_storage.dart';
import '../storage/field_settings_storage.dart';
import '../storage/settings_storage.dart';

const _kBackupApp = 'thingviewer';
const _kBackupVersion = 1;

enum ImportMode { replace, addChannels }

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
  final DateTime? exportedAt;

  const BackupContents({
    this.channels,
    this.settings,
    this.fieldChartSettings,
    this.exportedAt,
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

  /// Resolved lazily, only when [export] actually needs it, so constructing
  /// a [BackupService] at app startup doesn't have to wait on a
  /// platform-channel round trip nobody may ever need.
  final Future<String> Function() appVersion;

  BackupService(
    this._channelStorage,
    this._settingsStorage,
    this._fieldSettingsStorage, {
    this.appVersion = _noAppVersion,
  });

  static Future<String> _noAppVersion() async => '';

  Future<String> export() async {
    final version = await appVersion();
    final json = {
      'app': _kBackupApp,
      'version': _kBackupVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      if (version.isNotEmpty) 'appVersion': version,
      'channels': _channelStorage
          .loadChannels()
          .map((c) => c.toJson())
          .toList(),
      'settings': _settingsStorage.exportJson(),
      'fieldChartSettings': _fieldSettingsStorage.exportJson(),
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
      final exportedAtValue = decoded['exportedAt'];
      return BackupContents(
        channels: channels,
        settings: settings is Map<String, dynamic> ? settings : null,
        fieldChartSettings: fieldChartSettings is Map<String, dynamic>
            ? fieldChartSettings
            : null,
        exportedAt: exportedAtValue is String
            ? DateTime.tryParse(exportedAtValue)
            : null,
      );
    } catch (e) {
      throw BackupException(BackupErrorType.malformed, e.toString());
    }
  }

  Future<void> restore(BackupContents contents, ImportMode mode) async {
    switch (mode) {
      case ImportMode.replace:
        final channels = contents.channels;
        if (channels != null) {
          await _channelStorage.saveChannels(channels);
        }
        final settings = contents.settings;
        if (settings != null) {
          await _settingsStorage.importJson(settings);
        }
        final fieldChartSettings = contents.fieldChartSettings;
        if (fieldChartSettings != null) {
          await _fieldSettingsStorage.importJson(fieldChartSettings);
        }
      case ImportMode.addChannels:
        final incoming = contents.channels;
        if (incoming == null || incoming.isEmpty) return;
        final existing = _channelStorage.loadChannels();
        final existingSet = existing.toSet();
        final merged = [
          ...existing,
          ...incoming.where((c) => !existingSet.contains(c)),
        ];
        await _channelStorage.saveChannels(merged);
    }
  }
}
