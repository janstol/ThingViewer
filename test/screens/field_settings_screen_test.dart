import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/screens/field_settings/field_settings_screen.dart';
import 'package:thingviewer/theme.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

const _field = Field(id: 1, label: 'Temp');

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('selecting a chart type fires onChanged with it', (tester) async {
    FieldChartSettings? changed;

    await tester.pumpWidget(
      _wrap(
        FieldSettingsScreen(
          channel: _channel,
          field: _field,
          settings: FieldChartSettings.defaults,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();

    expect(find.text('Choose chart type'), findsOneWidget);

    await tester.tap(find.text('Step'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.type, ChartType.step);
  });

  testWidgets('selecting Column fires onChanged with it', (tester) async {
    FieldChartSettings? changed;

    await tester.pumpWidget(
      _wrap(
        FieldSettingsScreen(
          channel: _channel,
          field: _field,
          settings: FieldChartSettings.defaults,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Column'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.type, ChartType.column);
  });

  testWidgets('reset restores defaults after changes', (tester) async {
    FieldChartSettings? changed;

    await tester.pumpWidget(
      _wrap(
        FieldSettingsScreen(
          channel: _channel,
          field: _field,
          settings: const FieldChartSettings(
            type: ChartType.step,
            showDelta: true,
          ),
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Reset to defaults'), 200);
    await tester.tap(find.text('Reset to defaults'));
    await tester.pumpAndSettle();

    expect(changed, FieldChartSettings.defaults);
  });

  testWidgets('toggling a stats-bar switch fires onChanged with just that '
      'field flipped', (tester) async {
    FieldChartSettings? changed;

    await tester.pumpWidget(
      _wrap(
        FieldSettingsScreen(
          channel: _channel,
          field: _field,
          settings: FieldChartSettings.defaults,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Show sum'), 200);
    await tester.tap(find.text('Show sum'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.showSum, isFalse);
    // Untouched toggles stay at their default (shown).
    expect(changed!.showAverage, isTrue);
    expect(changed!.showMin, isTrue);
    expect(changed!.showMax, isTrue);
  });

  testWidgets('toggling the marker switches fires onChanged with just that '
      'field flipped', (tester) async {
    FieldChartSettings? changed;

    await tester.pumpWidget(
      _wrap(
        FieldSettingsScreen(
          channel: _channel,
          field: _field,
          settings: FieldChartSettings.defaults,
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Mark minimum on chart'), 200);
    await tester.tap(find.text('Mark minimum on chart'));
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.markMin, isTrue);
    expect(changed!.markMax, isFalse);

    await tester.scrollUntilVisible(find.text('Mark maximum on chart'), 200);
    await tester.tap(find.text('Mark maximum on chart'));
    await tester.pumpAndSettle();

    expect(changed!.markMin, isTrue);
    expect(changed!.markMax, isTrue);
  });

  testWidgets('setting yMin >= yMax is rejected, previous value kept', (
    tester,
  ) async {
    FieldChartSettings? changed;

    await tester.pumpWidget(
      _wrap(
        FieldSettingsScreen(
          channel: _channel,
          field: _field,
          settings: const FieldChartSettings(yMin: 0, yMax: 10),
          onChanged: (v) => changed = v,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Y-axis max'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    // yMax == yMin is rejected: onChanged must not fire, and the tile keeps
    // showing the original value.
    expect(changed, isNull);
    expect(find.text('10'), findsOneWidget);
  });
}
