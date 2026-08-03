import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/models/pinned_field.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';
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

// Same identity (id + serverUrl) as [_channel], but with no apiKey — what a
// keyless backup file produces for a private channel.
const _keylessChannel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: false,
  name: 'My Channel',
);

Future<BackupService> _service() async {
  final prefs = await SharedPreferences.getInstance();
  return BackupService(
    ChannelStorage(prefs),
    SettingsStorage(prefs),
    FieldSettingsStorage(prefs),
    PinnedFieldsStorage(prefs),
    appVersion: () async => '0.9.0',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export → parse → restore round trip', () {
    test(
      'preserves channels, settings, field chart settings, and pinned fields',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        final settingsStorage = SettingsStorage(prefs);
        final fieldSettingsStorage = FieldSettingsStorage(prefs);
        final pinnedFieldsStorage = PinnedFieldsStorage(prefs);

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
        await pinnedFieldsStorage.toggle(_channel, 1);

        final service = BackupService(
          channelStorage,
          settingsStorage,
          fieldSettingsStorage,
          pinnedFieldsStorage,
          appVersion: () async => '0.9.0',
        );
        final raw = await service.export();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        expect(decoded['app'], 'thingviewer');
        expect(decoded['version'], 2);
        expect(decoded['appVersion'], '0.9.0');

        // Restore into fresh, empty storage to prove the round trip carries
        // everything, not just whatever was already there.
        SharedPreferences.setMockInitialValues({});
        final freshPrefs = await SharedPreferences.getInstance();
        final freshService = BackupService(
          ChannelStorage(freshPrefs),
          SettingsStorage(freshPrefs),
          FieldSettingsStorage(freshPrefs),
          PinnedFieldsStorage(freshPrefs),
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

        final restoredPinnedFields = PinnedFieldsStorage(freshPrefs);
        expect(restoredPinnedFields.isPinned(_channel, 1), isTrue);
      },
    );
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
          PinnedFieldsStorage(prefs),
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
        PinnedFieldsStorage(prefs),
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
        PinnedFieldsStorage(prefs),
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
        PinnedFieldsStorage(prefs),
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
      final raw = jsonEncode({'app': 'thingviewer', 'version': 3});
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
      expect(contents.pinnedFields, isNull);
    });

    test('parses a pinnedFields section', () async {
      final service = await _service();
      final raw = jsonEncode({
        'app': 'thingviewer',
        'version': 2,
        'pinnedFields': [
          const PinnedField(
            serverUrl: 'https://api.thingspeak.com',
            channelId: 1,
            fieldId: 1,
          ).toJson(),
        ],
      });

      final contents = service.parse(raw);

      expect(contents.pinnedFields, hasLength(1));
    });
  });

  group('BackupExportMode.withoutApiKeys', () {
    test('omits apiKey and sets apiKeysExcluded, leaving public channels and '
        'other sections unaffected', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      final settingsStorage = SettingsStorage(prefs);
      await channelStorage.saveChannels([_channel, _otherChannel]);
      await settingsStorage.saveThemeMode(ThemeMode.dark);
      final service = BackupService(
        channelStorage,
        settingsStorage,
        FieldSettingsStorage(prefs),
        PinnedFieldsStorage(prefs),
      );

      final fullRaw = await service.export();
      final keylessRaw = await service.export(
        mode: BackupExportMode.withoutApiKeys,
      );
      final fullDecoded = jsonDecode(fullRaw) as Map<String, dynamic>;
      final keylessDecoded = jsonDecode(keylessRaw) as Map<String, dynamic>;

      expect(fullDecoded.containsKey('apiKeysExcluded'), isFalse);
      expect(keylessDecoded['apiKeysExcluded'], isTrue);

      final keylessChannels = keylessDecoded['channels'] as List<dynamic>;
      final privateJson = keylessChannels.firstWhere(
        (c) => c['id'] == _channel.id,
      );
      expect(privateJson.containsKey('apiKey'), isFalse);
      final publicJson = keylessChannels.firstWhere(
        (c) => c['id'] == _otherChannel.id,
      );
      expect(publicJson.containsKey('apiKey'), isFalse);

      expect(keylessDecoded['settings'], fullDecoded['settings']);
      expect(
        keylessDecoded['fieldChartSettings'],
        fullDecoded['fieldChartSettings'],
      );
      expect(keylessDecoded['pinnedFields'], fullDecoded['pinnedFields']);
    });

    test(
      'full-mode export is unaffected by the new mode parameter (regression)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        await channelStorage.saveChannels([_channel, _otherChannel]);
        final service = BackupService(
          channelStorage,
          SettingsStorage(prefs),
          FieldSettingsStorage(prefs),
          PinnedFieldsStorage(prefs),
        );

        final defaultRaw = await service.export();
        final explicitFullRaw = await service.export(
          mode: BackupExportMode.full,
        );
        final decoded = jsonDecode(defaultRaw) as Map<String, dynamic>;
        final explicitDecoded =
            jsonDecode(explicitFullRaw) as Map<String, dynamic>;

        // exportedAt is a fresh timestamp on each call, so compare
        // everything else for exact equality.
        decoded.remove('exportedAt');
        explicitDecoded.remove('exportedAt');
        expect(explicitDecoded, decoded);
        expect(decoded.containsKey('apiKeysExcluded'), isFalse);
        final channelsJson = decoded['channels'] as List<dynamic>;
        final privateJson = channelsJson.firstWhere(
          (c) => c['id'] == _channel.id,
        );
        expect(privateJson['apiKey'], _channel.apiKey);
      },
    );
  });

  group('BackupService.channelsNeedingApiKey', () {
    test(
      'counts a keyless private channel with no existing saved match',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = await _service();
        const keylessPrivate = Channel(
          id: 3,
          serverUrl: 'https://api.thingspeak.com',
          isPublic: false,
        );
        final contents = BackupContents(
          channels: [_keylessChannel, _otherChannel, keylessPrivate],
        );

        expect(service.channelsNeedingApiKey(contents), 2);
      },
    );

    test(
      'excludes a keyless channel that already has a saved key locally',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await ChannelStorage(prefs).saveChannels([_channel]);
        final service = await _service();
        final contents = BackupContents(channels: [_keylessChannel]);

        expect(service.channelsNeedingApiKey(contents), 0);
      },
    );

    test('is zero when there are no channels', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _service();
      const contents = BackupContents();

      expect(service.channelsNeedingApiKey(contents), 0);
    });
  });

  group('restore key reconciliation', () {
    test('ImportMode.replace preserves an existing saved key when the '
        'incoming channel has none', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_channel]);
      final service = BackupService(
        channelStorage,
        SettingsStorage(prefs),
        FieldSettingsStorage(prefs),
        PinnedFieldsStorage(prefs),
      );

      const keylessIncoming = _keylessChannel;
      await service.restore(
        BackupContents(channels: [keylessIncoming]),
        ImportMode.replace,
      );

      final restored = channelStorage.loadChannels().single;
      expect(restored.apiKey, _channel.apiKey);
      expect(restored.authError, isFalse);
    });

    test('ImportMode.replace sets authError when there is no existing key '
        'to preserve', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      final service = BackupService(
        channelStorage,
        SettingsStorage(prefs),
        FieldSettingsStorage(prefs),
        PinnedFieldsStorage(prefs),
      );

      const keylessIncoming = _keylessChannel;
      await service.restore(
        BackupContents(channels: [keylessIncoming]),
        ImportMode.replace,
      );

      final restored = channelStorage.loadChannels().single;
      expect(restored.apiKey, isNull);
      expect(restored.authError, isTrue);
    });

    test('ImportMode.addChannels sets authError on a new keyless private '
        'channel', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      final service = BackupService(
        channelStorage,
        SettingsStorage(prefs),
        FieldSettingsStorage(prefs),
        PinnedFieldsStorage(prefs),
      );

      const keylessIncoming = _keylessChannel;
      await service.restore(
        BackupContents(channels: [keylessIncoming]),
        ImportMode.addChannels,
      );

      final restored = channelStorage.loadChannels().single;
      expect(restored.apiKey, isNull);
      expect(restored.authError, isTrue);
    });

    test(
      'a keyless public channel is left as-is, never flagged authError',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        final service = BackupService(
          channelStorage,
          SettingsStorage(prefs),
          FieldSettingsStorage(prefs),
          PinnedFieldsStorage(prefs),
        );

        await service.restore(
          BackupContents(channels: [_otherChannel]),
          ImportMode.replace,
        );

        final restored = channelStorage.loadChannels().single;
        expect(restored.authError, isFalse);
      },
    );
  });
}
