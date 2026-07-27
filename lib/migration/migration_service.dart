import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../storage/settings_storage.dart';

// ── Legacy model ─────────────────────────────────────────────────────────────

/// Mirrors the old `ChannelModel` Hive type. Exposed for testing only.
@visibleForTesting
class LegacyChannel {
  final int id;
  final String name;
  final String serverUrl;
  final bool public;
  final String apiKey;
  final int order;
  final String description;
  final double latitude;
  final double longitude;

  const LegacyChannel({
    required this.id,
    this.name = '',
    this.serverUrl = '',
    this.public = true,
    this.apiKey = '',
    this.order = -1,
    this.description = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
  });
}

// ── Legacy TypeAdapter ────────────────────────────────────────────────────────

/// Minimal adapter that matches the old ChannelModel binary layout
/// (typeId 0, fields 0–8). Exposed for testing so test code can seed
/// Hive boxes with legacy data.
@visibleForTesting
class LegacyChannelAdapter extends TypeAdapter<LegacyChannel> {
  @override
  final int typeId = 0;

  @override
  LegacyChannel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LegacyChannel(
      id: (fields[0] as num?)?.toInt() ?? 0,
      name: fields[1] as String? ?? '',
      serverUrl: fields[2] as String? ?? '',
      public: fields[3] as bool? ?? true,
      apiKey: fields[4] as String? ?? '',
      order: (fields[5] as num?)?.toInt() ?? -1,
      description: fields[6] as String? ?? '',
      latitude: (fields[7] as num?)?.toDouble() ?? 0.0,
      longitude: (fields[8] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  void write(BinaryWriter writer, LegacyChannel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.serverUrl)
      ..writeByte(3)
      ..write(obj.public)
      ..writeByte(4)
      ..write(obj.apiKey)
      ..writeByte(5)
      ..write(obj.order)
      ..writeByte(6)
      ..write(obj.description)
      ..writeByte(7)
      ..write(obj.latitude)
      ..writeByte(8)
      ..write(obj.longitude);
  }
}

// ── Format mapping tables ────────────────────────────────────────────────────

const _dateFormatMap = <String, String>{
  'yyyy-MM-dd': 'yyyy-MM-dd',
  'MM/dd/yyyy': 'MM/dd/yyyy',
  'MM/dd/yy': 'MM/dd/yyyy',
  'dd/MM/yyyy': 'dd.MM.yyyy',
  'dd/MM/yy': 'dd.MM.yyyy',
  'd.M.y': 'dd.MM.yyyy',
  'dd.MM.y': 'dd.MM.yyyy',
};

const _timeFormatMap = <String, String>{
  'HH:mm:ss': 'HH:mm',
  'HH:mm': 'HH:mm',
  'h:mm:ss a': 'hh:mm a',
  'h:mm a': 'hh:mm a',
  'hh:mm:ss a': 'hh:mm a',
  'hh:mm a': 'hh:mm a',
};

// ── SharedPreferences keys mirrored from storage layer ───────────────────────

const _kChannelsKey = 'channels';
const _kThemeModeKey = 'themeMode';
const _kDateFormatKey = 'dateFormat';
const _kTimeFormatKey = 'timeFormat';

// ── MigrationService ─────────────────────────────────────────────────────────

/// One-time migration from Hive (old build) to SharedPreferences (rewrite).
///
/// Call [run] once at app startup, before constructing any storage objects.
/// The method is idempotent — subsequent calls return immediately via the
/// [_migrationFlagKey] guard. All failures are caught and logged so a
/// corrupted legacy box can never prevent the app from starting.
///
/// TODO(migration): remove this class, the hive/hive_flutter dependencies in
/// pubspec.yaml, and this file once the migration has shipped and reached the
/// installed base.
class MigrationService {
  static const _migrationFlagKey = 'migration_v2_done';
  static const _legacyChannelsBox = 'channels';
  static const _legacySettingsBox = 'settings';
  static const _legacyDateFormatKey = 'dateFormat';
  static const _legacyTimeFormatKey = 'timeFormat';
  static const _legacyThemeModeKey = 'themeMode';

