import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/backup/import_plan.dart';
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

/// A selection that imports nothing at all — tests build on top of this with
/// the specific fields they want selected.
const _nothing = ImportSelection(
  channels: {},
  fieldChartSettingsKeys: {},
  pinnedFields: {},
  settingKeys: {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('export → parse → planImport/applyImport round trip', () {
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
        final plan = freshService.planImport(contents);
        await freshService.applyImport(
          contents,
          ImportSelection(
            channels: plan.channels.map((d) => d.incoming).toSet(),
            fieldChartSettingsKeys: {
              for (final d in plan.channels) ...d.chartSettingKeys,
            },
            pinnedFields: {
              for (final d in plan.channels) ...d.pinnedFields,
            },
            settingKeys: BackupSettingKey.values.toSet(),
          ),
        );

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

  group('BackupService.planImport channel classification', () {
    test('a channel with no saved match is added', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _service();
      final contents = BackupContents(channels: [_otherChannel]);

      final plan = service.planImport(contents);

      expect(plan.channels.single.change, ChannelChange.added);
      expect(plan.channels.single.existing, isNull);
    });

    test('a channel identical to the saved one is unchanged', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChannelStorage(prefs).saveChannels([_channel]);
      final service = await _service();
      final contents = BackupContents(channels: [_channel]);

      final plan = service.planImport(contents);

      expect(plan.channels.single.change, ChannelChange.unchanged);
      expect(plan.channels.single.changes, isEmpty);
    });

    test('a channel with a different name is updated, with name flagged',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChannelStorage(prefs).saveChannels([_channel]);
      final service = await _service();
      final renamed = _channel.copyWith(name: 'Renamed');
      final contents = BackupContents(channels: [renamed]);

      final plan = service.planImport(contents);

      expect(plan.channels.single.change, ChannelChange.updated);
      expect(plan.channels.single.changes, {ChannelFieldChange.name});
    });

    test('a keyless private channel with no saved match needs an API key',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _service();
      final contents = BackupContents(channels: [_keylessChannel]);

      final plan = service.planImport(contents);

      expect(plan.channels.single.needsApiKey, isTrue);
    });

    test(
      'a keyless private channel with an existing saved key does not need one',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await ChannelStorage(prefs).saveChannels([_channel]);
        final service = await _service();
        final contents = BackupContents(channels: [_keylessChannel]);

        final plan = service.planImport(contents);

        expect(plan.channels.single.needsApiKey, isFalse);
        expect(plan.channels.single.change, ChannelChange.unchanged);
      },
    );

    test('a saved channel absent from the file is listed as onlyOnDevice',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await ChannelStorage(prefs).saveChannels([_channel, _otherChannel]);
      final service = await _service();
      final contents = BackupContents(channels: [_otherChannel]);

      final plan = service.planImport(contents);

      expect(plan.onlyOnDevice, [_channel]);
    });

    test('chart overrides and pins are grouped per channel, by prefix/match',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _service();
      final contents = BackupContents(
        channels: [_channel, _otherChannel],
        fieldChartSettings: {
          '${_channel.serverUrl}|${_channel.id}|1': {'type': 'line'},
          'https://elsewhere.example|999|1': {'type': 'line'},
        },
        pinnedFields: [
          PinnedField(
            serverUrl: _channel.serverUrl,
            channelId: _channel.id,
            fieldId: 2,
          ).toJson(),
          const PinnedField(
            serverUrl: 'https://elsewhere.example',
            channelId: 999,
            fieldId: 1,
          ).toJson(),
        ],
      );

      final plan = service.planImport(contents);

      final diff = plan.channels.firstWhere(
        (d) => d.incoming == _channel,
      );
      expect(diff.chartSettingKeys, [
        '${_channel.serverUrl}|${_channel.id}|1',
      ]);
      expect(diff.pinnedFields, hasLength(1));
      expect(plan.orphanChartSettingKeys, [
        'https://elsewhere.example|999|1',
      ]);
      expect(plan.orphanPinnedFields, hasLength(1));
    });
  });

  group('BackupService.planImport settings', () {
    test('is empty when the file has no settings section', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _service();

      final plan = service.planImport(const BackupContents());

      expect(plan.settings, isEmpty);
    });

    test('flags a changed key and leaves an absent key as unchanged',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await SettingsStorage(prefs).saveThemeMode(ThemeMode.light);
      final service = await _service();
      final contents = BackupContents(
        settings: {'themeMode': ThemeMode.dark.index},
      );

      final plan = service.planImport(contents);

      final themeDiff = plan.settings.firstWhere(
        (d) => d.key == BackupSettingKey.themeMode,
      );
      expect(themeDiff.changed, isTrue);
      final dateDiff = plan.settings.firstWhere(
        (d) => d.key == BackupSettingKey.dateFormat,
      );
      expect(dateDiff.changed, isFalse);
    });
  });

  group('BackupService.applyImport channels', () {
    test('a selected channel replaces the matching saved entry', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_channel]);
      final service = await _service();
      final renamed = _channel.copyWith(name: 'Renamed');
      final contents = BackupContents(channels: [renamed]);

      await service.applyImport(
        contents,
        ImportSelection(
          channels: {renamed},
          fieldChartSettingsKeys: const {},
          pinnedFields: const {},
          settingKeys: const {},
        ),
      );

      expect(channelStorage.loadChannels().single.name, 'Renamed');
    });

    test('an unselected channel is left untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_channel]);
      final service = await _service();
      final renamed = _channel.copyWith(name: 'Renamed');
      final contents = BackupContents(channels: [renamed]);

      await service.applyImport(contents, _nothing);

      expect(channelStorage.loadChannels().single.name, _channel.name);
    });

    test('a selected new channel is appended', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_channel]);
      final service = await _service();
      final contents = BackupContents(channels: [_otherChannel]);

      await service.applyImport(
        contents,
        ImportSelection(
          channels: {_otherChannel},
          fieldChartSettingsKeys: const {},
          pinnedFields: const {},
          settingKeys: const {},
        ),
      );

      expect(channelStorage.loadChannels(), [_channel, _otherChannel]);
    });

    test('removeChannelsNotInBackup drops only channels absent from the file',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final channelStorage = ChannelStorage(prefs);
      await channelStorage.saveChannels([_channel, _otherChannel]);
      final service = await _service();
      final contents = BackupContents(channels: [_otherChannel]);

      await service.applyImport(
        contents,
        const ImportSelection(
          channels: {},
          fieldChartSettingsKeys: {},
          pinnedFields: {},
          settingKeys: {},
          removeChannelsNotInBackup: true,
        ),
      );

      expect(channelStorage.loadChannels(), [_otherChannel]);
    });

    test(
      'a selected keyless private channel keeps the existing saved key',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        await channelStorage.saveChannels([_channel]);
        final service = await _service();
        final contents = BackupContents(channels: [_keylessChannel]);

        await service.applyImport(
          contents,
          ImportSelection(
            channels: {_keylessChannel},
            fieldChartSettingsKeys: const {},
            pinnedFields: const {},
            settingKeys: const {},
          ),
        );

        final restored = channelStorage.loadChannels().single;
        expect(restored.apiKey, _channel.apiKey);
        expect(restored.authError, isFalse);
      },
    );

    test(
      'a selected keyless private channel with no saved key gets authError',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = await _service();
        final prefs = await SharedPreferences.getInstance();
        final channelStorage = ChannelStorage(prefs);
        final contents = BackupContents(channels: [_keylessChannel]);

        await service.applyImport(
          contents,
          ImportSelection(
            channels: {_keylessChannel},
            fieldChartSettingsKeys: const {},
            pinnedFields: const {},
            settingKeys: const {},
          ),
        );

        final restored = channelStorage.loadChannels().single;
        expect(restored.apiKey, isNull);
        expect(restored.authError, isTrue);
      },
    );

    test('a keyless public channel is left as-is, never flagged authError',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = await _service();
      final contents = BackupContents(channels: [_otherChannel]);

      await service.applyImport(
        contents,
        ImportSelection(
          channels: {_otherChannel},
          fieldChartSettingsKeys: const {},
          pinnedFields: const {},
          settingKeys: const {},
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final restored = ChannelStorage(prefs).loadChannels().single;
      expect(restored.authError, isFalse);
    });
  });

  group('BackupService.applyImport settings', () {
    test('an unselected settings key is not written', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsStorage = SettingsStorage(prefs);
      await settingsStorage.saveThemeMode(ThemeMode.light);
      final service = await _service();
      final contents = BackupContents(
        settings: {'themeMode': ThemeMode.dark.index},
      );

      await service.applyImport(contents, _nothing);

      expect(settingsStorage.themeMode, ThemeMode.light);
    });

    test('a selected settings key is written', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settingsStorage = SettingsStorage(prefs);
      await settingsStorage.saveThemeMode(ThemeMode.light);
      final service = await _service();
      final contents = BackupContents(
        settings: {'themeMode': ThemeMode.dark.index},
      );

      await service.applyImport(
        contents,
        const ImportSelection(
          channels: {},
          fieldChartSettingsKeys: {},
          pinnedFields: {},
          settingKeys: {BackupSettingKey.themeMode},
        ),
      );

      expect(settingsStorage.themeMode, ThemeMode.dark);
    });
  });

  group('BackupService.applyImport chart overrides and pinned fields', () {
    test('merge keeps existing entries not in the selection', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fieldSettingsStorage = FieldSettingsStorage(prefs);
      final pinnedFieldsStorage = PinnedFieldsStorage(prefs);
      const existingSettings = FieldChartSettings(type: ChartType.step);
      await fieldSettingsStorage.save(_channel, 1, existingSettings);
      await pinnedFieldsStorage.toggle(_channel, 1);

      final service = await _service();
      final key = '${_otherChannel.serverUrl}|${_otherChannel.id}|2';
      final newPin = PinnedField(
        serverUrl: _otherChannel.serverUrl,
        channelId: _otherChannel.id,
        fieldId: 2,
      );
      final contents = BackupContents(
        fieldChartSettings: {
          key: const FieldChartSettings(type: ChartType.column).toJson(),
        },
        pinnedFields: [newPin.toJson()],
      );

      await service.applyImport(
        contents,
        ImportSelection(
          channels: const {},
          fieldChartSettingsKeys: {key},
          pinnedFields: {newPin},
          settingKeys: const {},
        ),
      );

      expect(
        FieldSettingsStorage(prefs).settingsFor(_channel, 1),
        existingSettings,
      );
      expect(PinnedFieldsStorage(prefs).isPinned(_channel, 1), isTrue);
      expect(PinnedFieldsStorage(prefs).isPinned(_otherChannel, 2), isTrue);
    });

    test('an unselected chart override key is not merged in', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = await _service();
      final key = '${_channel.serverUrl}|${_channel.id}|1';
      final contents = BackupContents(
        fieldChartSettings: {
          key: const FieldChartSettings(type: ChartType.column).toJson(),
        },
      );

      await service.applyImport(contents, _nothing);

      expect(
        FieldSettingsStorage(prefs).settingsFor(_channel, 1),
        FieldChartSettings.defaults,
      );
    });
  });
}
