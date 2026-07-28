import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/screens/channel_detail/channel_detail_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
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

const _emptyFields = [Field(id: 1, label: 'Temp')];

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
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

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockApi = MockThingSpeakApi();
    when(mockApi.readFeed(any, any)).thenAnswer((_) async => _fields);
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
    when(mockApi.readFeed(any, any)).thenAnswer((_) async => _emptyFields);

    await tester.pumpWidget(
      _wrap(
        ChannelDetailScreen(
          channel: _channel,
          api: mockApi,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
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
      when(mockApi.readFeed(any, any)).thenAnswer((_) async => _emptyFields);

      await tester.pumpWidget(
        _wrap(
          ChannelDetailScreen(
            channel: _channel,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
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
}