  final SharedPreferences _prefs;

  /// Optional override for Hive initialisation — inject a no-op in tests
  /// where [Hive.init] has already been called with a temp directory so that
  /// [Hive.initFlutter] (which requires the `path_provider` plugin) is skipped.
  @visibleForTesting
  final Future<void> Function() hiveInit;

  MigrationService(this._prefs, {Future<void> Function()? hiveInit})
    : hiveInit = hiveInit ?? _legacyHiveInit;

  /// Initialises Hive at the path where the old build stored its boxes.
  ///
  /// Older versions of `path_provider` on Android returned a directory with an
  /// `app_flutter` suffix (e.g. `.../app_flutter/`), which is where the legacy
  /// app stored its Hive boxes. Newer versions return a plain `files/` path.
  /// We resolve the legacy directory explicitly so the migration always finds
  /// the right data regardless of the `path_provider` version in use.
  static Future<void> _legacyHiveInit() async {
    final appDir = await getApplicationDocumentsDirectory();
    // Try the old 'app_flutter' sibling directory first; fall back to the
    // current documents directory if it doesn't exist (e.g. on iOS or fresh
    // installs where the legacy path was never created).
    final legacyDir = Directory('${appDir.parent.path}/app_flutter');
    final path = legacyDir.existsSync() ? legacyDir.path : appDir.path;
    Hive.init(path);
  }

  Future<void> run() async {
    if (_prefs.getBool(_migrationFlagKey) == true) return;
    try {
      await hiveInit();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(LegacyChannelAdapter());
      }
      await _migrateChannels();
      await _migrateSettings();
    } catch (e, st) {
      debugPrint('Migration failed: $e\n$st');
    } finally {
      await _prefs.setBool(_migrationFlagKey, true);
    }
  }

  Future<void> _migrateChannels() async {
    Box<LegacyChannel>? box;
    try {
      box = await Hive.openBox<LegacyChannel>(_legacyChannelsBox);
      if (box.isEmpty) return;

      // Guard: do not clobber channels already saved in the new format.
      if (_prefs.containsKey(_kChannelsKey)) return;

      final sorted = box.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      final channels = sorted.map((legacy) {
        return Channel(
          id: legacy.id,
          name: legacy.name.isEmpty ? null : legacy.name,
          serverUrl: legacy.serverUrl.isEmpty
              ? 'https://api.thingspeak.com'
              : legacy.serverUrl,
          isPublic: legacy.public,
          apiKey: legacy.apiKey.isEmpty ? null : legacy.apiKey,
        );
      }).toList();

      await _prefs.setString(_kChannelsKey, Channel.listToJson(channels));
    } finally {
      await box?.close();
    }
  }

  Future<void> _migrateSettings() async {
    Box<dynamic>? box;
    try {
      box = await Hive.openBox<dynamic>(_legacySettingsBox);

      // Only write each setting if the new key does not exist yet, so we
      // preserve anything the user changed in the new build before the first
      // migration pass (unlikely but defensive).

      final legacyDate = box.get(_legacyDateFormatKey) as String?;
      if (legacyDate != null && !_prefs.containsKey(_kDateFormatKey)) {
        final mapped = _dateFormatMap[legacyDate] ?? defaultDateFormat;
        await _prefs.setString(_kDateFormatKey, mapped);
      }

      final legacyTime = box.get(_legacyTimeFormatKey) as String?;
      if (legacyTime != null && !_prefs.containsKey(_kTimeFormatKey)) {
        final mapped = _timeFormatMap[legacyTime] ?? defaultTimeFormat;
        await _prefs.setString(_kTimeFormatKey, mapped);
      }

      final legacyTheme = box.get(_legacyThemeModeKey);
      if (legacyTheme != null && !_prefs.containsKey(_kThemeModeKey)) {
        final index = (legacyTheme as num).toInt();
        // Clamp to valid ThemeMode range (0 = system, 1 = light, 2 = dark).
        final clamped = index.clamp(0, 2);
        await _prefs.setInt(_kThemeModeKey, clamped);
      }
    } finally {
      await box?.close();
    }
  }
}
