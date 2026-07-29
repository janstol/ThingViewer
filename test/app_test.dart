import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/app.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/channel_detail/channel_detail_screen.dart';
import 'package:thingviewer/screens/channel_list/channel_list_screen.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';

import 'screens/channel_detail_notifier_test.mocks.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

Future<App> _buildApp() async {
  final prefs = await SharedPreferences.getInstance();
  final channelStorage = ChannelStorage(prefs);
  final settingsStorage = SettingsStorage(prefs);
  final fieldSettingsStorage = FieldSettingsStorage(prefs);
  return App(
    api: MockThingSpeakApi(),
    channelStorage: channelStorage,
    settingsStorage: settingsStorage,
    fieldSettingsStorage: fieldSettingsStorage,
    backupService: BackupService(
      channelStorage,
      settingsStorage,
      fieldSettingsStorage,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders with working localisation and an empty channel list', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    expect(find.text('No saved channels. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('MaterialApp.themeMode follows the settings dialog choice', (
    tester,
  ) async {
    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets(
    'a configured start channel opens straight into its detail screen on '
    'a narrow layout',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final prefs = await SharedPreferences.getInstance();
      await ChannelStorage(prefs).saveChannels([_channel]);
      await SettingsStorage(prefs).saveStartChannel(_channel);

      final mockApi = MockThingSpeakApi();
      when(mockApi.readChannel(any)).thenAnswer((_) async => _channel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => const FeedData(fields: [], statuses: []));

      final channelStorage = ChannelStorage(prefs);
      final settingsStorage = SettingsStorage(prefs);
      final fieldSettingsStorage = FieldSettingsStorage(prefs);
      await tester.pumpWidget(
        App(
          api: mockApi,
          channelStorage: channelStorage,
          settingsStorage: settingsStorage,
          fieldSettingsStorage: fieldSettingsStorage,
          backupService: BackupService(
            channelStorage,
            settingsStorage,
            fieldSettingsStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChannelDetailScreen), findsOneWidget);
      expect(find.byType(ChannelListScreen), findsNothing);
    },
  );

  testWidgets('with no start channel configured, a narrow layout stays on '
      'the channel list', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    await ChannelStorage(prefs).saveChannels([_channel]);

    await tester.pumpWidget(await _buildApp());
    await tester.pumpAndSettle();

    expect(find.byType(ChannelDetailScreen), findsNothing);
    expect(find.text('My Channel'), findsOneWidget);
  });
}
