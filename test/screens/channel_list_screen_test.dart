import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/screens/channel_list/channel_list_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/channel_snapshot_storage.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

import 'channel_detail_notifier_test.mocks.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

const _otherChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Other Channel',
);

const _authErrorChannel = Channel(
  id: 3,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: false,
  apiKey: 'bad-key',
  name: 'Broken Channel',
  authError: true,
);

final _fields = [
  Field(
    id: 1,
    label: 'Temp',
    values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
  ),
];

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Widget _wrapScaled(Widget child, double scale) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: child,
);

Future<SettingsNotifier> _settings() async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsNotifier(SettingsStorage(prefs));
}

Future<FieldSettingsStorage> _fieldSettingsStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return FieldSettingsStorage(prefs);
}

Future<PinnedFieldsStorage> _pinnedFieldsStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return PinnedFieldsStorage(prefs);
}

Future<ChannelSnapshotStorage> _channelSnapshotStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return ChannelSnapshotStorage(prefs);
}

Future<BackupService> _backupService() async {
  final prefs = await SharedPreferences.getInstance();
  return BackupService(
    ChannelStorage(prefs),
    SettingsStorage(prefs),
    FieldSettingsStorage(prefs),
    PinnedFieldsStorage(prefs),
  );
}

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    mockApi = MockThingSpeakApi();
  });

  testWidgets('shows empty-state message with no saved channels', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrap(
        ChannelListScreen(
          api: mockApi,
          channelStorage: storage,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
          channelSnapshotStorage: await _channelSnapshotStorage(),
          backupService: await _backupService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved channels. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('renders a tile for each saved channel', (tester) async {
    SharedPreferences.setMockInitialValues({
      'channels': Channel.listToJson([_channel]),
    });
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrap(
        ChannelListScreen(
          api: mockApi,
          channelStorage: storage,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
          channelSnapshotStorage: await _channelSnapshotStorage(),
          backupService: await _backupService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Channel'), findsOneWidget);
  });

  testWidgets('cancelling the swipe-to-dismiss dialog keeps the channel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'channels': Channel.listToJson([_channel]),
    });
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrap(
        ChannelListScreen(
          api: mockApi,
          channelStorage: storage,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
          channelSnapshotStorage: await _channelSnapshotStorage(),
          backupService: await _backupService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('My Channel'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Remove channel?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('My Channel'), findsOneWidget);
  });

  group('start channel', () {
    setUp(() {
      when(mockApi.readChannel(any)).thenAnswer((_) async => _channel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: _fields, statuses: []));
    });

    testWidgets(
      'set to a saved channel opens its detail screen, Back returns to the list',
      (tester) async {
        // Narrow (phone) layout: the default 800x600 test surface is wide
        // enough to trigger the tablet split view instead.
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({
          'channels': Channel.listToJson([_channel, _otherChannel]),
          'startChannelId': _channel.id,
          'startChannelServerUrl': _channel.serverUrl,
        });
        final storage = ChannelStorage(await SharedPreferences.getInstance());

        await tester.pumpWidget(
          _wrap(
            ChannelListScreen(
              api: mockApi,
              channelStorage: storage,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelSnapshotStorage: await _channelSnapshotStorage(),
              backupService: await _backupService(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Temp'), findsOneWidget);

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('My Channel'), findsOneWidget);
        expect(find.text('Other Channel'), findsOneWidget);
      },
    );

    testWidgets('unset shows the channel list', (tester) async {
      SharedPreferences.setMockInitialValues({
        'channels': Channel.listToJson([_channel, _otherChannel]),
      });
      final storage = ChannelStorage(await SharedPreferences.getInstance());

      await tester.pumpWidget(
        _wrap(
          ChannelListScreen(
            api: mockApi,
            channelStorage: storage,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
            channelSnapshotStorage: await _channelSnapshotStorage(),
            backupService: await _backupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Channel'), findsOneWidget);
      expect(find.text('Other Channel'), findsOneWidget);
    });

    testWidgets('a stale (deleted) channel identity falls back to the list', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'channels': Channel.listToJson([_otherChannel]),
        'startChannelId': _channel.id,
        'startChannelServerUrl': _channel.serverUrl,
      });
      final storage = ChannelStorage(await SharedPreferences.getInstance());

      await tester.pumpWidget(
        _wrap(
          ChannelListScreen(
            api: mockApi,
            channelStorage: storage,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
            channelSnapshotStorage: await _channelSnapshotStorage(),
            backupService: await _backupService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Other Channel'), findsOneWidget);
    });
  });

  testWidgets('the auth-error subtitle does not overflow at 2x text scale', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'channels': Channel.listToJson([_authErrorChannel]),
    });
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(
      _wrapScaled(
        ChannelListScreen(
          api: mockApi,
          channelStorage: storage,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
          pinnedFieldsStorage: await _pinnedFieldsStorage(),
          channelSnapshotStorage: await _channelSnapshotStorage(),
          backupService: await _backupService(),
        ),
        2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Broken Channel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
