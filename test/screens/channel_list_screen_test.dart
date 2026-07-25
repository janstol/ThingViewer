import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/channel_list/channel_list_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';

import 'channel_detail_notifier_test.mocks.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

Future<SettingsNotifier> _settings() async {
  final prefs = await SharedPreferences.getInstance();
  return SettingsNotifier(SettingsStorage(prefs));
}

void main() {
  late MockThingSpeakApi mockApi;

  setUp(() {
    mockApi = MockThingSpeakApi();
  });

  testWidgets('shows empty-state message with no saved channels', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(_wrap(ChannelListScreen(
      api: mockApi,
      channelStorage: storage,
      settings: await _settings(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('No saved channels. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('renders a tile for each saved channel', (tester) async {
    SharedPreferences.setMockInitialValues({
      'channels': Channel.listToJson([_channel]),
    });
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(_wrap(ChannelListScreen(
      api: mockApi,
      channelStorage: storage,
      settings: await _settings(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('My Channel'), findsOneWidget);
  });

  testWidgets('cancelling the swipe-to-dismiss dialog keeps the channel', (tester) async {
    SharedPreferences.setMockInitialValues({
      'channels': Channel.listToJson([_channel]),
    });
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await tester.pumpWidget(_wrap(ChannelListScreen(
      api: mockApi,
      channelStorage: storage,
      settings: await _settings(),
    )));
    await tester.pumpAndSettle();

    await tester.drag(find.text('My Channel'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Remove channel?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('My Channel'), findsOneWidget);
  });
}
