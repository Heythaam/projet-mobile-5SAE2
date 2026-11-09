import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class Country {
  const Country({required this.code, required this.name, required this.flagUrl});

  factory Country.fromJson(Map<String, dynamic> json) => Country(
    code: (json['cca2'] as String).toUpperCase(),
    name: (json['name'] as Map<String, dynamic>)['common'] as String,
    flagUrl: (json['flags'] as Map<String, dynamic>?)?['png'] as String? ?? '',
  );

  /// Two-letter ISO code such as `TN`.
  final String code;
  final String name;
  final String flagUrl;

  String get emoji => flagEmoji(code);
}

/// The flag as an emoji, built from the two letter code. Works offline.
String flagEmoji(String code) {
  final upper = code.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(upper)) return '';
  return String.fromCharCodes([
    for (final unit in upper.codeUnits) 0x1F1A5 + unit,
  ]);
}

/// Countries and flags from the free REST Countries API (no key). The list is
/// kept in memory after the first answer.
class CountryService {
  CountryService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? 'https://restcountries.com/v3.1';

  final http.Client _client;
  final String _baseUrl;
  List<Country>? _cache;

  /// Every country, sorted by name. Throws [CountryException] when the API
  /// cannot be reached.
  Future<List<Country>> all() async {
    final cached = _cache;
    if (cached != null) return cached;
    final body = await _get('/all?fields=name,cca2,flags');
    final list = [
      for (final item in body as List<dynamic>)
        Country.fromJson(item as Map<String, dynamic>),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return _cache = list;
  }

  /// One country by its code, or null when the API does not know it or cannot
  /// be reached.
  Future<Country?> byCode(String code) {
    final upper = code.toUpperCase();
    final cached = _cache;
    if (cached != null) {
      for (final country in cached) {
        if (country.code == upper) return Future.value(country);
      }
    }
    // One request per code; a failed lookup is forgotten so it can retry.
    return _single.putIfAbsent(upper, () async {
      try {
        final body = await _get('/alpha/$upper?fields=name,cca2,flags');
        final map = body is List<dynamic> ? body.first : body;
        return Country.fromJson(map as Map<String, dynamic>);
      } on Object {
        _single.remove(upper);
        return null;
      }
    });
  }

  final _single = <String, Future<Country?>>{};

  Future<Object?> _get(String path) async {
    final http.Response response;
    try {
      response = await _client
          .get(Uri.parse('$_baseUrl$path'))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const CountryException('The country list took too long to load.');
    } on Exception {
      throw const CountryException(
        'Could not load the country list. Check your connection.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CountryException('Country list failed (${response.statusCode}).');
    }
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const CountryException('The country list was not readable.');
    }
  }
}

class CountryException implements Exception {
  const CountryException(this.message);

  final String message;

  @override
  String toString() => message;
}
