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
}
