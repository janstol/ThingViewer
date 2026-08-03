import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/backup/backup_service.dart';
import 'package:thingviewer/backup/import_plan.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/channel_snapshot.dart';
import 'package:thingviewer/models/channel_status.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/models/pinned_field.dart';
import 'package:thingviewer/screens/channel_add/channel_add_screen.dart';
import 'package:thingviewer/screens/channel_detail/channel_detail_screen.dart';
import 'package:thingviewer/screens/channel_list/channel_list_screen.dart';
import 'package:thingviewer/screens/channel_status/channel_status_screen.dart';
import 'package:thingviewer/screens/field_chart/field_chart_screen.dart';
import 'package:thingviewer/screens/field_settings/field_settings_screen.dart';
import 'package:thingviewer/screens/import_preview/import_preview_screen.dart';
import 'package:thingviewer/screens/pinned_edit/pinned_edit_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/screens/settings/settings_screen.dart';
import 'package:thingviewer/storage/channel_snapshot_storage.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

import 'screens/channel_detail_notifier_test.mocks.dart';

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

final _now = DateTime.now();

final _fields = [
  Field(
    id: 1,
    label: 'Temp',
    values: [
      FieldValue(
        createdAt: _now.subtract(const Duration(days: 1)),
        value: 23.5,
      ),
      FieldValue(createdAt: _now, value: 24.1),
    ],
  ),
];

final _statuses = [ChannelStatus(createdAt: _now, message: 'All good')];

Widget _wrap(Widget child, ThemeMode themeMode) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  themeMode: themeMode,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<SettingsNotifier> _settings() async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsNotifier(SettingsStorage(prefs));
}

