import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/channel_status.dart';
import '../models/field.dart';

/// Error categories for API failures.
enum ApiErrorCode { network, credentials, general }

/// Thrown when an API request fails.
class ApiException implements Exception {
  final ApiErrorCode code;

  /// Optional server-provided detail (e.g. "Error 503").
  final String? serverMessage;

  const ApiException(this.code, [this.serverMessage]);

  @override
  String toString() => serverMessage != null
      ? 'ApiException($code): $serverMessage'
      : 'ApiException($code)';
}

/// Parameters for ThingSpeak API requests.
class ApiParameters {
  final String? apiKey;
  final int? results;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? location;
  final bool? status;

  const ApiParameters({
    this.apiKey,
    this.results,
    this.startDate,
    this.endDate,
    this.location,
    this.status,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (apiKey != null) params['api_key'] = apiKey!;
    if (results != null) params['results'] = results.toString();
    if (startDate != null) params['start'] = _formatDate(startDate!);
    if (endDate != null) params['end'] = _formatDate(endDate!);
    if (location == true) params['location'] = '1';
    if (status == true) params['status'] = 'true';
    return params;
  }

  static String _formatDate(DateTime dt) =>
      dt.toUtc().toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');
}

/// The result of [ThingSpeakApi.readFieldRange]: the paginated field data,
/// plus whether the page budget was exhausted before the full range was
/// covered.
class FieldRange {
  final Field field;
  final bool truncated;

  const FieldRange({required this.field, required this.truncated});
}

/// The result of [ThingSpeakApi.readFeed]: field values and channel statuses
/// parsed from the same response, so status comes at no extra request cost.
class FeedData {
  final List<Field> fields;
  final List<ChannelStatus> statuses;

  const FeedData({required this.fields, required this.statuses});
}

/// HTTP client for the ThingSpeak REST API.
///
/// Docs: https://www.mathworks.com/help/thingspeak/
class ThingSpeakApi {
  final http.Client _client;

  /// ThingSpeak silently caps any single `feeds`/`fields` request at this many
  /// entries, regardless of the requested date range — verified against the
  /// live API. [readFieldRange] paginates backwards past it.
  static const _maxResultsPerRequest = 8000;

  /// Cap on the number of pages [readFieldRange] will fetch (≈80 000 points)
  /// so a very dense channel can't turn a single chart open into an unbounded
  /// number of requests.
  static const _maxPages = 10;

  /// [readFieldRange] can request up to [_maxResultsPerRequest] entries per
  /// page, so a generous ceiling avoids cutting off a slow-but-progressing
  /// request while still bounding a stalled connection.
  static const _requestTimeout = Duration(seconds: 20);

  ThingSpeakApi(this._client);

