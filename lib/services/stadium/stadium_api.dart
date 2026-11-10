import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../entities/stadium/stadium.dart';

class StadiumApiException implements Exception {
  const StadiumApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StadiumApi {
  StadiumApi({
    http.Client? client,
    Future<String?> Function()? readToken,
    String? baseUrl,
  }) : _client = client ?? http.Client(),
       _readToken =
           readToken ??
           (() => const FlutterSecureStorage().read(key: 'auth_token')),
       _baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: 'http://10.0.2.2:8080',
           );

  final http.Client _client;
  final Future<String?> Function() _readToken;
  final String _baseUrl;

  Future<StadiumOverview> overview() async =>
      StadiumOverview.fromJson(await _send('GET', '/owner/stadiums'));

  Future<Stadium> stadium(int id) async => Stadium.fromJson(
    (await _send('GET', '/owner/stadiums/$id'))['stadium']
        as Map<String, dynamic>,
  );

  Future<Stadium> create(StadiumDraft draft) async => Stadium.fromJson(
    (await _send('POST', '/owner/stadiums', body: draft.toJson()))['stadium']
        as Map<String, dynamic>,
  );

  Future<Stadium> update(int id, StadiumDraft draft) async => Stadium.fromJson(
    (await _send('PUT', '/owner/stadiums/$id', body: draft.toJson()))['stadium']
        as Map<String, dynamic>,
  );

  Future<void> delete(int id) => _send('DELETE', '/owner/stadiums/$id');

  Future<Stadium> setPaused(int id, bool paused) async => Stadium.fromJson(
    (await _send(
          'POST',
          '/owner/stadiums/$id/pause',
          body: {'paused': paused},
        ))['stadium']
        as Map<String, dynamic>,
  );

  Future<DayAvailability> availability(int id, DateTime day) async =>
      DayAvailability.fromJson(
        await _send(
          'GET',
          '/owner/stadiums/$id/availability?date=${stadiumDay(day)}',
        ),
      );

  Future<void> block(int stadiumId, int pitchId, DateTime day, int start) =>
      _send(
        'POST',
        '/owner/stadiums/$stadiumId/blocks',
        body: {'pitchId': pitchId, 'date': stadiumDay(day), 'start': start},
      );

  Future<void> unblock(int blockId) =>
      _send('DELETE', '/owner/blocks/$blockId');

  Future<BookingInbox> inbox() async =>
      BookingInbox.fromJson(await _send('GET', '/owner/bookings'));

  Future<void> decide(int bookingId, {required bool accept}) => _send(
    'POST',
    '/owner/bookings/$bookingId/${accept ? 'accept' : 'decline'}',
  );

  Future<void> setAutoConfirm(bool value) =>
      _send('PUT', '/owner/settings', body: {'autoConfirm': value});

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _readToken();
    if (token == null) {
      throw const StadiumApiException('Sign in to manage your stadiums.');
    }
    final request = http.Request(method, Uri.parse('$_baseUrl$path'))
      ..headers.addAll({
        'accept': 'application/json',
        'authorization': 'Bearer $token',
        if (body != null) 'content-type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      );
    } on TimeoutException {
      throw const StadiumApiException('The server took too long to answer.');
    } on Exception {
      throw const StadiumApiException(
        "Can't reach the Kickoff server. Check that the API is running.",
      );
    }
    if (response.statusCode == 204) return const {};

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic> ? decoded['error'] : null;
      throw StadiumApiException(
        message is String
            ? message
            : 'Request failed (${response.statusCode}).',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const StadiumApiException('The server sent an invalid response.');
    }
    return decoded;
  }
}
