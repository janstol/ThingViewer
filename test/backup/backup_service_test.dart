import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: false,
  apiKey: 'secret-key',
  name: 'My Channel',
);

const _otherChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Other Channel',
);

Future<BackupService> _service() async {
  final prefs = await SharedPreferences.getInstance();
  return BackupService(
    ChannelStorage(prefs),
    SettingsStorage(prefs),
    FieldSettingsStorage(prefs),
    appVersion: () async => '0.9.0',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export → parse → restore round trip', () {
    test('preserves channels, settings, and field chart settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      final settingsStorage = SettingsStorage(prefs);
      final fieldSettingsStorage = FieldSettingsStorage(prefs);

      await channelStorage.saveChannels([_channel, _otherChannel]);
      await settingsStorage.saveThemeMode(ThemeMode.dark);
      await settingsStorage.saveDateFormat('yyyy-MM-dd');
      await settingsStorage.saveTimezoneDisplay(TimezoneDisplay.offset);
      await settingsStorage.saveStartChannel(_channel);
      const chartSettings = FieldChartSettings(
        type: ChartType.step,
        showDelta: true,
      );
      await fieldSettingsStorage.save(_channel, 1, chartSettings);

      final service = BackupService(
        channelStorage,
        settingsStorage,
        fieldSettingsStorage,
        appVersion: () async => '0.9.0',
      );
      final raw = await service.export();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['app'], 'thingviewer');
      expect(decoded['version'], 1);
      expect(decoded['appVersion'], '0.9.0');

      // Restore into fresh, empty storage to prove the round trip carries
      // everything, not just whatever was already there.
      SharedPreferences.setMockInitialValues({});
      final freshPrefs = await SharedPreferences.getInstance();
      final freshService = BackupService(
        ChannelStorage(freshPrefs),
        SettingsStorage(freshPrefs),
        FieldSettingsStorage(freshPrefs),
      );
      final contents = freshService.parse(raw);
      await freshService.restore(contents, ImportMode.replace);

      final restoredChannels = ChannelStorage(freshPrefs).loadChannels();
      expect(restoredChannels, [_channel, _otherChannel]);

      final restoredSettings = SettingsStorage(freshPrefs);
      expect(restoredSettings.themeMode, ThemeMode.dark);
      expect(restoredSettings.dateFormat, 'yyyy-MM-dd');
      expect(restoredSettings.timezoneDisplay, TimezoneDisplay.offset);
      expect(restoredSettings.startChannelId, _channel.id);
      expect(restoredSettings.startChannelServerUrl, _channel.serverUrl);

      final restoredFieldSettings = FieldSettingsStorage(freshPrefs);
      expect(restoredFieldSettings.settingsFor(_channel, 1), chartSettings);
    });
  });

  group('ImportMode.addChannels', () {
    test(
      'appends only channels not already present, by (id, serverUrl)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        await channelStorage.saveChannels([_channel]);
        final service = BackupService(
          channelStorage,
          SettingsStorage(prefs),
          FieldSettingsStorage(prefs),
        );

        const thirdChannel = Channel(
          id: 3,
          serverUrl: 'https://api.thingspeak.com',
          isPublic: true,
          name: 'Third Channel',
        );
        final contents = BackupContents(
          channels: [_channel, _otherChannel, thirdChannel],
        );

        await service.restore(contents, ImportMode.addChannels);

        expect(channelStorage.loadChannels(), [
          _channel,
          _otherChannel,
          thirdChannel,
        ]);
      },
    );

    test('leaves settings and field chart settings untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      final settingsStorage = SettingsStorage(prefs);
      await settingsStorage.saveThemeMode(ThemeMode.light);
      final service = BackupService(
        channelStorage,
        settingsStorage,
        FieldSettingsStorage(prefs),
      );

      final contents = BackupContents(
        channels: [_otherChannel],
        settings: {'themeMode': ThemeMode.dark.index},
      );

      await service.restore(contents, ImportMode.addChannels);

      expect(settingsStorage.themeMode, ThemeMode.light);
    });
  });

  group('ImportMode.replace', () {
    test('overwrites channels with exactly the backup contents', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_otherChannel]);
      final service = BackupService(
        channelStorage,
        SettingsStorage(prefs),
        FieldSettingsStorage(prefs),
      );

      final contents = BackupContents(channels: [_channel]);
      await service.restore(contents, ImportMode.replace);

      expect(channelStorage.loadChannels(), [_channel]);
    });

    test('leaves a section alone when absent from the backup', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_otherChannel]);
      final service = BackupService(
        channelStorage,
        SettingsStorage(prefs),
        FieldSettingsStorage(prefs),
      );

      // No `channels` section in this payload.
      final contents = BackupContents(settings: {'themeMode': 1});
      await service.restore(contents, ImportMode.replace);

      expect(channelStorage.loadChannels(), [_otherChannel]);
    });
  });

  group('parse errors', () {
    test('throws BackupException for malformed JSON', () async {
      final service = await _service();
      expect(
        () => service.parse('not json'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.type,
            'type',
            BackupErrorType.malformed,
          ),
        ),
      );
    });

    test('throws BackupException when the app marker is missing', () async {
      final service = await _service();
      final raw = jsonEncode({'version': 1, 'channels': []});
      expect(
        () => service.parse(raw),
        throwsA(
          isA<BackupException>().having(
            (e) => e.type,
            'type',
            BackupErrorType.notABackup,
          ),
        ),
      );
    });

    test('throws BackupException for a newer version', () async {
      final service = await _service();
      final raw = jsonEncode({'app': 'thingviewer', 'version': 2});
      expect(
        () => service.parse(raw),
        throwsA(
          isA<BackupException>().having(
            (e) => e.type,
            'type',
            BackupErrorType.newerVersion,
          ),
        ),
      );
    });

    test('imports cleanly from a channels-only payload', () async {
      final service = await _service();
      final raw = jsonEncode({
        'app': 'thingviewer',
        'version': 1,
        'channels': [_channel.toJson()],
      });

      final contents = service.parse(raw);

      expect(contents.channels, [_channel]);
      expect(contents.settings, isNull);
      expect(contents.fieldChartSettings, isNull);
    });
  });
}
