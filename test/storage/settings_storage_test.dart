import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/storage/settings_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('exportJson / importJson', () {
    test('round trips every field', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage(await SharedPreferences.getInstance());
      await storage.saveThemeMode(ThemeMode.dark);
      await storage.saveDateFormat('yyyy-MM-dd');
      await storage.saveTimeFormat('HH:mm:ss');
      await storage.saveTimezoneDisplay(TimezoneDisplay.name);
      await storage.saveEntryTimeDisplay(EntryTimeDisplay.age);
      await storage.saveStartChannel(_channel);

      final exported = storage.exportJson();

      SharedPreferences.setMockInitialValues({});
      final target = SettingsStorage(await SharedPreferences.getInstance());
      await target.importJson(exported);

      expect(target.themeMode, ThemeMode.dark);
      expect(target.dateFormat, 'yyyy-MM-dd');
      expect(target.timeFormat, 'HH:mm:ss');
      expect(target.timezoneDisplay, TimezoneDisplay.name);
      expect(target.entryTimeDisplay, EntryTimeDisplay.age);
      expect(target.startChannelId, _channel.id);
      expect(target.startChannelServerUrl, _channel.serverUrl);
    });

    test('omits startChannel keys when unset', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage(await SharedPreferences.getInstance());

      final exported = storage.exportJson();

      expect(exported.containsKey('startChannelId'), isFalse);
      expect(exported.containsKey('startChannelServerUrl'), isFalse);
    });

    test('clamps an out-of-range themeMode instead of crashing', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage(await SharedPreferences.getInstance());

      await storage.importJson({'themeMode': 99});

      expect(storage.themeMode, ThemeMode.values[2]);
    });

    test(
      'clamps an out-of-range timezoneDisplay instead of crashing',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = SettingsStorage(await SharedPreferences.getInstance());

        await storage.importJson({'timezoneDisplay': -5});

        expect(storage.timezoneDisplay, TimezoneDisplay.values[0]);
      },
    );

    test(
      'clamps an out-of-range entryTimeDisplay instead of crashing',
      () async {
        SharedPreferences.setMockInitialValues({});
        final storage = SettingsStorage(await SharedPreferences.getInstance());

        await storage.importJson({'entryTimeDisplay': 99});

        expect(
          storage.entryTimeDisplay,
          EntryTimeDisplay.values[EntryTimeDisplay.values.length - 1],
        );
      },
    );

    test('skips wrong-typed values without throwing', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage(await SharedPreferences.getInstance());

      await storage.importJson({
        'themeMode': 'not an int',
        'dateFormat': 42,
        'startChannelId': 'not an int',
      });

      expect(storage.themeMode, ThemeMode.system);
      expect(storage.dateFormat, defaultDateFormat);
      expect(storage.startChannelId, isNull);
    });

    test('leaves existing values alone when keys are absent', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SettingsStorage(await SharedPreferences.getInstance());
      await storage.saveThemeMode(ThemeMode.dark);

      await storage.importJson({'dateFormat': 'yyyy-MM-dd'});

      expect(storage.themeMode, ThemeMode.dark);
      expect(storage.dateFormat, 'yyyy-MM-dd');
    });
  });
}
