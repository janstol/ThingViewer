import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
import '../models/channel_status.dart';
import '../models/field.dart';

/// Error categories for API failures.
enum ApiErrorCode { network, credentials, invalidResponse, general }

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

  /// The oldest raw feed timestamp pagination actually reached, regardless
  /// of whether that entry carried a usable value for this field. Null when
  /// the range returned no entries at all. Only meaningful when [truncated]
  /// is true — a non-truncated result already covers the full requested
  /// range end to end.
  final DateTime? coveredFrom;

  const FieldRange({
    required this.field,
    required this.truncated,
    this.coveredFrom,
  });
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
    return await _parse(
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
    return await _parse(_parseFields, raw);
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
  /// [readFieldRange] to detect a short (final) page for sparse fields — and
  /// the oldest raw entry timestamp on the page, needed to paginate on
  /// entries rather than on values that happened to parse.
  Future<({Field field, int rawEntryCount, DateTime? oldestRawAt})>
  _readFieldPage(
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
    return await _parse(_parseSingleField, _ParseFieldArgs(raw, fieldId));
  }

  /// Reads the single most recent value for one field, for fields whose
  /// readings are sparser than the detail screen's feed window.
  ///
  /// `https://api.thingspeak.com/channels/{id}/fields/{field_id}/last.json`
  ///
  /// Best effort: ThingSpeak answers 404/`-1` for a field that has never been
  /// written, so any failure is reported as "no value" rather than an error.
  Future<FieldValue?> readLastFieldEntry(Channel channel, int fieldId) async {
    final uri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}/fields/$fieldId/last.json',
      params: ApiParameters(apiKey: channel.apiKey),
    );

    final raw = await _trySendRequest(uri);
    if (raw == null) return null;
    // Deliberately not routed through `_parse`: `_parseLastFieldEntry` already
    // returns null on junk, and turning that into an error would fail the whole
    // detail screen refresh over an optional extra value.
    return await compute(
      _parseLastFieldEntry,
      _ParseFieldArgs(raw, fieldId),
    );
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
    DateTime? coveredFrom;

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

      collected.addAll(result.field.values);
      invalidAt.addAll(result.field.invalidAt);
      onProgress?.call(collected.length);

      final oldestRawAt = result.oldestRawAt;
      if (oldestRawAt != null &&
          (coveredFrom == null || oldestRawAt.isBefore(coveredFrom))) {
        coveredFrom = oldestRawAt;
      }

      if (result.rawEntryCount < _maxResultsPerRequest) {
        // Short page: the full range down to `start` is covered. Compared
        // against the raw feed entry count, not `values.length` — a sparse
        // field can have far fewer values than entries in a full page.
        break;
      }

      if (oldestRawAt == null) {
        // A full page but no entry on it had a parseable timestamp: there is
        // no reliable cursor to advance by, so stop rather than re-request
        // the same window forever.
        truncated = true;
        break;
      }

      final nextCursorEnd = oldestRawAt.subtract(const Duration(seconds: 1));
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
      coveredFrom: coveredFrom,
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
    if (status == 200) {
      // ThingSpeak also delivers its error object under 200, so a successful
      // status alone doesn't mean the body carries data.
      final bodyError = _errorFromBody(response.body);
      if (bodyError != null) {
        throw ApiException(bodyError.code, bodyError.message);
      }
      return response.body;
    }

    if (response.body == '-1' && status == 400) {
      throw const ApiException(ApiErrorCode.credentials);
    }

    final bodyError = _errorFromBody(response.body);
    throw ApiException(
      bodyError?.code ?? ApiErrorCode.general,
      bodyError?.message ?? 'Error $status',
    );
  }

  /// ThingSpeak's own error object, when the body carries one. Bodies are only
  /// inspected when they are small and mention an error, so a full feed page is
  /// never decoded twice.
  static ({ApiErrorCode code, String? message})? _errorFromBody(String body) {
    if (body.length > 4096 || !body.contains('"error"')) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final error = decoded['error'];
    String? message;
    String? errorCode;
    if (error is Map) {
      message = _asString(error['details']);
      errorCode = _asString(error['error_code']);
    } else if (error is String) {
      message = error;
    } else {
      return null;
    }

    final isAuth =
        (errorCode?.startsWith('error_auth') ?? false) ||
        _asString(decoded['status']) == '401';
    return (
      code: isAuth ? ApiErrorCode.credentials : ApiErrorCode.general,
      message: message,
    );
  }

  /// Like [_sendRequest], but swallows [ApiException] and returns null.
  Future<String?> _trySendRequest(Uri uri) async {
    try {
      return await _sendRequest(uri);
    } on ApiException {
      return null;
    }
  }

  /// Runs an isolate parser, normalizing any parse failure into an
  /// [ApiException] the screens already handle.
  Future<R> _parse<M, R>(ComputeCallback<M, R> callback, M message) async {
    try {
      return await compute(callback, message);
    } catch (e) {
      // Never log `e` directly: a FormatException embeds its source, i.e. the
      // whole response body.
      debugPrint('API parse error: ${e.runtimeType}');
      throw const ApiException(ApiErrorCode.invalidResponse);
    }
  }

  // --- Isolate-safe parsers ---
  //
  // These run through compute(), so they throw FormatException rather than
  // ApiException — a custom exception's enum identity is not guaranteed to
  // survive the isolate boundary. `_parse` converts on the other side.

  /// Reads a value only when it is a string, so a wrong-typed one reads as
  /// absent instead of throwing.
  static String? _asString(Object? value) => value is String ? value : null;

  /// Decodes a feed-shaped ThingSpeak body, rejecting anything the parsers
  /// cannot read at all.
  static Map<String, dynamic> _decodeFeedBody(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('response is not a JSON object');
    }
    if (decoded['channel'] is! Map<String, dynamic> &&
        decoded['feeds'] is! List) {
      throw const FormatException('response has no channel or feeds');
    }
    return decoded;
  }

  static Channel _parseChannel(_ParseChannelArgs args) {
    final json = _decodeFeedBody(args.raw);
    final channel = json['channel'];
    final channelJson = channel is Map<String, dynamic> ? channel : json;

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
        url = _asString(settingsJson['url']);
        githubUrl = _asString(settingsJson['github_url']);
      } catch (_) {
        // Best-effort: absent, malformed, or an error body — leave both null.
      }
    }

    return args.channel.copyWith(
      name: _asString(channelJson['name']),
      description: _asString(channelJson['description']),
      url: url,
      githubUrl: githubUrl,
      updatedAt: DateTime.tryParse(_asString(channelJson['updated_at']) ?? ''),
      fieldCount: fieldCount,
    );
  }

  static FeedData _parseFields(String raw) {
    final json = _decodeFeedBody(raw);
    final channel = json['channel'];
    final channelJson = channel is Map<String, dynamic>
        ? channel
        : <String, dynamic>{};
    final feeds = json['feeds'] is List ? json['feeds'] as List<dynamic> : [];

    final fields =
        <
          int,
          ({String? label, List<FieldValue> values, List<DateTime> invalidAt})
        >{};

    for (int i = 1; i <= 8; i++) {
      if (!channelJson.containsKey('field$i')) continue;
      fields[i] = (
        label: _asString(channelJson['field$i']),
        values: [],
        invalidAt: [],
      );
    }

    final statuses = <ChannelStatus>[];

    for (final entry in feeds) {
      if (entry is! Map<String, dynamic>) continue;
      final feed = entry;
      final createdAt = DateTime.tryParse(
        _asString(feed['created_at']) ?? '',
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

      final status = _asString(feed['status']);
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

  static ({Field field, int rawEntryCount, DateTime? oldestRawAt})
  _parseSingleField(_ParseFieldArgs args) {
    final json = _decodeFeedBody(args.raw);
    final channel = json['channel'];
    final channelJson = channel is Map<String, dynamic>
        ? channel
        : <String, dynamic>{};
    final feeds = json['feeds'] is List ? json['feeds'] as List<dynamic> : [];

    final label = _asString(channelJson['field${args.fieldId}']);
    final values = <FieldValue>[];
    final invalidAt = <DateTime>[];
    DateTime? oldestRawAt;

    for (final entry in feeds) {
      if (entry is! Map<String, dynamic>) continue;
      final feed = entry;
      final createdAt = DateTime.tryParse(
        _asString(feed['created_at']) ?? '',
      )?.toLocal();
      if (createdAt != null &&
          (oldestRawAt == null || createdAt.isBefore(oldestRawAt))) {
        oldestRawAt = createdAt;
      }
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
      oldestRawAt: oldestRawAt,
    );
  }

  /// The `last.json` response is a bare entry object (no `channel` wrapper),
  /// so it carries no field label — unlike [_parseSingleField].
  static FieldValue? _parseLastFieldEntry(_ParseFieldArgs args) {
    try {
      final feed = jsonDecode(args.raw) as Map<String, dynamic>;
      final createdAt = DateTime.tryParse(
        _asString(feed['created_at']) ?? '',
      )?.toLocal();
      final rawValue = feed['field${args.fieldId}'];
      if (createdAt == null || rawValue == null) return null;
      final value = double.tryParse('$rawValue');
      if (value == null || !value.isFinite) return null;
      return FieldValue(createdAt: createdAt, value: value);
    } catch (_) {
      return null;
    }
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
