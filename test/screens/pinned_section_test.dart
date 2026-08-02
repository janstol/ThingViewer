import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/channel_snapshot.dart';
import 'package:thingviewer/models/pinned_field.dart';
import 'package:thingviewer/screens/channel_list/pinned_notifier.dart';
import 'package:thingviewer/screens/channel_list/pinned_section.dart';
import 'package:thingviewer/theme.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

const _pin = PinnedField(
  serverUrl: 'https://api.thingspeak.com',
  channelId: 1,
  fieldId: 1,
);

final _now = DateTime.utc(2024, 1, 1, 12);

Widget _wrap(List<PinnedEntry> entries) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: PinnedSection(
      entries: entries,
      now: _now,
      onEdit: () {},
      onTap: (_) {},
    ),
  ),
);

void main() {
  testWidgets(
    'a failed refresh with a cached value shows that value, not N/A',
    (tester) async {
      final entry = PinnedEntry(
        channel: _channel,
        pin: _pin,
        snapshot: FieldSnapshot(
          id: 1,
          label: 'Temp',
          value: 23.5,
          valueAt: _now.subtract(const Duration(hours: 2)),
        ),
        state: PinnedEntryError(ApiErrorCode.network),
      );

      await tester.pumpWidget(_wrap([entry]));

      expect(find.text('23.50'), findsOneWidget);
      expect(find.text('N/A'), findsNothing);
    },
  );

  testWidgets('a failed refresh with no cached value shows N/A', (
    tester,
  ) async {
    final entry = PinnedEntry(
      channel: _channel,
      pin: _pin,
      snapshot: null,
      state: PinnedEntryError(ApiErrorCode.network),
    );

    await tester.pumpWidget(_wrap([entry]));

    expect(find.text('N/A'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('a successful value shows the value and age', (tester) async {
    final entry = PinnedEntry(
      channel: _channel,
      pin: _pin,
      snapshot: FieldSnapshot(
        id: 1,
        label: 'Temp',
        value: 21.0,
        valueAt: _now.subtract(const Duration(minutes: 5)),
      ),
      state: PinnedEntryValue(),
    );

    await tester.pumpWidget(_wrap([entry]));

    expect(find.text('21.00'), findsOneWidget);
  });
}
