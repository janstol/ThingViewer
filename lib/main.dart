import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api/thingspeak_api.dart';
import 'app.dart';
import 'migration/migration_service.dart';
import 'storage/channel_storage.dart';
import 'storage/field_settings_storage.dart';
import 'storage/settings_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await MigrationService(prefs).run();
  final api = ThingSpeakApi(http.Client());
  final channelStorage = ChannelStorage(prefs);
  final settingsStorage = SettingsStorage(prefs);
  final fieldSettingsStorage = FieldSettingsStorage(prefs);

  runApp(
    App(
      api: api,
      channelStorage: channelStorage,
      settingsStorage: settingsStorage,
      fieldSettingsStorage: fieldSettingsStorage,
    ),
  );
}
