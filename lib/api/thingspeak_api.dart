import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/channel.dart';
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
  String toString() =>
      serverMessage != null ? 'ApiException($code): $serverMessage' : 'ApiException($code)';
}

/// Parameters for ThingSpeak API requests.
class ApiParameters {
  final String? apiKey;
  final int? results;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? location;

  const ApiParameters({
    this.apiKey,
    this.results,
    this.startDate,
    this.endDate,
    this.location,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (apiKey != null) params['api_key'] = apiKey!;
    if (results != null) params['results'] = results.toString();
    if (startDate != null) params['start'] = _formatDate(startDate!);
    if (endDate != null) params['end'] = _formatDate(endDate!);
    if (location == true) params['location'] = '1';
    return params;
  }

  static String _formatDate(DateTime dt) =>
      dt.toUtc().toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');
}

/// HTTP client for the ThingSpeak REST API.
///
/// Docs: https://www.mathworks.com/help/thingspeak/
class ThingSpeakApi {
  final http.Client _client;

  ThingSpeakApi(this._client);

  /// Reads channel metadata (name, description, fields).
  ///
  /// `https://api.thingspeak.com/channels/{id}/feeds.json?results=0`
  Future<Channel> readChannel(Channel channel) async {
    final uri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}/feeds.json',
      params: ApiParameters(apiKey: channel.apiKey, results: 0, location: true),
    );

    final raw = await _sendRequest(uri);
    return await compute(_parseChannel, _ParseChannelArgs(raw, channel));
  }

  /// Reads the latest feed data for all fields in a channel.
  ///
  /// `https://api.thingspeak.com/channels/{id}/feeds.json`
  Future<List<Field>> readFeed(Channel channel, ApiParameters params) async {
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
    final uri = _buildUri(
      baseUrl: channel.serverUrl,
      path: '/channels/${channel.id}/fields/$fieldId.json',
      params: params,
    );

    final raw = await _sendRequest(uri);
    return await compute(_parseSingleField, _ParseFieldArgs(raw, fieldId));
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
      response = await _client.get(uri);
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

  // --- Isolate-safe parsers ---

  static Channel _parseChannel(_ParseChannelArgs args) {
    final json = jsonDecode(args.raw) as Map<String, dynamic>;
    final channelJson = json['channel'] as Map<String, dynamic>? ?? json;

    int fieldCount = 0;
    for (int i = 1; i <= 8; i++) {
      if (channelJson.containsKey('field$i')) fieldCount = i;
    }

    return args.channel.copyWith(
      name: channelJson['name'] as String?,
      description: channelJson['description'] as String?,
      updatedAt: channelJson['updated_at'] != null
          ? DateTime.tryParse(channelJson['updated_at'] as String)
          : null,
      fieldCount: fieldCount,
    );
  }

  static List<Field> _parseFields(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final channelJson = json['channel'] as Map<String, dynamic>? ?? {};
    final feeds = json['feeds'] as List<dynamic>? ?? [];

    final fields = <int, ({String? label, List<FieldValue> values})>{};

    for (int i = 1; i <= 8; i++) {
      if (!channelJson.containsKey('field$i')) continue;
      fields[i] = (label: channelJson['field$i'] as String?, values: []);
    }

    for (final entry in feeds) {
      final feed = entry as Map<String, dynamic>;
      final createdAt =
          DateTime.tryParse(feed['created_at'] as String? ?? '')?.toLocal();
      if (createdAt == null) continue;

      for (final id in fields.keys) {
        final rawValue = feed['field$id'] as String?;
        if (rawValue == null) continue;
        final value = double.tryParse(rawValue);
        if (value == null) continue;
        fields[id]!.values.add(FieldValue(createdAt: createdAt, value: value));
      }
    }

    return fields.entries
        .map((e) => Field(id: e.key, label: e.value.label, values: e.value.values))
        .toList();
  }

  static Field _parseSingleField(_ParseFieldArgs args) {
    final json = jsonDecode(args.raw) as Map<String, dynamic>;
    final channelJson = json['channel'] as Map<String, dynamic>? ?? {};
    final feeds = json['feeds'] as List<dynamic>? ?? [];

    final label = channelJson['field${args.fieldId}'] as String?;
    final values = <FieldValue>[];

    for (final entry in feeds) {
      final feed = entry as Map<String, dynamic>;
      final createdAt =
          DateTime.tryParse(feed['created_at'] as String? ?? '')?.toLocal();
      final rawValue = feed['field${args.fieldId}'] as String?;
      if (createdAt == null || rawValue == null) continue;
      final value = double.tryParse(rawValue);
      if (value == null) continue;
      values.add(FieldValue(createdAt: createdAt, value: value));
    }

    return Field(id: args.fieldId, label: label, values: values);
  }
}

// Helper classes for compute() (must be top-level or static)
class _ParseChannelArgs {
  final String raw;
  final Channel channel;
  const _ParseChannelArgs(this.raw, this.channel);
}

class _ParseFieldArgs {
  final String raw;
  final int fieldId;
  const _ParseFieldArgs(this.raw, this.fieldId);
}
