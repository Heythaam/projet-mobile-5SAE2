import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/users/country_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final all = [
    {
      'cca2': 'TN',
      'name': {'common': 'Tunisia'},
      'flags': {'png': 'https://flagcdn.com/w320/tn.png'},
    },
    {
      'cca2': 'FR',
      'name': {'common': 'France'},
      'flags': {'png': 'https://flagcdn.com/w320/fr.png'},
    },
  ];

  test('flagEmoji builds the flag from the code', () {
    expect(flagEmoji('TN'), '🇹🇳');
    expect(flagEmoji('fr'), '🇫🇷');
    expect(flagEmoji('T'), '');
    expect(flagEmoji('T1'), '');
  });

  test('all() sorts by name and asks the API only once', () async {
    var calls = 0;
    Uri? seen;
    final service = CountryService(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        calls++;
        seen = request.url;
        return http.Response(jsonEncode(all), 200);
      }),
    );
    final first = await service.all();
    final second = await service.all();
    expect(first.map((c) => c.name), ['France', 'Tunisia']);
    expect(first.last.code, 'TN');
    expect(first.last.flagUrl, endsWith('tn.png'));
    expect(first.last.emoji, '🇹🇳');
    expect(identical(first, second), isTrue);
    expect(calls, 1);
    expect(seen?.path, '/all');
    expect(seen?.queryParameters['fields'], 'name,cca2,flags');
  });

  test('all() falls back to the built-in list when the API is offline', () async {
    final service = CountryService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final list = await service.all();
    expect(service.usingOfflineList, isTrue);
    expect(list.length, greaterThan(200));
    expect(list.any((c) => c.code == 'TN' && c.name == 'Tunisia'), isTrue);
  });

  test('all() falls back on a server error', () async {
    final service = CountryService(
      client: MockClient((_) async => http.Response('down', 503)),
    );
    expect((await service.all()).length, greaterThan(200));
    expect(service.usingOfflineList, isTrue);
  });

  test('all() reads a list wrapped in an object', () async {
    final service = CountryService(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'data': all}), 200),
      ),
    );
    expect((await service.all()).map((c) => c.name), ['France', 'Tunisia']);
    expect(service.usingOfflineList, isFalse);
  });

  test('all() falls back on an object without a list', () async {
    final service = CountryService(
      client: MockClient(
        (_) async => http.Response(jsonEncode({'message': 'bad'}), 200),
      ),
    );
    expect((await service.all()).length, greaterThan(200));
    expect(service.usingOfflineList, isTrue);
  });

  test('byCode reads one country and remembers it', () async {
    var calls = 0;
    final service = CountryService(
      baseUrl: 'http://api.test',
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/alpha/TN');
        return http.Response(jsonEncode(all.first), 200);
      }),
    );
    expect((await service.byCode('tn'))?.name, 'Tunisia');
    expect((await service.byCode('TN'))?.name, 'Tunisia');
    expect(calls, 1);
  });

  test('byCode uses the built-in name offline and tries again later', () async {
    var online = false;
    final service = CountryService(
      client: MockClient((_) async {
        if (!online) throw http.ClientException('offline');
        return http.Response(jsonEncode(all.first), 200);
      }),
    );
    final offline = await service.byCode('TN');
    expect(offline?.name, 'Tunisia');
    expect(offline?.flagUrl, isEmpty);
    expect(await service.byCode('ZZ'), isNull);
    online = true;
    expect((await service.byCode('TN'))?.flagUrl, isNotEmpty);
  });
}