  /// Reads channel metadata (name, description, fields).
  ///
  /// `https://api.thingspeak.com/channels/{id}/feeds.json?results=0`
  ///
  /// Also fires a best-effort request to `/channels/{id}.json` for `url` and
  /// `github_url`, which the feeds endpoint doesn't return. That leg never
  /// fails the call — it's unclear whether a private channel needs the
  /// account-level User API Key rather than the channel Read API Key stored
  /// here, so any failure is treated the same as the fields simply being absent.
  Future<Channel> readChannel(Channel channel) async {
    final feedsUri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}/feeds.json',
      params: ApiParameters(apiKey: channel.apiKey, results: 0, location: true),
    );
    final settingsUri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}.json',
      params: ApiParameters(apiKey: channel.apiKey),
    );

    final results = await Future.wait([
      _sendRequest(feedsUri),
      _trySendRequest(settingsUri),
    ]);
    return await compute(
      _parseChannel,
      _ParseChannelArgs(results[0]!, channel, results[1]),
    );
  }

  /// Reads the latest feed data for all fields in a channel, plus any
  /// per-entry status messages when `params.status` is set.
  ///
  /// `https://api.thingspeak.com/channels/{id}/feeds.json`
  Future<FeedData> readFeed(Channel channel, ApiParameters params) async {
    final uri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}/feeds.json',
      params: params,
    );

    final raw = await _sendRequest(uri);
    return await compute(_parseFields, raw);
  }

  /// Reads data for a single field.
  ///
  /// `https://api.thingspeak.com/channels/{id}/fields/{field_id}.json`
  Future<Field> readField(
    Channel channel,
    int fieldId,
    ApiParameters params,
  ) async {
    final page = await _readFieldPage(channel, fieldId, params);
    return page.field;
  }

  /// Like [readField], but also returns the raw feed entry count for the
  /// page — the count *before* filtering to this field's values, needed by
  /// [readFieldRange] to detect a short (final) page for sparse fields.
  Future<({Field field, int rawEntryCount})> _readFieldPage(
    Channel channel,
    int fieldId,
    ApiParameters params,
  ) async {
    final uri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}/fields/$fieldId.json',
      params: params,
    );

    final raw = await _sendRequest(uri);
    return await compute(_parseSingleField, _ParseFieldArgs(raw, fieldId));
  }

  /// Reads all data for a single field over [start]..[end], paginating
  /// backwards past ThingSpeak's [_maxResultsPerRequest]-entry-per-request cap.
  ///
  /// Each page requests `results: _maxResultsPerRequest` ending at a cursor
  /// that starts at [end] and walks backward to just before the oldest
  /// timestamp seen so far. Stops when a page comes back short (the full
  /// range is covered), when a page makes no backward progress (defensive
  /// against many entries sharing one timestamp), or after [_maxPages].
  Future<FieldRange> readFieldRange(
    Channel channel,
    int fieldId, {
    String? apiKey,
    required DateTime start,
    required DateTime end,
    void Function(int fetched)? onProgress,
  }) async {
    final collected = <FieldValue>[];
    final invalidAt = <DateTime>[];
    String? label;
    var cursorEnd = end;
    var truncated = false;

    for (var page = 0; page < _maxPages; page++) {
      final result = await _readFieldPage(
        channel,
        fieldId,
        ApiParameters(
          apiKey: apiKey,
          startDate: start,
          endDate: cursorEnd,
          results: _maxResultsPerRequest,
        ),
      );
      label ??= result.field.label;

      if (result.field.values.isEmpty) break;

      collected.addAll(result.field.values);
      invalidAt.addAll(result.field.invalidAt);
      onProgress?.call(collected.length);

      if (result.rawEntryCount < _maxResultsPerRequest) {
        // Short page: the full range down to `start` is covered. Compared
        // against the raw feed entry count, not `values.length` — a sparse
        // field can have far fewer values than entries in a full page.
        break;
      }

      final oldest = result.field.values.first.createdAt;
      final nextCursorEnd = oldest.subtract(const Duration(seconds: 1));
      if (!nextCursorEnd.isAfter(start)) break;

      if (!nextCursorEnd.isBefore(cursorEnd)) {
        // No backward progress possible (e.g. many entries share one
        // timestamp) — stop rather than loop forever.
        truncated = true;
        break;
      }
      cursorEnd = nextCursorEnd;

      if (page == _maxPages - 1) truncated = true;
    }

    collected.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    invalidAt.sort();
    return FieldRange(
      field: Field(
        id: fieldId,
        label: label,
        values: collected,
        invalidAt: invalidAt,
      ),
      truncated: truncated,
    );
  }

  Uri _buildUri({
    required String baseUrl,
    required String path,
    ApiParameters? params,
  }) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.replaceAll(RegExp(r'/+$'), '');
    final queryParams = params?.toQueryParameters() ?? const <String, String>{};
    // `Uri.replace` keeps the original query when queryParameters is null,
    // so pass an explicit (possibly empty) map to avoid leaking a query
    // string from a custom base URL into every request.
    return base.replace(
      path: '$basePath$path',
      queryParameters: queryParams.isNotEmpty ? queryParams : const {},
    );
  }

  Future<String> _sendRequest(Uri uri) async {
    http.Response response;
    try {
      response = await _client.get(uri).timeout(_requestTimeout);
    } on SocketException catch (e) {
      throw ApiException(
        e.osError?.errorCode == 7 ? ApiErrorCode.network : ApiErrorCode.general,
      );
    } on Exception catch (e) {
      // Never log `e` directly: http.ClientException.toString() embeds the
      // request URI, which can carry a private channel's api_key.
      debugPrint('API error: ${e.runtimeType}');
      throw const ApiException(ApiErrorCode.network);
    }

    final status = response.statusCode;
    if (status == 200) return response.body;

    if (response.body == '-1' && status == 400) {
      throw const ApiException(ApiErrorCode.credentials);
    }

    String? serverMessage;
    try {
      final parsed = jsonDecode(response.body) as Map<String, dynamic>;
      final error = parsed['error'];
      if (error is Map && error.containsKey('details')) {
        serverMessage = error['details'] as String?;
      } else if (error is String) {
        serverMessage = error;
      }
    } catch (_) {}

    throw ApiException(ApiErrorCode.general, serverMessage ?? 'Error $status');
  }

  /// Like [_sendRequest], but swallows [ApiException] and returns null.
  Future<String?> _trySendRequest(Uri uri) async {
    try {
      return await _sendRequest(uri);
    } on ApiException {
      return null;
    }
  }

  // --- Isolate-safe parsers ---

  static Channel _parseChannel(_ParseChannelArgs args) {
    final json = jsonDecode(args.raw) as Map<String, dynamic>;
    final channelJson = json['channel'] as Map<String, dynamic>? ?? json;

    int fieldCount = 0;
    for (int i = 1; i <= 8; i++) {
      if (channelJson.containsKey('field$i')) fieldCount = i;
    }

    String? url;
    String? githubUrl;
    if (args.settingsRaw != null) {
      try {
        final settingsJson =
            jsonDecode(args.settingsRaw!) as Map<String, dynamic>;
        url = settingsJson['url'] as String?;
        githubUrl = settingsJson['github_url'] as String?;
      } catch (_) {
        // Best-effort: absent, malformed, or an error body — leave both null.
      }
    }

    return args.channel.copyWith(
      name: channelJson['name'] as String?,
      description: channelJson['description'] as String?,
      url: url,
      githubUrl: githubUrl,
      updatedAt: channelJson['updated_at'] != null
          ? DateTime.tryParse(channelJson['updated_at'] as String)
          : null,
      fieldCount: fieldCount,
    );
  }

  static FeedData _parseFields(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final channelJson = json['channel'] as Map<String, dynamic>? ?? {};
    final feeds = json['feeds'] as List<dynamic>? ?? [];

    final fields =
        <
          int,
          ({String? label, List<FieldValue> values, List<DateTime> invalidAt})
        >{};

    for (int i = 1; i <= 8; i++) {
      if (!channelJson.containsKey('field$i')) continue;
      fields[i] = (
        label: channelJson['field$i'] as String?,
        values: [],
        invalidAt: [],
      );
    }

    final statuses = <ChannelStatus>[];

    for (final entry in feeds) {
      final feed = entry as Map<String, dynamic>;
      final createdAt = DateTime.tryParse(
        feed['created_at'] as String? ?? '',
      )?.toLocal();
      if (createdAt == null) continue;

      for (final id in fields.keys) {
        final rawValue = feed['field$id'];
        if (rawValue == null) continue;
        final value = double.tryParse('$rawValue');
        if (value == null) continue;
        if (!value.isFinite) {
          fields[id]!.invalidAt.add(createdAt);
          continue;
        }
        fields[id]!.values.add(FieldValue(createdAt: createdAt, value: value));
      }

      final status = feed['status'] as String?;
      if (status != null && status.trim().isNotEmpty) {
        statuses.add(ChannelStatus(createdAt: createdAt, message: status));
      }
    }

    final parsedFields = fields.entries.map((e) {
      final values = e.value.values
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final invalidAt = e.value.invalidAt..sort();
      return Field(
        id: e.key,
        label: e.value.label,
        values: values,
        invalidAt: invalidAt,
      );
    }).toList();

    statuses.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return FeedData(fields: parsedFields, statuses: statuses);
  }

  static ({Field field, int rawEntryCount}) _parseSingleField(
    _ParseFieldArgs args,
  ) {
    final json = jsonDecode(args.raw) as Map<String, dynamic>;
    final channelJson = json['channel'] as Map<String, dynamic>? ?? {};
    final feeds = json['feeds'] as List<dynamic>? ?? [];

    final label = channelJson['field${args.fieldId}'] as String?;
    final values = <FieldValue>[];
    final invalidAt = <DateTime>[];

    for (final entry in feeds) {
      final feed = entry as Map<String, dynamic>;
      final createdAt = DateTime.tryParse(
        feed['created_at'] as String? ?? '',
      )?.toLocal();
      final rawValue = feed['field${args.fieldId}'];
      if (createdAt == null || rawValue == null) continue;
      final value = double.tryParse('$rawValue');
      if (value == null) continue;
      if (!value.isFinite) {
        invalidAt.add(createdAt);
        continue;
      }
      values.add(FieldValue(createdAt: createdAt, value: value));
    }
    values.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    invalidAt.sort();

    return (
      field: Field(
        id: args.fieldId,
        label: label,
        values: values,
        invalidAt: invalidAt,
      ),
      rawEntryCount: feeds.length,
    );
  }
}

// Helper classes for compute() (must be top-level or static)
class _ParseChannelArgs {
  final String raw;
  final Channel channel;
  final String? settingsRaw;
  const _ParseChannelArgs(this.raw, this.channel, this.settingsRaw);
}

class _ParseFieldArgs {
  final String raw;
  final int fieldId;
  const _ParseFieldArgs(this.raw, this.fieldId);
}
