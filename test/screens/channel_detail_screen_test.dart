import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/channel_status.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/screens/channel_detail/channel_detail_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/channel_snapshot_storage.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

import 'channel_detail_notifier_test.mocks.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

final _fields = [
  Field(
    id: 1,
    label: 'Temp',
    values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
  ),
];

final _twoFields = [
  Field(
    id: 1,
    label: 'Temp',
    values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
  ),
  Field(
    id: 2,
    label: 'Humidity',
    values: [FieldValue(createdAt: DateTime(2024), value: 61.2)],
  ),
];

const _emptyFields = [Field(id: 1, label: 'Temp')];

final _manyFields = List.generate(
  20,
  (i) => Field(
    id: i + 1,
    label: 'Field ${i + 1}',
    values: [FieldValue(createdAt: DateTime(2024), value: i.toDouble())],
  ),
);

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

// Mirrors ChannelListScreen's wide (tablet) layout: a fixed-width left
// panel, the detail screen filling the rest, and a FAB that floats over
// the whole Scaffold, i.e. over the detail panel's trailing edge.
Widget _wrapWideWithFab(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    floatingActionButton: FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    ),
    body: Row(
      children: [
        const SizedBox(width: 320),
        Expanded(child: child),
      ],
    ),
  ),
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

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockThingSpeakApi();
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: _fields, statuses: []));
  });

  testWidgets('renders the description above the field list', (tester) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      description: 'A description of the channel',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(SelectableText, 'A description of the channel'),
      findsOneWidget,
    );
    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('renders nothing extra when description is null', (tester) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('renders nothing extra when description is whitespace only', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      description: '   ',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsNothing);
    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('shows the description above the no-fields message when empty', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      description: 'A description of the channel',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: _emptyFields, statuses: []));
    when(mockApi.readLastFieldEntry(any, any)).thenAnswer((_) async => null);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A description of the channel'), findsOneWidget);
    expect(find.text('No fields found for this channel.'), findsOneWidget);
  });

  testWidgets(
    'shows only the no-fields message when empty and no description',
    (tester) async {
      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        fieldCount: 1,
      );
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: _emptyFields, statuses: []));
      when(mockApi.readLastFieldEntry(any, any)).thenAnswer((_) async => null);

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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No fields found for this channel.'), findsOneWidget);
    },
  );

  testWidgets('shows both link buttons when url and githubUrl are set', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      url: 'https://dweet.io',
      githubUrl: 'https://github.com/example/thingviewer-tree',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
  });

  testWidgets('shows only the Website button when githubUrl is null', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      url: 'https://dweet.io',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Website'), findsOneWidget);
    expect(find.text('Source code'), findsNothing);
  });

  testWidgets(
    'shows no buttons when there are no links, description unaffected',
    (tester) async {
      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        description: 'A description of the channel',
        fieldCount: 1,
      );
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A description of the channel'), findsOneWidget);
      expect(find.text('Website'), findsNothing);
      expect(find.text('Source code'), findsNothing);
    },
  );

  testWidgets(
    'shows the header when links are present but description is null',
    (tester) async {
      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        url: 'https://dweet.io',
        fieldCount: 1,
      );
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Website'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    },
  );

  testWidgets('rejects a javascript: scheme url, no button rendered', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      url: 'javascript:alert(1)',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Website'), findsNothing);
    expect(find.text('Source code'), findsNothing);
  });

  testWidgets('pull-to-refresh on the field list re-fetches the channel', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    verify(mockApi.readChannel(any)).called(2);
  });

  testWidgets(
    'field list stays on screen while a pull-to-refresh is in flight',
    (tester) async {
      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        fieldCount: 1,
      );
      var callCount = 0;
      when(mockApi.readChannel(any)).thenAnswer((_) async {
        callCount++;
        if (callCount > 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
        return enrichedChannel;
      });

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
        ),
      );
      await tester.pumpAndSettle();

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Temp'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();
    },
  );

  testWidgets('pulling to refresh on the error state recovers to loaded', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      fieldCount: 1,
    );
    var callCount = 0;
    when(mockApi.readChannel(any)).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) {
        throw const ApiException(ApiErrorCode.network);
      }
      return enrichedChannel;
    });

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
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Network error. Please check your connection.'),
      findsOneWidget,
    );

    await tester.fling(
      find.byType(SingleChildScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Temp'), findsOneWidget);
  });

  testWidgets('shows the newest status message and opens the log on tap', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      fieldCount: 1,
    );
    final statuses = [
      ChannelStatus(createdAt: DateTime(2024, 1, 1), message: 'older status'),
      ChannelStatus(
        createdAt: DateTime(2024, 1, 2),
        message: 'BU_10:06:39: 1s 3524L (125ms) 0err recal.required',
      ),
    ];
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: _fields, statuses: statuses));

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
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('BU_10:06:39: 1s 3524L (125ms) 0err recal.required'),
      findsOneWidget,
    );
    expect(find.text('older status'), findsNothing);
    expect(find.text('Status'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Status log'), findsOneWidget);
    expect(find.text('older status'), findsOneWidget);
    expect(
      find.text('BU_10:06:39: 1s 3524L (125ms) 0err recal.required'),
      findsOneWidget,
    );
  });

  testWidgets('shows no status section when the channel has no statuses', (
    tester,
  ) async {
    final enrichedChannel = _channel.copyWith(
      name: 'My Channel',
      fieldCount: 1,
    );
    when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets(
    'the last field clears the FAB when embedded in the wide split layout',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        fieldCount: _manyFields.length,
      );
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: _manyFields, statuses: []));

      await tester.pumpWidget(
        _wrapWideWithFab(
          ChannelDetailScreen(
            channel: _channel,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: await _pinnedFieldsStorage(),
            channelSnapshotStorage: await _channelSnapshotStorage(),
            fabClearance: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lastTile = find.widgetWithText(ListTile, 'Field 20');
      await tester.dragUntilVisible(
        lastTile,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      final tileRect = tester.getRect(lastTile);
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      expect(
        tileRect.overlaps(fabRect),
        isFalse,
        reason: 'last field row must not sit under the FAB',
      );
    },
  );

  group('pinned-first ordering', () {
    testWidgets(
      'a pinned field renders under Pinned fields, not Other fields',
      (tester) async {
        final enrichedChannel = _channel.copyWith(
          name: 'My Channel',
          fieldCount: 2,
        );
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: _twoFields, statuses: []));
        final prefs = await SharedPreferences.getInstance();
        final pinnedFieldsStorage = PinnedFieldsStorage(prefs);
        await pinnedFieldsStorage.toggle(_channel, 1);

        await tester.pumpWidget(
          _wrap(
            ChannelDetailScreen(
              channel: _channel,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: pinnedFieldsStorage,
              channelSnapshotStorage: await _channelSnapshotStorage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pinned fields'), findsOneWidget);
        expect(find.text('Other fields'), findsOneWidget);
        expect(find.text('Temp'), findsOneWidget);
        expect(find.text('Humidity'), findsOneWidget);

        final pinnedHeaderY = tester.getTopLeft(find.text('Pinned fields')).dy;
        final otherHeaderY = tester.getTopLeft(find.text('Other fields')).dy;
        final tempY = tester.getTopLeft(find.text('Temp')).dy;
        final humidityY = tester.getTopLeft(find.text('Humidity')).dy;

        expect(pinnedHeaderY, lessThan(tempY));
        expect(tempY, lessThan(otherHeaderY));
        expect(otherHeaderY, lessThan(humidityY));
      },
    );

    testWidgets('no pins renders a single Fields header', (tester) async {
      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        description: 'A description of the channel',
        fieldCount: 1,
      );
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);

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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fields'), findsOneWidget);
      expect(find.text('Pinned fields'), findsNothing);
      expect(find.text('Other fields'), findsNothing);
    });

    testWidgets('every field pinned omits the Other fields header', (
      tester,
    ) async {
      final enrichedChannel = _channel.copyWith(
        name: 'My Channel',
        fieldCount: 2,
      );
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: _twoFields, statuses: []));
      final prefs = await SharedPreferences.getInstance();
      final pinnedFieldsStorage = PinnedFieldsStorage(prefs);
      await pinnedFieldsStorage.toggle(_channel, 1);
      await pinnedFieldsStorage.toggle(_channel, 2);

      await tester.pumpWidget(
        _wrap(
          ChannelDetailScreen(
            channel: _channel,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
            pinnedFieldsStorage: pinnedFieldsStorage,
            channelSnapshotStorage: await _channelSnapshotStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinned fields'), findsOneWidget);
      expect(find.text('Other fields'), findsNothing);
      expect(find.text('Temp'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
    });

    testWidgets(
      'pinning a field from the chart screen moves it into the pinned '
      'section on return',
      (tester) async {
        final enrichedChannel = _channel.copyWith(
          name: 'My Channel',
          description: 'A description of the channel',
          fieldCount: 2,
        );
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: _twoFields, statuses: []));
        when(
          mockApi.readFieldRange(
            any,
            any,
            apiKey: anyNamed('apiKey'),
            start: anyNamed('start'),
            end: anyNamed('end'),
          ),
        ).thenAnswer(
          (_) async => FieldRange(field: _twoFields.first, truncated: false),
        );

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
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Fields'), findsOneWidget);

        await tester.tap(find.widgetWithText(ListTile, 'Temp'));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.push_pin_outlined));
        await tester.pumpAndSettle();

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('Pinned fields'), findsOneWidget);
        expect(find.text('Other fields'), findsOneWidget);

        final pinnedHeaderY = tester.getTopLeft(find.text('Pinned fields')).dy;
        final tempY = tester.getTopLeft(find.text('Temp')).dy;
        final otherHeaderY = tester.getTopLeft(find.text('Other fields')).dy;
        final humidityY = tester.getTopLeft(find.text('Humidity')).dy;

        expect(pinnedHeaderY, lessThan(tempY));
        expect(tempY, lessThan(otherHeaderY));
        expect(otherHeaderY, lessThan(humidityY));
      },
    );

    testWidgets(
      'no overflow at 2x text scale with a long label and 7-digit value',
      (tester) async {
        final enrichedChannel = _channel.copyWith(
          name: 'My Channel',
          fieldCount: 1,
        );
        final longLabelField = [
          Field(
            id: 1,
            label:
                'A very long field label that could wrap onto several '
                'lines at large text scales',
            values: [FieldValue(createdAt: DateTime(2024), value: 1234.567)],
          ),
        ];
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(mockApi.readFeed(any, any)).thenAnswer(
          (_) async => FeedData(fields: longLabelField, statuses: []),
        );

        await tester.pumpWidget(
          _wrapScaled(
            ChannelDetailScreen(
              channel: _channel,
              api: mockApi,
              settings: await _settings(),
              fieldSettingsStorage: await _fieldSettingsStorage(),
              pinnedFieldsStorage: await _pinnedFieldsStorage(),
              channelSnapshotStorage: await _channelSnapshotStorage(),
            ),
            2,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('1234.567'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
