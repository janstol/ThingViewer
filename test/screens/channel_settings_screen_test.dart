import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel_settings.dart';
import 'package:thingviewer/models/range_preset.dart';
import 'package:thingviewer/screens/channel_settings/channel_settings_screen.dart';
import 'package:thingviewer/theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('picking a default range reports it and keeps the rest', (
    tester,
  ) async {
    final changes = <ChannelSettings>[];
    await tester.pumpWidget(
      _wrap(
        ChannelSettingsScreen(
          settings: const ChannelSettings(rememberRange: true),
          onChanged: changes.add,
          onEditChannel: () {},
        ),
      ),
    );

    await tester.tap(find.text('Default range'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 30 days'));
    await tester.pumpAndSettle();

    expect(
      changes.single,
      const ChannelSettings(
        defaultRange: RangePreset.last30Days,
        rememberRange: true,
      ),
    );
    expect(
      find.text('Last 30 days. Fields with their own default range keep it.'),
      findsOneWidget,
    );
  });

  testWidgets('the remember switch reports the new value', (tester) async {
    final changes = <ChannelSettings>[];
    await tester.pumpWidget(
      _wrap(
        ChannelSettingsScreen(
          settings: ChannelSettings.defaults,
          onChanged: changes.add,
          onEditChannel: () {},
        ),
      ),
    );

    await tester.tap(find.text('Remember selected range'));
    await tester.pumpAndSettle();

    expect(changes.single, const ChannelSettings(rememberRange: true));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('Edit channel calls onEditChannel', (tester) async {
    var edited = 0;
    await tester.pumpWidget(
      _wrap(
        ChannelSettingsScreen(
          settings: ChannelSettings.defaults,
          onChanged: (_) {},
          onEditChannel: () => edited++,
        ),
      ),
    );

    await tester.tap(find.text('Edit channel'));
    await tester.pumpAndSettle();

    expect(edited, 1);
  });
}
