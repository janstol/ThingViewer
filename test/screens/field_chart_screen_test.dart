import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/l10n/app_localizations.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/models/field_chart_settings.dart';
import 'package:thingviewer/screens/field_chart/field_chart_screen.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/field_settings_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';
import 'package:thingviewer/theme.dart';

import 'field_chart_notifier_test.mocks.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

// The notifier's default range is the last 7 days from DateTime.now(), so
// fixture timestamps must be recent or the fetched values get filtered out
// and the chart never leaves the empty state.
final _now = DateTime.now();
final _field = Field(
  id: 1,
  label: 'Temp',
  values: [
    FieldValue(createdAt: _now.subtract(const Duration(days: 2)), value: 1),
    FieldValue(createdAt: _now.subtract(const Duration(days: 1)), value: 2),
    FieldValue(createdAt: _now, value: 3),
  ],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.light(),
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
    when(
      mockApi.readFieldRange(
        any,
        any,
        apiKey: anyNamed('apiKey'),
        start: anyNamed('start'),
        end: anyNamed('end'),
      ),
    ).thenAnswer((_) async => FieldRange(field: _field, truncated: false));
  });

  testWidgets(
    'selecting Step in field settings applies isStepLineChart to the rendered chart',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      LineChartData chartData() =>
          tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(chartData().lineBarsData.single.isStepLineChart, isFalse);
      expect(chartData().lineBarsData.single.isCurved, isFalse);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Step'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(chartData().lineBarsData.single.isStepLineChart, isTrue);
      expect(chartData().lineBarsData.single.isCurved, isFalse);
    },
  );

  testWidgets(
    'selecting Spline in field settings applies isCurved to the rendered chart',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spline'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      final chartData = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(chartData.lineBarsData.single.isCurved, isTrue);
      expect(chartData.lineBarsData.single.isStepLineChart, isFalse);
    },
  );

  testWidgets('selecting Column renders a BarChart and no LineChart', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        FieldChartScreen(
          channel: _channel,
          field: _field,
          api: mockApi,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Column'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('Scatter is not offered in the type picker', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FieldChartScreen(
          channel: _channel,
          field: _field,
          api: mockApi,
          settings: await _settings(),
          fieldSettingsStorage: await _fieldSettingsStorage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Type'));
    await tester.pumpAndSettle();

    expect(find.text('Scatter'), findsNothing);
  });

  testWidgets(
    // Scatter is hidden from the picker but stays implemented — a field
    // already set to it (from before it was hidden) must still render and
    // must not crash the settings screen's label lookup.
    'a field already set to Scatter keeps rendering it, picker unaffected',
    (tester) async {
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        _field.id,
        const FieldChartSettings(type: ChartType.scatter),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chartData = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(chartData.lineBarsData.single.barWidth, 0);
      expect(chartData.lineBarsData.single.dotData.show, isTrue);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Scatter'), findsOneWidget); // shown as current value
    },
  );

  testWidgets(
    'gapOnInvalid inserts a null spot at the invalid reading; off by default',
    (tester) async {
      // Tall viewport so the new switch doesn't need scrolling into view.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Between the day-2 and day-1 real values.
      final invalidAt = _now.subtract(const Duration(hours: 36));
      final fieldWithInvalid = Field(
        id: 1,
        label: 'Temp',
        values: _field.values,
        invalidAt: [invalidAt],
      );
      when(
        mockApi.readFieldRange(
          any,
          any,
          apiKey: anyNamed('apiKey'),
          start: anyNamed('start'),
          end: anyNamed('end'),
        ),
      ).thenAnswer(
        (_) async => FieldRange(field: fieldWithInvalid, truncated: false),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      List<FlSpot> spots() => tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .lineBarsData
          .single
          .spots;

      // Off by default: connected across the invalid reading, no null spot.
      expect(spots().any((s) => s.x.isNaN), isFalse);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Break line at invalid readings'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      final withGap = spots();
      final nullIndex = withGap.indexWhere((s) => s.x.isNaN);
      expect(nullIndex, greaterThan(-1));
      expect(
        withGap[nullIndex - 1].x,
        _field.values[0].createdAt.millisecondsSinceEpoch.toDouble(),
      );
      expect(
        withGap[nullIndex + 1].x,
        _field.values[1].createdAt.millisecondsSinceEpoch.toDouble(),
      );
    },
  );
}
