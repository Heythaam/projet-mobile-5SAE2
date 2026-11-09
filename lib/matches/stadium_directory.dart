import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// What the Match module needs from the Stadium module. It only uses the
/// stadium module's public API: list stadiums, read free slots, hold a slot and
/// release it.
abstract class StadiumDirectory {
  Future<List<RealStadium>> stadiums();
  Future<List<FreeSlot>> freeSlots(int stadiumId, DateTime day);

  /// Holds the slot for a match and returns the booking id.
  Future<int> hold({
    required int stadiumId,
    required int pitchId,
    required DateTime day,
    required int start,
    required String matchCode,
  });

  Future<void> release(int bookingId);
}

class StadiumDirectoryException implements Exception {
  const StadiumDirectoryException(this.message, {this.statusCode});

  final String message;

  /// The HTTP status when the server answered, null for network problems.
  final int? statusCode;

  @override
  String toString() => message;
}

class RealPitch {
  const RealPitch({required this.id, required this.name, required this.size});

  final int id;
  final String name;
  final String size;

  /// Players in a match on this pitch (both teams).
  int get capacity => switch (size) {
    '7v7' => 14,
    '11v11' => 22,
    _ => 10,
  };
}

class RealStadium {
  const RealStadium({
    required this.id,
    required this.name,
    required this.address,
    required this.pricePerHour,
    required this.pitches,
  });

  factory RealStadium.fromJson(Map<String, dynamic> json) => RealStadium(
    id: json['id'] as int,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    pricePerHour: json['pricePerHour'] as int? ?? 0,
    pitches: [
      for (final pitch in json['pitches'] as List<dynamic>? ?? const [])
        RealPitch(
          id: (pitch as Map<String, dynamic>)['id'] as int,
          name: pitch['name'] as String? ?? '',
          size: pitch['size'] as String? ?? '5v5',
        ),
    ],
  );

  final int id;
  final String name;
  final String address;
  final int pricePerHour;
  final List<RealPitch> pitches;

  int get maxCapacity => pitches.isEmpty
      ? 10
      : pitches.map((pitch) => pitch.capacity).reduce((a, b) => a > b ? a : b);
}

/// A free slot on one pitch.
class FreeSlot {
  const FreeSlot({
    required this.pitch,
    required this.start,
    required this.end,
    required this.price,
  });

  final RealPitch pitch;

  /// Minutes after midnight.
  final int start;
  final int end;
  final int price;

  String get startLabel =>
      '${(start ~/ 60).toString().padLeft(2, '0')}:'
      '${(start % 60).toString().padLeft(2, '0')}';
}

/// Talks to the Kickoff API with the signed-in player's token.
class HttpStadiumDirectory implements StadiumDirectory {
  HttpStadiumDirectory({
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

  @override
  Future<List<RealStadium>> stadiums() async {
    final json = await _send('GET', '/stadiums');
    return [
      for (final item in json['stadiums'] as List<dynamic>? ?? const [])
        RealStadium.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<FreeSlot>> freeSlots(int stadiumId, DateTime day) async {
    final json = await _send(
      'GET',
      '/stadiums/$stadiumId/slots?date=${_day(day)}',
    );
    if (json['open'] == false) return const [];
    final slots = <FreeSlot>[];
    for (final item in json['pitches'] as List<dynamic>? ?? const []) {
      final map = item as Map<String, dynamic>;
      final pitch = RealPitch(
        id: map['id'] as int,
        name: map['name'] as String? ?? '',
        size: map['size'] as String? ?? '5v5',
      );
      for (final raw in map['slots'] as List<dynamic>? ?? const []) {
        final slot = raw as Map<String, dynamic>;
        if (slot['state'] != 'free') continue;
        slots.add(
          FreeSlot(
            pitch: pitch,
            start: slot['start'] as int,
            end: slot['end'] as int,
            price: slot['price'] as int,
          ),
        );
      }
    }
    slots.sort((a, b) {
      final byTime = a.start.compareTo(b.start);
      return byTime != 0 ? byTime : a.pitch.name.compareTo(b.pitch.name);
    });
    return slots;
  }

  @override
  Future<int> hold({
    required int stadiumId,
    required int pitchId,
    required DateTime day,
    required int start,
    required String matchCode,
  }) async {
    final json = await _send(
      'POST',
      '/stadiums/$stadiumId/bookings',
      body: {
        'pitchId': pitchId,
        'date': _day(day),
        'start': start,
        'matchId': matchCode,
      },
    );
    return (json['booking'] as Map<String, dynamic>)['id'] as int;
  }

  @override
  Future<void> release(int bookingId) async {
    await _send('DELETE', '/stadium-bookings/$bookingId');
  }

  static String _day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final token = await _readToken();
    if (token == null) {
      throw const StadiumDirectoryException('Sign in to use real stadiums.');
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
      throw const StadiumDirectoryException(
        'The server took too long to answer.',
      );
    } on Exception {
      throw const StadiumDirectoryException(
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
      throw StadiumDirectoryException(
        message is String ? message : 'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const StadiumDirectoryException(
        'The server sent an invalid response.',
      );
    }
    return decoded;
  }
}