Future<ChannelStorage> _channelStorage() async {
  final prefs = await SharedPreferences.getInstance();
  return ChannelStorage(prefs);
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

ImportPlan _importPlan() {
  const updated = Channel(
    id: 1,
    serverUrl: 'https://api.thingspeak.com',
    isPublic: true,
    name: 'My Channel Renamed',
  );
  const needsKey = Channel(
    id: 3,
    serverUrl: 'https://api.thingspeak.com',
    isPublic: false,
    name: 'Private Channel',
  );
  const pin = PinnedField(
    serverUrl: 'https://api.thingspeak.com',
    channelId: 1,
    fieldId: 1,
  );
  return ImportPlan(
    contents: BackupContents(
      channels: [updated, needsKey],
      exportedAt: _now,
      appVersion: '0.9.0',
    ),
    channels: [
      ChannelDiff(
        incoming: updated,
        existing: _channel,
        change: ChannelChange.updated,
        changes: const {ChannelFieldChange.name},
        needsApiKey: false,
        chartSettingKeys: const ['https://api.thingspeak.com|1|1'],
        pinnedFields: const [pin],
      ),
      const ChannelDiff(
        incoming: needsKey,
        existing: null,
        change: ChannelChange.added,
        changes: {},
        needsApiKey: true,
        chartSettingKeys: [],
        pinnedFields: [],
      ),
    ],
    settings: [
      SettingDiff(
        key: BackupSettingKey.themeMode,
        current: ThemeMode.light.index,
        incoming: ThemeMode.dark.index,
      ),
    ],
    orphanChartSettingKeys: const [],
    orphanPinnedFields: const [],
    onlyOnDevice: const [_otherChannel],
  );
}

Future<void> _checkA11y(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

void _setNarrowSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    mockApi = MockThingSpeakApi();
    when(mockApi.readChannel(any)).thenAnswer((_) async => _channel);
    when(
      mockApi.readFieldRange(
        any,
        any,
        apiKey: anyNamed('apiKey'),
        start: anyNamed('start'),
        end: anyNamed('end'),
      ),
    ).thenAnswer(
      (_) async => FieldRange(field: _fields.first, truncated: false),
    );
  });

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    group(themeMode.name, () {
      testWidgets('channel list - empty', (tester) async {
        _setNarrowSurface(tester);
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
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('channel list - populated', (tester) async {
        _setNarrowSurface(tester);
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
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('channel list - wide', (tester) async {
        _setWideSurface(tester);
        when(mockApi.readChannel(any)).thenAnswer((_) async => _channel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: _fields, statuses: []));
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
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('channel list - pins present', (tester) async {
        _setNarrowSurface(tester);
        when(mockApi.readChannel(any)).thenAnswer((_) async => _channel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: _fields, statuses: []));
        SharedPreferences.setMockInitialValues({
          'channels': Channel.listToJson([_channel, _otherChannel]),
        });
        final prefs = await SharedPreferences.getInstance();
        final storage = ChannelStorage(prefs);
        final pinnedFieldsStorage = PinnedFieldsStorage(prefs);
        await pinnedFieldsStorage.toggle(_channel, 1);

        await tester.pumpWidget(
          _wrap(
            ChannelListScreen(
              api: mockApi,
              channelStorage: storage,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: pinnedFieldsStorage,
              channelSnapshotStorage: await _channelSnapshotStorage(),
              backupService: await _backupService(),
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Temp'), findsOneWidget);

        await _checkA11y(tester);
      });

      testWidgets('channel detail', (tester) async {
        SharedPreferences.setMockInitialValues({});
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: _fields, statuses: []));

        await tester.pumpWidget(
          _wrap(
            ChannelDetailScreen(
              channel: _channel,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelSnapshotStorage: await _channelSnapshotStorage(),
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('channel detail - stale banner (refreshing)', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final pending = Completer<FeedData>();
        when(mockApi.readFeed(any, any)).thenAnswer((_) => pending.future);
        final prefs = await SharedPreferences.getInstance();
        final snapshotStorage = ChannelSnapshotStorage(prefs);
        await snapshotStorage.save(
          _channel,
          ChannelSnapshot(
            fields: [
              FieldSnapshot(
                id: 1,
                label: 'Temp',
                value: 23.5,
                valueAt: _now.subtract(const Duration(hours: 2)),
              ),
            ],
            fetchedAt: _now.subtract(const Duration(hours: 2)),
          ),
        );

        await tester.pumpWidget(
          _wrap(
            ChannelDetailScreen(
              channel: _channel,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelSnapshotStorage: snapshotStorage,
            ),
            themeMode,
          ),
        );
        await tester.pump();

        await _checkA11y(tester);

        pending.complete(FeedData(fields: _fields, statuses: []));
        await tester.pumpAndSettle();
      });

      testWidgets('channel detail - refresh failed banner', (tester) async {
        SharedPreferences.setMockInitialValues({});
        when(
          mockApi.readFeed(any, any),
        ).thenThrow(ApiException(ApiErrorCode.network));
        final prefs = await SharedPreferences.getInstance();
        final snapshotStorage = ChannelSnapshotStorage(prefs);
        await snapshotStorage.save(
          _channel,
          ChannelSnapshot(
            fields: [
              FieldSnapshot(
                id: 1,
                label: 'Temp',
                value: 23.5,
                valueAt: _now.subtract(const Duration(hours: 2)),
              ),
            ],
            fetchedAt: _now.subtract(const Duration(hours: 2)),
          ),
        );

        await tester.pumpWidget(
          _wrap(
            ChannelDetailScreen(
              channel: _channel,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelSnapshotStorage: snapshotStorage,
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('field chart', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _fields.first,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('field table', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            FieldChartScreen(
              channel: _channel,
              field: _fields.first,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.table_rows));
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('channel add', (tester) async {
        await tester.pumpWidget(
          _wrap(ChannelAddScreen(api: mockApi), themeMode),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('channel edit', (tester) async {
        await tester.pumpWidget(
          _wrap(
            ChannelAddScreen(api: mockApi, initialChannel: _channel),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('field settings', (tester) async {
        await tester.pumpWidget(
          _wrap(
            FieldSettingsScreen(
              channel: _channel,
              field: _fields.first,
              settings: FieldChartSettings.defaults,
              onChanged: (_) {},
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('pinned fields picker', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            PinnedEditScreen(
              api: mockApi,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channels: const [_channel, _otherChannel],
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('import preview', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            ImportPreviewScreen(
              plan: _importPlan(),
              fileName: 'thingviewer-backup-2026-08-01.json',
              settings: await _settings(),
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('settings', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            SettingsScreen(
              settings: await _settings(),
              channels: const [_channel, _otherChannel],
              api: mockApi,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelStorage: await _channelStorage(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              channelSnapshotStorage: await _channelSnapshotStorage(),
              backupService: await _backupService(),
              onImported: () {},
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('settings - about dialog', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            SettingsScreen(
              settings: await _settings(),
              channels: const [_channel, _otherChannel],
              api: mockApi,
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelStorage: await _channelStorage(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              channelSnapshotStorage: await _channelSnapshotStorage(),
              backupService: await _backupService(),
              onImported: () {},
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byType(AboutListTile),
          100,
          scrollable: find.byType(Scrollable),
        );
        await tester.tap(find.byType(AboutListTile));
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });

      testWidgets('status log', (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            ChannelStatusScreen(
              statuses: _statuses,
              settings: await _settings(),
            ),
            themeMode,
          ),
        );
        await tester.pumpAndSettle();

        await _checkA11y(tester);
      });
    });
  }
}
