import 'package:flutter/material.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/field.dart';

sealed class FieldChartState {}

class FieldChartLoading extends FieldChartState {}

class FieldChartLoaded extends FieldChartState {
  final DateTimeRange range;
  final List<FieldValue> values;
  FieldChartLoaded(this.range, this.values);
}

class FieldChartEmpty extends FieldChartState {
  final DateTimeRange range;
  FieldChartEmpty(this.range);
}

class FieldChartError extends FieldChartState {
  final DateTimeRange range;
  final List<FieldValue> cachedValues;
  final ApiErrorCode errorCode;
  final String? serverMessage;
  FieldChartError(
    this.range,
    this.cachedValues,
    this.errorCode, [
    this.serverMessage,
  ]);
}

class FieldChartNotifier extends ChangeNotifier {
  final ThingSpeakApi _api;
  final Channel _channel;
  final Field _field;
  bool _disposed = false;

  /// Local cache of all fetched values.
  final List<FieldValue> _cache;

  FieldChartState _state = FieldChartLoading();
  FieldChartState get state => _state;

  FieldChartNotifier(this._api, this._channel, this._field)
    : _cache = List.of(_field.values) {
    // Always fetch the default range from the API on first open. The single
    // cached value from the channel detail screen is not enough to draw a
    // useful chart.
    applyFilter(_defaultRange());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> applyFilter(DateTimeRange range) async {
    _state = FieldChartLoading();
    notifyListeners();

    _state = await _getData(range);
    if (!_disposed) notifyListeners();
  }

  Future<FieldChartState> _getData(DateTimeRange range) async {
    final cacheRange = _cacheRange(_cache);

    // If the cache already covers the requested range, filter locally.
    if (_cache.isNotEmpty &&
        !range.start.isBefore(cacheRange.start) &&
        !range.end.isAfter(cacheRange.end)) {
      final filtered = _filterByRange(_cache, range);
      return filtered.isEmpty
          ? FieldChartEmpty(range)
          : FieldChartLoaded(range, filtered);
    }

    // Fetch from API.
    try {
      final result = await _api.readField(
        _channel,
        _field.id,
        ApiParameters(
          apiKey: _channel.apiKey,
          startDate: range.start,
          endDate: range.end,
        ),
      );
      if (result.values.isNotEmpty) {
        // Merge new values into the cache (keyed by timestamp) so previously
        // cached data outside the requested range is preserved.
        final merged = {for (final v in _cache) v.createdAt: v};
        for (final v in result.values) {
          merged[v.createdAt] = v;
        }
        _cache
          ..clear()
          ..addAll(
            merged.values.toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          );
      }
    } on ApiException catch (e) {
      return FieldChartError(
        range,
        _filterByRange(_cache, range),
        e.code,
        e.serverMessage,
      );
    }

    final filtered = _filterByRange(_cache, range);
    return filtered.isEmpty
        ? FieldChartEmpty(range)
        : FieldChartLoaded(range, filtered);
  }

  static List<FieldValue> _filterByRange(
    List<FieldValue> data,
    DateTimeRange range,
  ) => data
      .where(
        (v) =>
            !v.createdAt.isBefore(range.start) &&
            !v.createdAt.isAfter(range.end),
      )
      .toList();

  static DateTimeRange _cacheRange(List<FieldValue> data) {
    if (data.isEmpty) return _defaultRange();
    final sorted = data.map((v) => v.createdAt).toList()..sort();
    return DateTimeRange(start: sorted.first, end: sorted.last);
  }

  static DateTimeRange _defaultRange() {
    final now = DateTime.now();
    return DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );
  }
}
