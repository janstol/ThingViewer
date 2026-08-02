import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/thingspeak_api.dart';
import 'app.dart';
import 'backup/backup_service.dart';
import 'migration/migration_service.dart';
import 'storage/channel_snapshot_storage.dart';
import 'storage/channel_storage.dart';
import 'storage/field_settings_storage.dart';
import 'storage/pinned_fields_storage.dart';
import 'storage/settings_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await MigrationService(prefs).run();
  final api = ThingSpeakApi(http.Client());
  final channelStorage = ChannelStorage(prefs);
  final settingsStorage = SettingsStorage(prefs);
  final fieldSettingsStorage = FieldSettingsStorage(prefs);
  final pinnedFieldsStorage = PinnedFieldsStorage(prefs);
  final channelSnapshotStorage = ChannelSnapshotStorage(prefs);
  final backupService = BackupService(
    channelStorage,
    settingsStorage,
    fieldSettingsStorage,
    pinnedFieldsStorage,
    appVersion: () async => (await PackageInfo.fromPlatform()).version,
  );

  runApp(
    App(
      api: api,
      channelStorage: channelStorage,
      settingsStorage: settingsStorage,
      fieldSettingsStorage: fieldSettingsStorage,
      pinnedFieldsStorage: pinnedFieldsStorage,
      channelSnapshotStorage: channelSnapshotStorage,
      backupService: backupService,
    ),
  );
}
