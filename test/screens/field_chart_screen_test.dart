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
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

// Forces 24h time entry so filter-sheet tests can type "23:59" directly,
// without an AM/PM toggle in the way.
Widget _wrap24(Widget child) => MaterialApp(
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
    child: child!,
  ),
  home: child,
);

String _compactDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.year.toString().padLeft(4, '0')}';

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

  group('pinch-zoom clamping', () {
    // _field spans exactly 2 days: floor = fullRange / 500, ceiling = fullRange.
    const fullRangeMs = 2 * 24 * 60 * 60 * 1000.0;

    testWidgets('spreading fingers apart clamps the range to the floor', (
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

      final center = tester.getRect(find.byType(LineChart)).center;
      final pointerA = await tester.startGesture(center - const Offset(1, 0));
      final pointerB = await tester.startGesture(center + const Offset(1, 0));
      await tester.pump();

      await pointerA.moveTo(center - const Offset(2000, 0));
      await tester.pump();
      await pointerB.moveTo(center + const Offset(2000, 0));
      await tester.pump();

      await pointerA.up();
      await pointerB.up();
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.maxX - data.minX, closeTo(fullRangeMs / 500, 0.01));
    });

    testWidgets('pinching together from the full view stays at the ceiling', (
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

      final center = tester.getRect(find.byType(LineChart)).center;
      final pointerA = await tester.startGesture(
        center - const Offset(300, 0),
      );
      final pointerB = await tester.startGesture(
        center + const Offset(300, 0),
      );
      await tester.pump();

      await pointerA.moveTo(center - const Offset(1, 0));
      await tester.pump();
      await pointerB.moveTo(center + const Offset(1, 0));
      await tester.pump();

      await pointerA.up();
      await pointerB.up();
      await tester.pumpAndSettle();

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(
        data.minX,
        _field.values.first.createdAt.millisecondsSinceEpoch.toDouble(),
      );
      expect(
        data.maxX,
        _field.values.last.createdAt.millisecondsSinceEpoch.toDouble(),
      );
    });
  });

  testWidgets(
    'a single-point series pads the view symmetrically and ignores pinch gestures',
    (tester) async {
      final singleValueField = Field(
        id: 1,
        label: 'Temp',
        values: [FieldValue(createdAt: _now, value: 1)],
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
        (_) async => FieldRange(field: singleValueField, truncated: false),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: singleValueField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: await _fieldSettingsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final anchorMs = _now.millisecondsSinceEpoch.toDouble();
      const paddingMs = 60 * 60 * 1000.0;

      LineChartData data() =>
          tester.widget<LineChart>(find.byType(LineChart)).data;

      expect(data().minX, anchorMs - paddingMs);
      expect(data().maxX, anchorMs + paddingMs);

      final center = tester.getRect(find.byType(LineChart)).center;
      final pointerA = await tester.startGesture(center - const Offset(1, 0));
      final pointerB = await tester.startGesture(center + const Offset(1, 0));
      await tester.pump();
      await pointerA.moveTo(center - const Offset(2000, 0));
      await tester.pump();
      await pointerB.moveTo(center + const Offset(2000, 0));
      await tester.pump();
      await pointerA.up();
      await pointerB.up();
      await tester.pumpAndSettle();

      expect(data().minX, anchorMs - paddingMs);
      expect(data().maxX, anchorMs + paddingMs);
    },
  );

  testWidgets(
    'Column chart shows the no-data message when there are no values to bucket',
    (tester) async {
      final singleValueField = Field(
        id: 1,
        label: 'Temp',
        values: [FieldValue(createdAt: _now, value: 1)],
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
        (_) async => FieldRange(field: singleValueField, truncated: false),
      );
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        singleValueField.id,
        const FieldChartSettings(type: ChartType.column, showDelta: true),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: singleValueField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BarChart), findsOneWidget);
      expect(find.text('No data at this zoom level.'), findsOneWidget);
    },
  );

  testWidgets(
    'Column chart bottom titles thin out to every Nth label past 5 bars',
    (tester) async {
      final manyValuesField = Field(
        id: 1,
        label: 'Temp',
        values: [
          for (var i = 0; i < 20; i++)
            FieldValue(
              createdAt: _now.subtract(Duration(hours: 6 * (19 - i))),
              value: i.toDouble(),
            ),
        ],
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
        (_) async => FieldRange(field: manyValuesField, truncated: false),
      );
      final fieldSettingsStorage = await _fieldSettingsStorage();
      await fieldSettingsStorage.save(
        _channel,
        manyValuesField.id,
        const FieldChartSettings(type: ChartType.column),
      );

      await tester.pumpWidget(
        _wrap(
          FieldChartScreen(
            channel: _channel,
            field: manyValuesField,
            api: mockApi,
            settings: await _settings(),
            fieldSettingsStorage: fieldSettingsStorage,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      // 20 bars => labelStep = (20 / 5).ceil() = 4.
      final getTitles = data.titlesData.bottomTitles.sideTitles
          .getTitlesWidget;
      final meta = TitleMeta(
        min: 0,
        max: 20,
        parentAxisSize: 400,
        axisPosition: 0,
        appliedInterval: 1,
        sideTitles: data.titlesData.bottomTitles.sideTitles,
        formattedValue: '',
        axisSide: AxisSide.bottom,
        rotationQuarterTurns: 0,
      );

      expect(getTitles(0.0, meta), isA<SideTitleWidget>());
      expect(getTitles(1.0, meta), isA<SizedBox>());
      expect(getTitles(4.0, meta), isA<SideTitleWidget>());
      expect(getTitles(-1.0, meta), isA<SizedBox>());
      expect(getTitles(20.0, meta), isA<SizedBox>());
    },
  );

  group('filter sheet', () {
    testWidgets('cancelling leaves the current range unchanged', (
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

      final minXBefore = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .minX;

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      final minXAfter = tester
          .widget<LineChart>(find.byType(LineChart))
          .data
          .minX;
      expect(minXAfter, minXBefore);
    });

    testWidgets('picking a From value past the current To clamps it back', (
      tester,
    ) async {
      final rangeEnd = _field.values.last.createdAt;
      final settings = await _settings();

      await tester.pumpWidget(
        _wrap24(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: settings,
            fieldSettingsStorage: await _fieldSettingsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('From'));
      await tester.pumpAndSettle();

      // Date picker: switch to text input, type a date past the current To.
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        _compactDate(rangeEnd),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Time picker: switch to text input, type a time past the current To.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final timeFields = find.byType(TextFormField);
      await tester.enterText(timeFields.at(0), '23');
      await tester.enterText(timeFields.at(1), '59');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final expected = rangeEnd.subtract(const Duration(minutes: 1));
      expect(find.text(settings.formatDateTime(expected)), findsOneWidget);
    });

    testWidgets('picking a future To value clamps it back to now', (
      tester,
    ) async {
      final rangeEnd = _field.values.last.createdAt;
      final settings = await _settings();

      await tester.pumpWidget(
        _wrap24(
          FieldChartScreen(
            channel: _channel,
            field: _field,
            api: mockApi,
            settings: settings,
            fieldSettingsStorage: await _fieldSettingsStorage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('To'));
      await tester.pumpAndSettle();

      // Default pre-filled date is already the current To's date; accept it.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Time picker: switch to text input, type a time later than now.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final timeFields = find.byType(TextFormField);
      await tester.enterText(timeFields.at(0), '23');
      await tester.enterText(timeFields.at(1), '59');
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final unclamped = DateTime(
        rangeEnd.year,
        rangeEnd.month,
        rangeEnd.day,
        23,
        59,
      );
      expect(find.text(settings.formatDateTime(unclamped)), findsNothing);
    });
  });
}
