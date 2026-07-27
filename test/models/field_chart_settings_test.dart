import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/field_chart_settings.dart';

void main() {
  group('isDefault', () {
    test('defaults are default', () {
      expect(FieldChartSettings.defaults.isDefault, isTrue);
    });

    test('any non-default field makes it non-default', () {
      expect(
        FieldChartSettings.defaults.copyWith(showDelta: true).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(type: ChartType.step).isDefault,
        isFalse,
      );
      expect(
        FieldChartSettings.defaults.copyWith(decimals: 2).isDefault,
        isFalse,
      );
    });
  });

  group('toJson', () {
    test('defaults produce an empty map', () {
      expect(FieldChartSettings.defaults.toJson(), isEmpty);
    });

    test('non-default fields are all included', () {
      const settings = FieldChartSettings(
        type: ChartType.step,
        title: 'Custom title',
        xAxisLabel: 'Time',
        yAxisLabel: 'Value',
        yMin: 0,
        yMax: 100,
        decimals: 2,
        showDelta: true,
      );

      expect(settings.toJson(), {
        'type': 'step',
        'title': 'Custom title',
        'xAxisLabel': 'Time',
        'yAxisLabel': 'Value',
        'yMin': 0.0,
        'yMax': 100.0,
        'decimals': 2,
        'showDelta': true,
      });
    });
  });

  group('fromJson round-trip', () {
    test('round-trips a fully populated instance', () {
      const settings = FieldChartSettings(
        type: ChartType.spline,
        title: 'Custom title',
        xAxisLabel: 'Time',
        yAxisLabel: 'Value',
        yMin: -5.5,
        yMax: 42.25,
        decimals: 4,
        showDelta: true,
      );

      final roundTripped = FieldChartSettings.fromJson(settings.toJson());

      expect(roundTripped, settings);
    });

    test('round-trips defaults', () {
      final roundTripped = FieldChartSettings.fromJson(
        FieldChartSettings.defaults.toJson(),
      );

      expect(roundTripped, FieldChartSettings.defaults);
    });
  });

  group('fromJson tolerance', () {
    test('unknown type string falls back to line', () {
      final settings = FieldChartSettings.fromJson({'type': 'bar'});

      expect(settings.type, ChartType.line);
    });

    test('missing type falls back to line', () {
      final settings = FieldChartSettings.fromJson({});

      expect(settings.type, ChartType.line);
    });

    test('non-numeric bounds fall back to null (auto)', () {
      final settings = FieldChartSettings.fromJson({
        'yMin': 'not a number',
        'yMax': <String, dynamic>{},
        'decimals': 'two',
      });

      expect(settings.yMin, isNull);
      expect(settings.yMax, isNull);
      expect(settings.decimals, isNull);
    });

    test('integer bounds are parsed as doubles', () {
      final settings = FieldChartSettings.fromJson({'yMin': 0, 'yMax': 100});

      expect(settings.yMin, 0.0);
      expect(settings.yMax, 100.0);
    });
  });
}
