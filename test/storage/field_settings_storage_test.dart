import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

const _otherChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settingsFor returns defaults when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FieldSettingsStorage(await SharedPreferences.getInstance());

    expect(storage.settingsFor(_channel, 1), FieldChartSettings.defaults);
  });

  test('save persists settings retrievable by the same key', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FieldSettingsStorage(await SharedPreferences.getInstance());
    const settings = FieldChartSettings(type: ChartType.step, showDelta: true);

    await storage.save(_channel, 1, settings);

    expect(storage.settingsFor(_channel, 1), settings);
  });

  test('settings are isolated per channel and field id', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FieldSettingsStorage(await SharedPreferences.getInstance());
    const forField1 = FieldChartSettings(type: ChartType.step);
    const forField2 = FieldChartSettings(type: ChartType.spline);

    await storage.save(_channel, 1, forField1);
    await storage.save(_channel, 2, forField2);
    await storage.save(_otherChannel, 1, FieldChartSettings.defaults.copyWith(decimals: 3));

    expect(storage.settingsFor(_channel, 1), forField1);
    expect(storage.settingsFor(_channel, 2), forField2);
    expect(storage.settingsFor(_otherChannel, 1).decimals, 3);
    expect(storage.settingsFor(_otherChannel, 2), FieldChartSettings.defaults);
  });

  test('saving default settings removes any existing entry', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = FieldSettingsStorage(await SharedPreferences.getInstance());
    await storage.save(_channel, 1, const FieldChartSettings(type: ChartType.step));

    await storage.save(_channel, 1, FieldChartSettings.defaults);

    expect(storage.settingsFor(_channel, 1), FieldChartSettings.defaults);
    // Re-load from the persisted blob to confirm the entry was actually removed,
    // not just shadowed in memory.
    final reloaded = FieldSettingsStorage(await SharedPreferences.getInstance());
    expect(reloaded.settingsFor(_channel, 1), FieldChartSettings.defaults);
  });

  test('a corrupt blob yields defaults instead of throwing', () async {
    SharedPreferences.setMockInitialValues({'fieldChartSettings': 'not json'});
    final storage = FieldSettingsStorage(await SharedPreferences.getInstance());

    expect(storage.settingsFor(_channel, 1), FieldChartSettings.defaults);
  });

  test('settings persist across storage instances', () async {
    SharedPreferences.setMockInitialValues({});
    final first = FieldSettingsStorage(await SharedPreferences.getInstance());
    const settings = FieldChartSettings(yMin: 0, yMax: 100);
    await first.save(_channel, 1, settings);

    final second = FieldSettingsStorage(await SharedPreferences.getInstance());

    expect(second.settingsFor(_channel, 1), settings);
  });
}
