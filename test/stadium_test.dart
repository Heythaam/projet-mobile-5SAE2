import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_match_app/stadium/stadium_module.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> requests;
  late Map<String, Object? Function(http.Request)> routes;

  StadiumApi api() => StadiumApi(
    client: MockClient((request) async {
      requests.add(request);
      final key = '${request.method} ${request.url.path}';
      final handler = routes[key];
      if (handler == null) {
        return http.Response(jsonEncode({'error': 'No route $key'}), 404);
      }
      final body = handler(request);
      return body == null
          ? http.Response('', 204)
          : http.Response(
              jsonEncode(body),
              request.method == 'POST' ? 201 : 200,
            );
    }),
    readToken: () async => 'token',
    baseUrl: 'http://api',
  );

  setUp(() {
    requests = [];
    routes = {};
  });

  testWidgets('home shows totals and stadium cards', (tester) async {
    routes['GET /owner/stadiums'] = (_) => _overview([
      {..._stadium, 'todayBooked': 5, 'todaySlots': 12},
      {
        ..._stadium,
        'id': 2,
        'name': 'Parc Sud',
        'paused': true,
        'todayBooked': 0,
        'todaySlots': 0,
      },
    ], pending: 2);
    await tester.pumpWidget(_app(StadiumHomeScreen(api: api())));
    await tester.pumpAndSettle();

    expect(find.text('My stadiums'), findsOneWidget);
    expect(find.text('310'), findsOneWidget);
    expect(find.text('Arena Nord'), findsOneWidget);
    expect(find.text('5/12'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Add stadium'), findsOneWidget);
  });

  testWidgets('home explains an empty account and a failed load', (
    tester,
  ) async {
    routes['GET /owner/stadiums'] = (_) => _overview([]);
    await tester.pumpWidget(_app(StadiumHomeScreen(api: api())));
    await tester.pumpAndSettle();
    expect(find.text('No stadiums yet'), findsOneWidget);

    routes.clear();
    await tester.pumpWidget(
      _app(StadiumHomeScreen(api: api(), key: UniqueKey())),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your stadiums"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('wizard validates, edits pitches and publishes the stadium', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? posted;
    routes['POST /owner/stadiums'] = (request) {
      posted = jsonDecode(request.body) as Map<String, dynamic>;
      return {'stadium': _stadium};
    };
    Stadium? result;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Stadium>(
                MaterialPageRoute(
                  builder: (_) => StadiumEditorScreen(api: api()),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stadium_next')));
    await tester.pumpAndSettle();
    expect(find.text('Use 2-40 characters.'), findsOneWidget);
    expect(
      find.text('+216 numbers have 8 digits.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('stadium_name')),
      'Arena Nord',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stadium_phone')),
      '20123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stadium_address')),
      'Rue du Stade',
    );
    await tester.tap(find.byKey(const ValueKey('stadium_next')));
    await tester.pumpAndSettle();

    expect(find.text('Pitch A'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stadium_add_pitch')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('7v7'));
    await tester.tap(find.bySemanticsLabel('Indoor'));
    await tester.tap(find.byKey(const ValueKey('pitch_save')));
    await tester.pumpAndSettle();
    expect(find.text('Pitch B'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Showers'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Showers'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('stadium_next')));
    await tester.pumpAndSettle();
    expect(find.text('Open days'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Raise price'));
    await tester.pump();
    expect(find.text('65'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Sundays closed'));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('stadium_next')));
    await tester.pumpAndSettle();

    expect(posted, isNotNull);
    expect(posted!['name'], 'Arena Nord');
    expect(posted!['pricePerHour'], 65);
    expect(posted!['openDays'], 127);
    expect(posted!['features'], ['lights', 'showers']);
    expect(posted!['pitches'], [
      {'size': '5v5', 'surface': 'turf'},
      {'size': '7v7', 'surface': 'indoor'},
    ]);
    expect(result?.name, 'Arena Nord');
  });

  testWidgets('wizard shows the server error and stays on the last step', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        StadiumEditorScreen(api: api(), stadium: Stadium.fromJson(_stadium)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit stadium'), findsOneWidget);
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.byKey(const ValueKey('stadium_next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('No route PUT /owner/stadiums/1'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('availability shows slot states and blocks a free slot', (
    tester,
  ) async {
    var blocked = false;
    routes['GET /owner/stadiums/1/availability'] = (_) =>
        _availability(blocked);
    routes['POST /owner/stadiums/1/blocks'] = (request) {
      blocked = true;
      expect(jsonDecode(request.body)['start'], 18 * 60);
      return {'blockId': 9};
    };
    await tester.pumpWidget(
      _app(
        StadiumDetailScreen(api: api(), stadium: Stadium.fromJson(_stadium)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('16:00, free'), findsOneWidget);
    expect(find.bySemanticsLabel('17:00, booked by yassine'), findsOneWidget);
    expect(
      find.bySemanticsLabel('19:00, waiting for your answer'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('stadium_block_mode')));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('18:00, free'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('18:00, blocked'), findsOneWidget);
  });

  testWidgets('inbox accepts a pending booking', (tester) async {
    var accepted = false;
    routes['GET /owner/bookings'] = (_) => {
      'autoConfirm': false,
      'pending': accepted ? [] : [_booking('pending')],
      'confirmed': [_booking('confirmed', id: 8)],
    };
    routes['POST /owner/bookings/7/accept'] = (_) {
      accepted = true;
      return {'booking': _booking('confirmed')};
    };
    await tester.pumpWidget(_app(BookingsInboxScreen(api: api())));
    await tester.pumpAndSettle();

    expect(find.text('Waiting for you · 1'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Accept booking'));
    await tester.pumpAndSettle();
    expect(
      requests.any((r) => r.url.path == '/owner/bookings/7/accept'),
      isTrue,
    );
    expect(find.text('Waiting for you · 1'), findsNothing);
    expect(find.text('Booking accepted.'), findsOneWidget);
  });

  testWidgets('guests are asked to sign in', (tester) async {
    await tester.pumpWidget(_app(const StadiumModule(isGuest: true)));
    expect(find.text('Sign in to add a stadium'), findsOneWidget);
  });

  testWidgets('screens fit small phones with large text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    routes['GET /owner/stadiums'] = (_) => _overview([
      {
        ..._stadium,
        'name': 'A very long stadium name here',
        'todayBooked': 5,
        'todaySlots': 12,
      },
    ]);
    routes['GET /owner/stadiums/1/availability'] = (_) => _availability(false);
    routes['GET /owner/bookings'] = (_) => {
      'autoConfirm': true,
      'pending': [_booking('pending')],
      'confirmed': <Object?>[],
    };

    for (final screen in <Widget>[
      StadiumHomeScreen(api: api()),
      StadiumDetailScreen(api: api(), stadium: Stadium.fromJson(_stadium)),
      BookingsInboxScreen(api: api()),
      StadiumEditorScreen(api: api(), stadium: Stadium.fromJson(_stadium)),
    ]) {
      await tester.pumpWidget(_app(screen, textScale: 1.3, key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.byKey(const ValueKey('stadium_next')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'editor step ${step + 2}');
    }
  });
}

Widget _app(Widget home, {double textScale = 1, Key? key}) => MaterialApp(
  key: key,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: home,
);

const _stadium = <String, Object?>{
  'id': 1,
  'name': 'Arena Nord',
  'phone': '+216 20 123 456',
  'address': 'Rue du Stade',
  'features': ['lights'],
  'openDays': 127,
  'openMinute': 16 * 60,
  'closeMinute': 24 * 60,
  'slotMinutes': 60,
  'pricePerHour': 60,
  'eveningSurcharge': 20,
  'eveningFrom': 20 * 60,
  'paused': false,
  'pitches': [
    {'id': 11, 'name': 'A', 'size': '5v5', 'surface': 'turf'},
    {'id': 12, 'name': 'B', 'size': '7v7', 'surface': 'indoor'},
  ],
};

Map<String, Object?> _overview(
  List<Map<String, Object?>> stadiums, {
  int pending = 0,
}) => {
  'todayBookings': 5,
  'weekIncome': 310,
  'pendingBookings': pending,
  'stadiums': stadiums,
};

String _tomorrow() {
  final date = DateTime.now().add(const Duration(days: 1));
  return stadiumDay(date);
}

Map<String, Object?> _booking(String status, {int id = 7}) => {
  'id': id,
  'pitchId': 11,
  'date': _tomorrow(),
  'start': 19 * 60,
  'end': 20 * 60,
  'price': 60,
  'hostName': 'yassine',
  'status': status,
  'pitchName': 'A',
  'pitchSize': '5v5',
  'stadiumName': 'Arena Nord',
};

Map<String, Object?> _availability(bool blocked) => {
  'date': _tomorrow(),
  'open': true,
  'pitches': [
    {
      'id': 11,
      'name': 'A',
      'size': '5v5',
      'surface': 'turf',
      'slots': [
        {'start': 960, 'end': 1020, 'price': 60, 'state': 'free'},
        {
          'start': 1020,
          'end': 1080,
          'price': 60,
          'state': 'confirmed',
          'booking': _booking('confirmed'),
        },
        blocked
            ? {
                'start': 1080,
                'end': 1140,
                'price': 60,
                'state': 'blocked',
                'blockId': 9,
              }
            : {'start': 1080, 'end': 1140, 'price': 60, 'state': 'free'},
        {
          'start': 1140,
          'end': 1200,
          'price': 60,
          'state': 'pending',
          'booking': _booking('pending'),
        },
      ],
    },
    {
      'id': 12,
      'name': 'B',
      'size': '7v7',
      'surface': 'indoor',
      'slots': <Object?>[],
    },
  ],
};
