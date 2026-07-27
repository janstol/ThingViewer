import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/channel_add/channel_add_screen.dart';

import 'channel_detail_notifier_test.mocks.dart';

const _existing = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Existing',
);

const _other = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Other',
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    mockApi = MockThingSpeakApi();
  });

  testWidgets('shows an error for an empty server URL', (tester) async {
    await tester.pumpWidget(_wrap(ChannelAddScreen(api: mockApi)));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Server URL'),
      '',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel ID'),
      '1',
    );
    await _tapSave(tester);

    expect(find.text('Enter a server URL'), findsOneWidget);
  });

  testWidgets('shows an error for an invalid server URL', (tester) async {
    await tester.pumpWidget(_wrap(ChannelAddScreen(api: mockApi)));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Server URL'),
      'not-a-url',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel ID'),
      '1',
    );
    await _tapSave(tester);

    expect(find.text('Enter a valid server URL'), findsOneWidget);
  });

  testWidgets('shows an error for an invalid channel ID', (tester) async {
    await tester.pumpWidget(_wrap(ChannelAddScreen(api: mockApi)));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Channel ID'),
      'abc',
    );
    await _tapSave(tester);

    expect(find.text('Enter a valid channel ID'), findsOneWidget);
  });

  testWidgets('shows the Read API Key label and helper for private channels', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(ChannelAddScreen(api: mockApi)));
    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();

    expect(find.text('Read API Key'), findsOneWidget);
    expect(
      find.text(
        "Required for private channels. Find it on the channel's API Keys tab on ThingSpeak.",
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a duplicate-channel error when the api returns an existing channel',
    (tester) async {
      when(mockApi.readChannel(any)).thenAnswer((_) async => _existing);

      await tester.pumpWidget(
        _wrap(
          ChannelAddScreen(api: mockApi, existingChannels: const [_existing]),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Channel ID'),
        '1',
      );
      await _tapSave(tester);

      expect(
        find.text('This channel is already in your list.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('prefills fields from initialChannel and titles as Edit', (
    tester,
  ) async {
    const initial = Channel(
      id: 42,
      serverUrl: 'https://example.com',
      isPublic: false,
      apiKey: 'secret-key',
      name: 'My Channel',
    );

    await tester.pumpWidget(
      _wrap(ChannelAddScreen(api: mockApi, initialChannel: initial)),
    );

    expect(find.text('Edit Channel'), findsOneWidget);
    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('secret-key'), findsOneWidget);
  });

  testWidgets('duplicate check exempts the channel being edited from itself', (
    tester,
  ) async {
    when(mockApi.readChannel(any)).thenAnswer((_) async => _existing);
    await tester.pumpWidget(
      _wrap(
        ChannelAddScreen(
          api: mockApi,
          existingChannels: const [_existing, _other],
          initialChannel: _existing,
        ),
      ),
    );
    await _tapSave(tester);

    expect(find.text('This channel is already in your list.'), findsNothing);
  });

  testWidgets(
    'duplicate check still trips when editing into a different saved channel',
    (tester) async {
      when(mockApi.readChannel(any)).thenAnswer((_) async => _other);
      await tester.pumpWidget(
        _wrap(
          ChannelAddScreen(
            api: mockApi,
            existingChannels: const [_existing, _other],
            initialChannel: _existing,
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Channel ID'),
        '2',
      );
      await _tapSave(tester);

      expect(
        find.text('This channel is already in your list.'),
        findsOneWidget,
      );
    },
  );
}
