// Stadium module — app side.
//
// The whole client part of the Stadium module lives in this one file:
// models, the API client and every owner screen. The rest of the app only
// opens [StadiumModule] (from the profile menu). Server side lives in
// backend/lib/stadium.dart.
//
// Screens (matching the Kickoff stadium mockups):
//   1. My stadiums       [StadiumHomeScreen]
//   2-4. Add / edit      [StadiumEditorScreen] (basics, pitches, hours & price)
//   5. Availability      [StadiumDetailScreen]
//   6. Bookings inbox    [BookingsInboxScreen]

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../screens/kickoff_style.dart';

// ===========================================================================
// Constants
// ===========================================================================

const stadiumPitchSizes = ['5v5', '7v7', '11v11'];

const stadiumSurfaces = <String, (String, IconData)>{
  'turf': ('Turf', Icons.grass_rounded),
  'grass': ('Grass', Icons.park_rounded),
  'indoor': ('Indoor', Icons.roofing_rounded),
};

const stadiumFeatures = <String, (String, IconData)>{
  'lights': ('Lights', Icons.lightbulb_rounded),
  'showers': ('Showers', Icons.shower_rounded),
  'parking': ('Parking', Icons.local_parking_rounded),
  'cafe': ('Café', Icons.local_cafe_rounded),
};

const _slotLengths = [60, 90, 120];
const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _dayFullNames = [
  'Mondays',
  'Tuesdays',
  'Wednesdays',
  'Thursdays',
  'Fridays',
  'Saturdays',
  'Sundays',
];
const _maxPitches = 8;

abstract final class _C {
  static const green = Color(0xFF1FA25B);
  static const greenDark = Color(0xFF15703F);
  static const pending = KickoffColors.orange;
  static const pendingDark = Color(0xFFC46F1F);
}

// ===========================================================================
// Models
// ===========================================================================

class Pitch {
  const Pitch({
    required this.size,
    required this.surface,
    this.id,
    this.name = '',
  });

  factory Pitch.fromJson(Map<String, dynamic> json) => Pitch(
    id: json['id'] as int?,
    name: json['name'] as String? ?? '',
    size: json['size'] as String,
    surface: json['surface'] as String,
  );

  final int? id;
  final String name;
  final String size;
  final String surface;

  String get surfaceLabel => stadiumSurfaces[surface]?.$1 ?? surface;

  Map<String, Object?> toJson() => {
    if (id != null) 'id': id,
    'size': size,
    'surface': surface,
  };

  Pitch copyWith({String? size, String? surface, String? name}) => Pitch(
    id: id,
    name: name ?? this.name,
    size: size ?? this.size,
    surface: surface ?? this.surface,
  );
}

class Stadium {
  const Stadium({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.features,
    required this.openDays,
    required this.openMinute,
    required this.closeMinute,
    required this.slotMinutes,
    required this.pricePerHour,
    required this.eveningSurcharge,
    required this.eveningFrom,
    required this.paused,
    required this.pitches,
  });

  factory Stadium.fromJson(Map<String, dynamic> json) => Stadium(
    id: json['id'] as int,
    name: json['name'] as String,
    phone: json['phone'] as String,
    address: json['address'] as String,
    features: (json['features'] as List<dynamic>).cast<String>(),
    openDays: json['openDays'] as int,
    openMinute: json['openMinute'] as int,
    closeMinute: json['closeMinute'] as int,
    slotMinutes: json['slotMinutes'] as int,
    pricePerHour: json['pricePerHour'] as int,
    eveningSurcharge: json['eveningSurcharge'] as int,
    eveningFrom: json['eveningFrom'] as int? ?? 20 * 60,
    paused: json['paused'] as bool,
    pitches: (json['pitches'] as List<dynamic>)
        .map((item) => Pitch.fromJson(item as Map<String, dynamic>))
        .toList(),
  );

  final int id;
  final String name;
  final String phone;
  final String address;
  final List<String> features;
  final int openDays;
  final int openMinute;
  final int closeMinute;
  final int slotMinutes;
  final int pricePerHour;
  final int eveningSurcharge;
  final int eveningFrom;
  final bool paused;
  final List<Pitch> pitches;

  bool isOpenOn(DateTime day) => openDays & (1 << (day.weekday - 1)) != 0;
}

class StadiumSummary {
  const StadiumSummary({
    required this.stadium,
    required this.todayBooked,
    required this.todaySlots,
  });

  final Stadium stadium;
  final int todayBooked;
  final int todaySlots;
}

class StadiumOverview {
  const StadiumOverview({
    required this.todayBookings,
    required this.weekIncome,
    required this.pendingBookings,
    required this.stadiums,
  });

  factory StadiumOverview.fromJson(Map<String, dynamic> json) =>
      StadiumOverview(
        todayBookings: json['todayBookings'] as int,
        weekIncome: json['weekIncome'] as int,
        pendingBookings: json['pendingBookings'] as int,
        stadiums: (json['stadiums'] as List<dynamic>).map((item) {
          final map = item as Map<String, dynamic>;
          return StadiumSummary(
            stadium: Stadium.fromJson(map),
            todayBooked: map['todayBooked'] as int,
            todaySlots: map['todaySlots'] as int,
          );
        }).toList(),
      );

  final int todayBookings;
  final int weekIncome;
  final int pendingBookings;
  final List<StadiumSummary> stadiums;
}

class StadiumBooking {
  const StadiumBooking({
    required this.id,
    required this.pitchId,
    required this.date,
    required this.start,
    required this.end,
    required this.price,
    required this.hostName,
    required this.status,
    this.pitchName,
    this.pitchSize,
    this.stadiumName,
  });

  factory StadiumBooking.fromJson(Map<String, dynamic> json) => StadiumBooking(
    id: json['id'] as int,
    pitchId: json['pitchId'] as int,
    date: DateTime.parse(json['date'] as String),
    start: json['start'] as int,
    end: json['end'] as int,
    price: json['price'] as int,
    hostName: json['hostName'] as String,
    status: json['status'] as String,
    pitchName: json['pitchName'] as String?,
    pitchSize: json['pitchSize'] as String?,
    stadiumName: json['stadiumName'] as String?,
  );

  final int id;
  final int pitchId;
  final DateTime date;
  final int start;
  final int end;
  final int price;
  final String hostName;
  final String status;
  final String? pitchName;
  final String? pitchSize;
  final String? stadiumName;

  bool get isPending => status == 'pending';
}

enum SlotState { free, pending, confirmed, blocked, past }

class StadiumSlot {
  const StadiumSlot({
    required this.start,
    required this.end,
    required this.price,
    required this.state,
    this.booking,
    this.blockId,
  });

  factory StadiumSlot.fromJson(Map<String, dynamic> json) => StadiumSlot(
    start: json['start'] as int,
    end: json['end'] as int,
    price: json['price'] as int,
    state: switch (json['state']) {
      'pending' => SlotState.pending,
      'confirmed' => SlotState.confirmed,
      'blocked' => SlotState.blocked,
      'past' => SlotState.past,
      _ => SlotState.free,
    },
    booking: json['booking'] == null
        ? null
        : StadiumBooking.fromJson(json['booking'] as Map<String, dynamic>),
    blockId: json['blockId'] as int?,
  );

  final int start;
  final int end;
  final int price;
  final SlotState state;
  final StadiumBooking? booking;
  final int? blockId;
}

class PitchAvailability {
  const PitchAvailability({required this.pitch, required this.slots});

  final Pitch pitch;
  final List<StadiumSlot> slots;
}

class DayAvailability {
  const DayAvailability({required this.open, required this.pitches});

  factory DayAvailability.fromJson(Map<String, dynamic> json) =>
      DayAvailability(
        open: json['open'] as bool,
        pitches: (json['pitches'] as List<dynamic>).map((item) {
          final map = item as Map<String, dynamic>;
          return PitchAvailability(
            pitch: Pitch.fromJson(map),
            slots: (map['slots'] as List<dynamic>)
                .map(
                  (slot) => StadiumSlot.fromJson(slot as Map<String, dynamic>),
                )
                .toList(),
          );
        }).toList(),
      );

  final bool open;
  final List<PitchAvailability> pitches;
}

class BookingInbox {
  const BookingInbox({
    required this.autoConfirm,
    required this.pending,
    required this.confirmed,
  });

  factory BookingInbox.fromJson(Map<String, dynamic> json) {
    List<StadiumBooking> list(String key) => (json[key] as List<dynamic>)
        .map((item) => StadiumBooking.fromJson(item as Map<String, dynamic>))
        .toList();
    return BookingInbox(
      autoConfirm: json['autoConfirm'] as bool,
      pending: list('pending'),
      confirmed: list('confirmed'),
    );
  }

  final bool autoConfirm;
  final List<StadiumBooking> pending;
  final List<StadiumBooking> confirmed;
}

/// Everything the owner fills in while adding or editing a stadium.
class StadiumDraft {
  StadiumDraft({
    this.name = '',
    this.phone = '',
    this.address = '',
    List<Pitch>? pitches,
    Set<String>? features,
    this.openDays = 0x3F,
    this.openMinute = 16 * 60,
    this.closeMinute = 24 * 60,
    this.slotMinutes = 60,
    this.pricePerHour = 60,
    this.eveningSurcharge = 20,
  }) : pitches =
           pitches ?? [const Pitch(size: '5v5', surface: 'turf', name: 'A')],
       features = features ?? {'lights'};

  factory StadiumDraft.from(Stadium stadium) => StadiumDraft(
    name: stadium.name,
    phone: stadium.phone,
    address: stadium.address,
    pitches: [...stadium.pitches],
    features: {...stadium.features},
    openDays: stadium.openDays,
    openMinute: stadium.openMinute,
    closeMinute: stadium.closeMinute,
    slotMinutes: stadium.slotMinutes,
    pricePerHour: stadium.pricePerHour,
    eveningSurcharge: stadium.eveningSurcharge,
  );

  String name;
  String phone;
  String address;
  List<Pitch> pitches;
  Set<String> features;
  int openDays;
  int openMinute;
  int closeMinute;
  int slotMinutes;
  int pricePerHour;
  int eveningSurcharge;

  int get slotsPerDay => closeMinute - openMinute < slotMinutes
      ? 0
      : (closeMinute - openMinute) ~/ slotMinutes;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'features': [
      for (final key in stadiumFeatures.keys)
        if (features.contains(key)) key,
    ],
    'openDays': openDays,
    'openMinute': openMinute,
    'closeMinute': closeMinute,
    'slotMinutes': slotMinutes,
    'pricePerHour': pricePerHour,
    'eveningSurcharge': eveningSurcharge,
    'pitches': pitches.map((pitch) => pitch.toJson()).toList(),
  };
}

// ===========================================================================
// API
// ===========================================================================

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

// ===========================================================================
// Formatting
// ===========================================================================

String stadiumDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String stadiumTime(int minutes) {
  final value = minutes % (24 * 60);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';
}

String _slotLabel(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60}h' : '${minutes / 60}h';

String _shortDate(DateTime date) =>
    '${_dayNames[date.weekday - 1]} ${date.day}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _message(Object error) =>
    error is StadiumApiException ? error.message : 'Something went wrong.';

// ===========================================================================
// Entry point
// ===========================================================================

/// Opens the Stadium module. Guests see a sign-in prompt because every
/// stadium belongs to a real account on the API.
class StadiumModule extends StatelessWidget {
  const StadiumModule({
    this.api,
    this.isGuest = false,
    this.onSignIn,
    super.key,
  });

  final StadiumApi? api;
  final bool isGuest;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    if (!isGuest) return StadiumHomeScreen(api: api ?? StadiumApi());
    return _Page(
      title: 'My stadiums',
      icon: Icons.stadium_rounded,
      child: _StatusView(
        icon: Icons.lock_rounded,
        title: 'Sign in to add a stadium',
        message:
            'Stadiums, opening hours and bookings are saved to your account.',
        actionLabel: onSignIn == null ? null : 'Sign in',
        actionIcon: Icons.login_rounded,
        onAction: onSignIn == null
            ? null
            : () {
                Navigator.of(context).pop();
                onSignIn!();
              },
      ),
    );
  }
}

// ===========================================================================
// 1. My stadiums
// ===========================================================================

class StadiumHomeScreen extends StatefulWidget {
  const StadiumHomeScreen({required this.api, super.key});

  final StadiumApi api;

  @override
  State<StadiumHomeScreen> createState() => _StadiumHomeScreenState();
}

class _StadiumHomeScreenState extends State<StadiumHomeScreen> {
  StadiumOverview? _overview;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _overview == null;
      _error = null;
    });
    try {
      final overview = await widget.api.overview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final created = await Navigator.of(context).push<Stadium>(
      MaterialPageRoute(builder: (_) => StadiumEditorScreen(api: widget.api)),
    );
    if (created == null || !mounted) return;
    _toast(context, '${created.name} is live. Players can book it now.');
    await _load();
  }

  Future<void> _open(Stadium stadium) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StadiumDetailScreen(api: widget.api, stadium: stadium),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openInbox() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BookingsInboxScreen(api: widget.api)),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final overview = _overview;
    return _Page(
      title: 'My stadiums',
      icon: Icons.stadium_rounded,
      actions: [
        _BadgeButton(
          icon: Icons.event_note_rounded,
          label: 'Bookings',
          count: overview?.pendingBookings ?? 0,
          onPressed: _openInbox,
        ),
      ],
      bottom: overview == null
          ? null
          : ChunkyButton(
              key: const ValueKey('stadium_add'),
              label: 'Add stadium',
              icon: Icons.add_rounded,
              onPressed: _add,
            ),
      child: _loading
          ? const _Loading()
          : overview == null
          ? _StatusView(
              icon: Icons.wifi_off_rounded,
              title: "Couldn't load your stadiums",
              message: _error ?? '',
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: KickoffColors.ink,
              backgroundColor: KickoffColors.yellow,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  4 * scale,
                  16 * scale,
                  16 * scale,
                ),
                children: [
                  if (_error != null) ...[
                    _Banner(icon: Icons.wifi_off_rounded, text: _error!),
                    SizedBox(height: 10 * scale),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.event_available_rounded,
                          value: '${overview.todayBookings}',
                          label: 'today',
                        ),
                      ),
                      SizedBox(width: 10 * scale),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.payments_rounded,
                          value: '${overview.weekIncome}',
                          label: 'this week',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16 * scale),
                  if (overview.stadiums.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 24 * scale),
                      child: const _StatusView(
                        icon: Icons.stadium_rounded,
                        title: 'No stadiums yet',
                        message:
                            'Add your stadium, its pitches and opening hours. '
                            'Players will be able to book your free slots.',
                        compact: true,
                      ),
                    )
                  else
                    for (final summary in overview.stadiums) ...[
                      _StadiumCard(
                        summary: summary,
                        onTap: () => _open(summary.stadium),
                      ),
                      SizedBox(height: 10 * scale),
                    ],
                ],
              ),
            ),
    );
  }
}

class _StadiumCard extends StatelessWidget {
  const _StadiumCard({required this.summary, required this.onTap});

  final StadiumSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final stadium = summary.stadium;
    final paused = stadium.paused;
    final muted = paused ? KickoffColors.muted : Colors.white;
    return _ChunkyTile(
      color: paused ? KickoffColors.panel : KickoffColors.blue,
      edge: paused ? KickoffColors.panelDark : KickoffColors.blueDark,
      onTap: onTap,
      semanticLabel: '${stadium.name}${paused ? ', paused' : ''}',
      padding: EdgeInsets.all(10 * scale),
      child: Row(
        children: [
          _IconSquare(
            icon: paused ? Icons.pause_rounded : Icons.stadium_rounded,
            color: paused ? KickoffColors.field : _C.green,
            foreground: paused ? KickoffColors.muted : Colors.white,
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stadium.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    scale,
                    17,
                    color: muted,
                    weight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Wrap(
                  spacing: 12 * scale,
                  runSpacing: 2 * scale,
                  children: [
                    _IconText(
                      icon: Icons.grid_view_rounded,
                      text: '${stadium.pitches.length}',
                      color: paused ? KickoffColors.dim : KickoffColors.yellow,
                      textColor: muted,
                    ),
                    if (paused)
                      _IconText(
                        icon: Icons.lock_rounded,
                        text: 'Paused',
                        color: KickoffColors.yellow,
                        textColor: muted,
                      )
                    else
                      _IconText(
                        icon: Icons.event_available_rounded,
                        text: summary.todaySlots == 0
                            ? 'Closed today'
                            : '${summary.todayBooked}/${summary.todaySlots}',
                        color: KickoffColors.yellow,
                        textColor: muted,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: paused ? KickoffColors.dim : Colors.white,
            size: 24 * scale,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 2-4. Add / edit stadium
// ===========================================================================

class StadiumEditorScreen extends StatefulWidget {
  const StadiumEditorScreen({required this.api, this.stadium, super.key});

  final StadiumApi api;

  /// The stadium to edit, or null to add a new one.
  final Stadium? stadium;

  @override
  State<StadiumEditorScreen> createState() => _StadiumEditorScreenState();
}

class _StadiumEditorScreenState extends State<StadiumEditorScreen> {
  late final StadiumDraft _draft = widget.stadium == null
      ? StadiumDraft()
      : StadiumDraft.from(widget.stadium!);
  late final _name = TextEditingController(text: _draft.name);
  late final _phone = TextEditingController(text: _draft.phone);
  late final _address = TextEditingController(text: _draft.address);
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
  bool _busy = false;
  String? _stepError;

  bool get _editing => widget.stadium != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _back() {
    if (_busy) return;
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _step -= 1;
        _stepError = null;
      });
    }
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      _draft
        ..name = _name.text
        ..phone = _phone.text
        ..address = _address.text;
    }
    if (_step == 2) {
      final error = _hoursError();
      if (error != null) {
        setState(() => _stepError = error);
        return;
      }
      await _submit();
      return;
    }
    setState(() {
      _step += 1;
      _stepError = null;
    });
  }

  String? _hoursError() {
    if (_draft.openDays == 0) return 'Pick at least one open day.';
    if (_draft.slotsPerDay == 0) {
      return 'Opening hours must fit at least one '
          '${_slotLabel(_draft.slotMinutes)} slot.';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      final saved = _editing
          ? await widget.api.update(widget.stadium!.id, _draft)
          : await widget.api.create(_draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stepError = _message(error);
      });
    }
  }

  Future<void> _editPitch(int? index) async {
    final pitch = index == null
        ? const Pitch(size: '5v5', surface: 'turf')
        : _draft.pitches[index];
    final result = await showModalBottomSheet<_PitchEdit>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      shape: _sheetShape(context),
      builder: (_) => _PitchSheet(
        pitch: pitch,
        letter: String.fromCharCode(65 + (index ?? _draft.pitches.length)),
        canRemove: index != null && _draft.pitches.length > 1,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.remove) {
        _draft.pitches.removeAt(index!);
      } else if (index == null) {
        _draft.pitches.add(result.pitch);
      } else {
        _draft.pitches[index] = result.pitch;
      }
      _draft.pitches = [
        for (final (i, p) in _draft.pitches.indexed)
          p.copyWith(name: String.fromCharCode(65 + i)),
      ];
    });
  }

  Future<void> _pickTime({required bool opening}) async {
    final value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KickoffColors.panelDark,
      shape: _sheetShape(context),
      builder: (_) => _TimeSheet(
        title: opening ? 'Opens at' : 'Closes at',
        selected: opening ? _draft.openMinute : _draft.closeMinute,
        first: opening ? 0 : 30,
        last: opening ? 23 * 60 + 30 : 24 * 60,
      ),
    );
    if (value == null) return;
    setState(() {
      if (opening) {
        _draft.openMinute = value;
      } else {
        _draft.closeMinute = value;
      }
      _stepError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return PopScope(
      canPop: _step == 0 && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: _Page(
        title: _editing ? 'Edit stadium' : 'Add stadium',
        onBack: _back,
        header: Padding(
          padding: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 8 * scale),
          child: _Progress(step: _step, total: 3),
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stepError != null) ...[
              _Banner(
                icon: Icons.error_outline_rounded,
                text: _stepError!,
                error: true,
              ),
              SizedBox(height: 10 * scale),
            ],
            ChunkyButton(
              key: const ValueKey('stadium_next'),
              label: _step < 2
                  ? 'Next'
                  : _editing
                  ? 'Save changes'
                  : 'Publish stadium',
              icon: _step < 2
                  ? Icons.arrow_forward_rounded
                  : Icons.check_rounded,
              busy: _busy,
              onPressed: _busy ? null : _next,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_step),
            child: switch (_step) {
              0 => _basicsStep(scale),
              1 => _pitchesStep(scale),
              _ => _hoursStep(scale),
            },
          ),
        ),
      ),
    );
  }

  Widget _basicsStep(double scale) => Form(
    key: _formKey,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        8 * scale,
        16 * scale,
        16 * scale,
      ),
      children: [
        _StepTitle(
          title: 'Your stadium',
          subtitle: 'Players see this when they pick where to play.',
        ),
        SizedBox(height: 14 * scale),
        PillField(
          key: const ValueKey('stadium_name'),
          controller: _name,
          hint: 'Stadium name',
          icon: Icons.stadium_rounded,
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 2 || text.length > 40) {
              return 'Use 2-40 characters.';
            }
            return null;
          },
        ),
        SizedBox(height: 12 * scale),
        PillField(
          key: const ValueKey('stadium_phone'),
          controller: _phone,
          hint: 'Contact number',
          icon: Icons.call_rounded,
          keyboardType: TextInputType.phone,
          validator: (value) =>
              RegExp(r'^\+?[0-9 ]{6,20}$').hasMatch(value?.trim() ?? '')
              ? null
              : 'Enter a phone number (digits, spaces, +).',
        ),
        SizedBox(height: 12 * scale),
        PillField(
          key: const ValueKey('stadium_address'),
          controller: _address,
          hint: 'Address or area',
          icon: Icons.place_rounded,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.length < 3 || text.length > 80) {
              return 'Use 3-80 characters.';
            }
            return null;
          },
        ),
      ],
    ),
  );

  Widget _pitchesStep(double scale) => ListView(
    padding: EdgeInsets.fromLTRB(16 * scale, 8 * scale, 16 * scale, 16 * scale),
    children: [
      _StepTitle(
        title: 'Pitches',
        subtitle: 'Each pitch can be booked on its own.',
      ),
      SizedBox(height: 12 * scale),
      for (final (index, pitch) in _draft.pitches.indexed) ...[
        _ChunkyTile(
          color: KickoffColors.blue,
          edge: KickoffColors.blueDark,
          onTap: () => _editPitch(index),
          semanticLabel: 'Edit pitch ${pitch.name}',
          padding: EdgeInsets.all(10 * scale),
          child: Row(
            children: [
              _IconSquare(letter: pitch.name, color: _C.green),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pitch ${pitch.name}',
                      style: _text(scale, 17, weight: FontWeight.w600),
                    ),
                    SizedBox(height: 2 * scale),
                    Row(
                      children: [
                        Text(pitch.size, style: _text(scale, 14)),
                        SizedBox(width: 10 * scale),
                        Flexible(
                          child: _IconText(
                            icon: stadiumSurfaces[pitch.surface]!.$2,
                            text: pitch.surfaceLabel,
                            color: KickoffColors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: Colors.white, size: 22 * scale),
            ],
          ),
        ),
        SizedBox(height: 10 * scale),
      ],
      if (_draft.pitches.length < _maxPitches)
        _DashedAdd(
          key: const ValueKey('stadium_add_pitch'),
          label: 'Add pitch',
          onTap: () => _editPitch(null),
        ),
      SizedBox(height: 22 * scale),
      _StepTitle(title: 'Features', subtitle: 'What players get on site.'),
      SizedBox(height: 12 * scale),
      Row(
        children: [
          for (final (index, entry) in stadiumFeatures.entries.indexed) ...[
            if (index > 0) SizedBox(width: 8 * scale),
            Expanded(
              child: _FeatureTile(
                label: entry.value.$1,
                icon: entry.value.$2,
                selected: _draft.features.contains(entry.key),
                onTap: () => setState(() {
                  if (!_draft.features.remove(entry.key)) {
                    _draft.features.add(entry.key);
                  }
                }),
              ),
            ),
          ],
        ],
      ),
    ],
  );

  Widget _hoursStep(double scale) {
    final eveningPrice =
        (_draft.pricePerHour * (1 + _draft.eveningSurcharge / 100)).round();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16 * scale,
        8 * scale,
        16 * scale,
        16 * scale,
      ),
      children: [
        _StepTitle(
          title: 'Open days',
          subtitle: 'Tap a day to open or close it.',
        ),
        SizedBox(height: 12 * scale),
        Row(
          children: [
            for (var day = 0; day < 7; day++) ...[
              if (day > 0) SizedBox(width: 6 * scale),
              Expanded(
                child: _DayToggle(
                  letter: _dayLetters[day],
                  name: _dayFullNames[day],
                  selected: _draft.openDays & (1 << day) != 0,
                  onTap: () => setState(() {
                    _draft.openDays ^= 1 << day;
                    _stepError = null;
                  }),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 20 * scale),
        _StepTitle(title: 'Opening hours'),
        SizedBox(height: 10 * scale),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Opens',
                value: stadiumTime(_draft.openMinute),
                onTap: () => _pickTime(opening: true),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: KickoffColors.muted,
                size: 22 * scale,
              ),
            ),
            Expanded(
              child: _TimeButton(
                label: 'Closes',
                value: stadiumTime(_draft.closeMinute),
                onTap: () => _pickTime(opening: false),
              ),
            ),
          ],
        ),
        SizedBox(height: 12 * scale),
        Row(
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              color: KickoffColors.yellow,
              size: 22 * scale,
            ),
            SizedBox(width: 10 * scale),
            for (final length in _slotLengths) ...[
              _Pill(
                label: _slotLabel(length),
                selected: _draft.slotMinutes == length,
                onTap: () => setState(() {
                  _draft.slotMinutes = length;
                  _stepError = null;
                }),
              ),
              SizedBox(width: 8 * scale),
            ],
          ],
        ),
        SizedBox(height: 20 * scale),
        _StepTitle(title: 'Price'),
        SizedBox(height: 10 * scale),
        _Panel(
          child: Row(
            children: [
              _RoundAction(
                icon: Icons.remove_rounded,
                label: 'Lower price',
                onTap: _draft.pricePerHour > 5
                    ? () => setState(() => _draft.pricePerHour -= 5)
                    : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_rounded,
                          color: KickoffColors.yellow,
                          size: 24 * scale,
                        ),
                        SizedBox(width: 6 * scale),
                        Text(
                          '${_draft.pricePerHour}',
                          key: const ValueKey('stadium_price'),
                          style: _text(scale, 28, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Text(
                      'per hour',
                      style: _text(scale, 13, color: KickoffColors.muted),
                    ),
                  ],
                ),
              ),
              _RoundAction(
                icon: Icons.add_rounded,
                label: 'Raise price',
                onTap: _draft.pricePerHour < 10000
                    ? () => setState(() => _draft.pricePerHour += 5)
                    : null,
              ),
            ],
          ),
        ),
        SizedBox(height: 10 * scale),
        _Panel(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.nightlight_round,
                    color: KickoffColors.yellow,
                    size: 24 * scale,
                  ),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Text(
                      _draft.eveningSurcharge == 0
                          ? 'Evening surcharge'
                          : '+${_draft.eveningSurcharge}% after 20:00',
                      style: _text(scale, 16, weight: FontWeight.w600),
                    ),
                  ),
                  _KickoffSwitch(
                    label: 'Evening surcharge',
                    value: _draft.eveningSurcharge > 0,
                    onChanged: (on) =>
                        setState(() => _draft.eveningSurcharge = on ? 20 : 0),
                  ),
                ],
              ),
              if (_draft.eveningSurcharge > 0) ...[
                SizedBox(height: 8 * scale),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Evening slots cost $eveningPrice per hour',
                        style: _text(scale, 14, color: KickoffColors.muted),
                      ),
                    ),
                    _RoundAction(
                      icon: Icons.remove_rounded,
                      label: 'Lower surcharge',
                      small: true,
                      onTap: _draft.eveningSurcharge > 5
                          ? () => setState(() => _draft.eveningSurcharge -= 5)
                          : null,
                    ),
                    SizedBox(width: 6 * scale),
                    _RoundAction(
                      icon: Icons.add_rounded,
                      label: 'Raise surcharge',
                      small: true,
                      onTap: _draft.eveningSurcharge < 100
                          ? () => setState(() => _draft.eveningSurcharge += 5)
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 14 * scale),
        Text(
          _draft.slotsPerDay == 0
              ? 'No slot fits these hours yet.'
              : '${_draft.slotsPerDay} slots a day on each pitch · '
                    '${_draft.pitches.length} '
                    '${_draft.pitches.length == 1 ? 'pitch' : 'pitches'}',
          textAlign: TextAlign.center,
          style: _text(scale, 14, color: KickoffColors.muted),
        ),
      ],
    );
  }
}

class _PitchEdit {
  const _PitchEdit(this.pitch, {this.remove = false});

  final Pitch pitch;
  final bool remove;
}

class _PitchSheet extends StatefulWidget {
  const _PitchSheet({
    required this.pitch,
    required this.letter,
    required this.canRemove,
  });

  final Pitch pitch;
  final String letter;
  final bool canRemove;

  @override
  State<_PitchSheet> createState() => _PitchSheetState();
}

class _PitchSheetState extends State<_PitchSheet> {
  late String _size = widget.pitch.size;
  late String _surface = widget.pitch.surface;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return _SheetBody(
      title: 'Pitch ${widget.letter}',
      children: [
        Text('Size', style: _text(scale, 14, color: KickoffColors.muted)),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            for (final size in stadiumPitchSizes)
              _Pill(
                label: size,
                selected: _size == size,
                onTap: () => setState(() => _size = size),
              ),
          ],
        ),
        SizedBox(height: 16 * scale),
        Text('Surface', style: _text(scale, 14, color: KickoffColors.muted)),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: [
            for (final entry in stadiumSurfaces.entries)
              _Pill(
                label: entry.value.$1,
                icon: entry.value.$2,
                selected: _surface == entry.key,
                onTap: () => setState(() => _surface = entry.key),
              ),
          ],
        ),
        SizedBox(height: 20 * scale),
        ChunkyButton(
          key: const ValueKey('pitch_save'),
          label: 'Save pitch',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(
            _PitchEdit(widget.pitch.copyWith(size: _size, surface: _surface)),
          ),
        ),
        if (widget.canRemove) ...[
          SizedBox(height: 8 * scale),
          _TextAction(
            label: 'Remove pitch',
            icon: Icons.delete_outline_rounded,
            color: const Color(0xFFFFB7AB),
            onTap: () =>
                Navigator.of(context)
                    .pop(_PitchEdit(widget.pitch, remove: true)),
          ),
        ],
      ],
    );
  }
}

class _TimeSheet extends StatelessWidget {
  const _TimeSheet({
    required this.title,
    required this.selected,
    required this.first,
    required this.last,
  });

  final String title;
  final int selected;
  final int first;
  final int last;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final times = [for (var m = first; m <= last; m += 30) m];
    return _SheetBody(
      title: title,
      maxHeightFactor: 0.7,
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8 * scale,
          crossAxisSpacing: 8 * scale,
          childAspectRatio: 1.6,
          children: [
            for (final minute in times)
              _Pill(
                label: stadiumTime(minute),
                selected: minute == selected,
                expand: true,
                onTap: () => Navigator.of(context).pop(minute),
              ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// 5. Availability
// ===========================================================================

class StadiumDetailScreen extends StatefulWidget {
  const StadiumDetailScreen({
    required this.api,
    required this.stadium,
    super.key,
  });

  final StadiumApi api;
  final Stadium stadium;

  @override
  State<StadiumDetailScreen> createState() => _StadiumDetailScreenState();
}

class _StadiumDetailScreenState extends State<StadiumDetailScreen> {
  late Stadium _stadium = widget.stadium;
  final DateTime _today = _dateOnly(DateTime.now());
  late DateTime _day = _today;
  int _pitch = 0;
  DayAvailability? _data;
  String? _error;
  bool _loading = true;
  bool _blockMode = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final day = _day;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.availability(_stadium.id, day);
      if (!mounted || day != _day) return;
      setState(() {
        _data = data;
        _loading = false;
        _pitch = _pitch.clamp(0, (data.pitches.length - 1).clamp(0, 99));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  void _selectDay(DateTime day) {
    if (day == _day) return;
    setState(() {
      _day = day;
      _data = null;
    });
    _load();
  }

  Future<void> _tapSlot(PitchAvailability pitch, StadiumSlot slot) async {
    if (_busy.contains(slot.start)) return;
    if (_blockMode) {
      if (slot.state == SlotState.free) {
        await _run(slot.start, () {
          return widget.api.block(
            _stadium.id,
            pitch.pitch.id!,
            _day,
            slot.start,
          );
        });
      } else if (slot.state == SlotState.blocked && slot.blockId != null) {
        await _run(slot.start, () => widget.api.unblock(slot.blockId!));
      } else if (slot.state == SlotState.past) {
        _toast(context, 'That slot has already passed.');
      } else {
        _toast(context, 'Booked slots cannot be blocked.');
      }
      return;
    }
    switch (slot.state) {
      case SlotState.pending:
      case SlotState.confirmed:
        await _showBooking(pitch, slot);
      case SlotState.blocked:
        _toast(context, 'Blocked. Tap “Block a slot” to reopen it.');
      case SlotState.free:
        _toast(context, 'Free to book. Tap “Block a slot” to close it.');
      case SlotState.past:
        break;
    }
  }

  Future<void> _run(int start, Future<void> Function() action) async {
    setState(() => _busy.add(start));
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) _toast(context, _message(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(start));
    }
  }

  Future<void> _showBooking(PitchAvailability pitch, StadiumSlot slot) async {
    final booking = slot.booking;
    if (booking == null) return;
    final decision = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: KickoffColors.panelDark,
      shape: _sheetShape(context),
      builder: (context) => _BookingSheet(
        booking: booking,
        pitchLabel: 'Pitch ${pitch.pitch.name} · ${pitch.pitch.size}',
      ),
    );
    if (decision == null) return;
    await _run(
      slot.start,
      () => widget.api.decide(booking.id, accept: decision),
    );
    if (mounted) {
      _toast(context, decision ? 'Booking accepted.' : 'Booking declined.');
    }
  }

  Future<void> _manage() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KickoffColors.panelDark,
      shape: _sheetShape(context),
      builder: (context) => _SheetBody(
        title: _stadium.name,
        children: [
          _SheetOption(
            icon: Icons.edit_rounded,
            label: 'Edit details',
            onTap: () => Navigator.of(context).pop('edit'),
          ),
          _SheetOption(
            icon: _stadium.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            label: _stadium.paused ? 'Resume bookings' : 'Pause bookings',
            onTap: () => Navigator.of(context).pop('pause'),
          ),
          _SheetOption(
            icon: Icons.delete_outline_rounded,
            label: 'Delete stadium',
            color: const Color(0xFFFFB7AB),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'edit':
        final saved = await Navigator.of(context).push<Stadium>(
          MaterialPageRoute(
            builder: (_) =>
                StadiumEditorScreen(api: widget.api, stadium: _stadium),
          ),
        );
        if (saved == null || !mounted) return;
        setState(() => _stadium = saved);
        _toast(context, 'Changes saved.');
        await _load();
      case 'pause':
        await _togglePause();
      case 'delete':
        await _delete();
    }
  }

  Future<void> _togglePause() async {
    try {
      final updated = await widget.api.setPaused(_stadium.id, !_stadium.paused);
      if (!mounted) return;
      setState(() => _stadium = updated);
      _toast(
        context,
        updated.paused
            ? 'Paused. Players can’t book ${updated.name} for now.'
            : '${updated.name} is taking bookings again.',
      );
    } catch (error) {
      if (mounted) _toast(context, _message(error), error: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scale = kickoffScale(context);
        return AlertDialog(
          backgroundColor: KickoffColors.panelDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22 * scale),
          ),
          title: Text(
            'Delete ${_stadium.name}?',
            style: _text(scale, 19, weight: FontWeight.w600),
          ),
          content: Text(
            'Its pitches, hours and blocked slots are removed. '
            'This cannot be undone.',
            style: _text(scale, 15, color: KickoffColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Keep it', style: _text(scale, 15)),
            ),
            TextButton(
              key: const ValueKey('stadium_confirm_delete'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: _text(
                  scale,
                  15,
                  color: const Color(0xFFFFB7AB),
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.delete(_stadium.id);
      if (!mounted) return;
      _toast(context, '${_stadium.name} was deleted.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) _toast(context, _message(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final data = _data;
    final pitch = data == null || data.pitches.isEmpty
        ? null
        : data.pitches[_pitch];
    return _Page(
      title: _stadium.name,
      actions: [
        RoundIconButton(
          icon: Icons.settings_rounded,
          label: 'Manage stadium',
          onPressed: _manage,
        ),
      ],
      bottom: data == null || !data.open
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The hint sits above the button so the slot grid never
                // jumps when block mode turns on.
                if (_blockMode) ...[
                  const _Banner(
                    icon: Icons.touch_app_rounded,
                    text:
                        'Tap free slots to block them. '
                        'Tap a locked slot to free it.',
                  ),
                  SizedBox(height: 10 * scale),
                ],
                ChunkyButton(
                  key: const ValueKey('stadium_block_mode'),
                  label: _blockMode ? 'Done' : 'Block a slot',
                  icon: _blockMode ? Icons.check_rounded : Icons.lock_rounded,
                  backgroundColor: _blockMode
                      ? KickoffColors.blue
                      : KickoffColors.yellow,
                  bottomColor: _blockMode
                      ? KickoffColors.blueDark
                      : KickoffColors.yellowDark,
                  foregroundColor: _blockMode
                      ? Colors.white
                      : KickoffColors.ink,
                  onPressed: () => setState(() => _blockMode = !_blockMode),
                ),
              ],
            ),
      child: RefreshIndicator(
        color: KickoffColors.ink,
        backgroundColor: KickoffColors.yellow,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16 * scale,
            4 * scale,
            16 * scale,
            16 * scale,
          ),
          children: [
            if (_stadium.paused) ...[
              _Banner(
                icon: Icons.pause_circle_rounded,
                text: 'Paused. Players can’t book this stadium.',
                actionLabel: 'Resume',
                onAction: _togglePause,
              ),
              SizedBox(height: 12 * scale),
            ],
            if (_stadium.pitches.length > 1 || (data?.pitches.length ?? 0) > 1)
              Padding(
                padding: EdgeInsets.only(bottom: 12 * scale),
                child: Row(
                  children: [
                    for (final (index, item)
                        in (data?.pitches.map((p) => p.pitch) ??
                                _stadium.pitches)
                            .indexed) ...[
                      _LetterChip(
                        letter: item.name,
                        label: 'Pitch ${item.name}, ${item.size}',
                        selected: index == _pitch,
                        onTap: () => setState(() => _pitch = index),
                      ),
                      SizedBox(width: 8 * scale),
                    ],
                    const Spacer(),
                    if (pitch != null)
                      Text(
                        '${pitch.pitch.size} · ${pitch.pitch.surfaceLabel}',
                        style: _text(scale, 14, color: KickoffColors.muted),
                      ),
                  ],
                ),
              ),
            _DayStrip(
              today: _today,
              selected: _day,
              isOpen: _stadium.isOpenOn,
              onSelect: _selectDay,
            ),
            SizedBox(height: 14 * scale),
            if (_loading && data == null)
              Padding(
                padding: EdgeInsets.only(top: 40 * scale),
                child: const _Loading(),
              )
            else if (data == null)
              _StatusView(
                icon: Icons.wifi_off_rounded,
                title: "Couldn't load this day",
                message: _error ?? '',
                actionLabel: 'Try again',
                onAction: _load,
                compact: true,
              )
            else if (!data.open)
              _StatusView(
                icon: Icons.event_busy_rounded,
                title: 'Closed on ${_dayFullNames[_day.weekday - 1]}',
                message: 'Open this day from Manage → Edit details.',
                compact: true,
              )
            else if (pitch != null) ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 8 * scale,
                crossAxisSpacing: 8 * scale,
                childAspectRatio: 1.75,
                children: [
                  for (final slot in pitch.slots)
                    _SlotTile(
                      slot: slot,
                      busy: _busy.contains(slot.start),
                      onTap: () => _tapSlot(pitch, slot),
                    ),
                ],
              ),
              SizedBox(height: 14 * scale),
              const _Legend(),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.slot,
    required this.busy,
    required this.onTap,
  });

  final StadiumSlot slot;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final (
      Color color,
      Color edge,
      Color fg,
      IconData? icon,
      String state,
    ) = switch (slot.state) {
      SlotState.free => (
        KickoffColors.blue,
        KickoffColors.blueDark,
        Colors.white,
        null,
        'free',
      ),
      SlotState.confirmed => (
        KickoffColors.yellow,
        KickoffColors.yellowDark,
        KickoffColors.ink,
        Icons.person_rounded,
        'booked by ${slot.booking?.hostName ?? 'a player'}',
      ),
      SlotState.pending => (
        _C.pending,
        _C.pendingDark,
        KickoffColors.ink,
        Icons.hourglass_top_rounded,
        'waiting for your answer',
      ),
      SlotState.blocked => (
        KickoffColors.panelDark,
        KickoffColors.panelDark,
        KickoffColors.dim,
        Icons.lock_rounded,
        'blocked',
      ),
      SlotState.past => (
        KickoffColors.panel.withValues(alpha: 0.45),
        Colors.transparent,
        KickoffColors.dim,
        null,
        'past',
      ),
    };
    return Semantics(
      button: slot.state != SlotState.past,
      label: '${stadiumTime(slot.start)}, $state',
      excludeSemantics: true,
      child: _ChunkyTile(
        color: color,
        edge: edge,
        onTap: onTap,
        radius: 14,
        edgeWidth: slot.state == SlotState.past ? 0 : 3,
        child: Center(
          child: busy
              ? SizedBox(
                  width: 18 * scale,
                  height: 18 * scale,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 16 * scale, color: fg),
                        SizedBox(width: 3 * scale),
                      ],
                      Text(
                        stadiumTime(slot.start),
                        style: _text(
                          scale,
                          16,
                          color: fg,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12 * scale,
          height: 12 * scale,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4 * scale),
          ),
        ),
        SizedBox(width: 5 * scale),
        Text(label, style: _text(scale, 13, color: KickoffColors.muted)),
      ],
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14 * scale,
      runSpacing: 6 * scale,
      children: [
        item(KickoffColors.blue, 'Free'),
        item(KickoffColors.yellow, 'Booked'),
        item(_C.pending, 'Pending'),
        item(KickoffColors.panelDark, 'Blocked'),
      ],
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.today,
    required this.selected,
    required this.isOpen,
    required this.onSelect,
  });

  final DateTime today;
  final DateTime selected;
  final bool Function(DateTime day) isOpen;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final days = [
      for (var i = 0; i < 14; i++)
        DateTime(today.year, today.month, today.day + i),
    ];
    return SizedBox(
      height: 72 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => SizedBox(width: 4 * scale),
        itemBuilder: (context, index) {
          final day = days[index];
          final active = day == selected;
          final open = isOpen(day);
          final color = active
              ? KickoffColors.ink
              : open
              ? Colors.white
              : KickoffColors.dim;
          return Semantics(
            button: true,
            selected: active,
            label:
                '${_dayFullNames[day.weekday - 1]} ${day.day}${open ? '' : ', closed'}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onSelect(day),
              borderRadius: BorderRadius.circular(24 * scale),
              child: Container(
                width: 48 * scale,
                decoration: BoxDecoration(
                  color: active ? KickoffColors.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(24 * scale),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _dayLetters[day.weekday - 1],
                      style: _text(
                        scale,
                        13,
                        color: active ? KickoffColors.ink : KickoffColors.muted,
                      ),
                    ),
                    SizedBox(height: 2 * scale),
                    Text(
                      '${day.day}',
                      style: _text(
                        scale,
                        18,
                        color: color,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BookingSheet extends StatelessWidget {
  const _BookingSheet({required this.booking, required this.pitchLabel});

  final StadiumBooking booking;
  final String pitchLabel;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return _SheetBody(
      title: booking.isPending ? 'Booking request' : 'Confirmed booking',
      children: [
        _InfoRow(icon: Icons.person_rounded, text: booking.hostName),
        _InfoRow(icon: Icons.grid_view_rounded, text: pitchLabel),
        _InfoRow(
          icon: Icons.schedule_rounded,
          text:
              '${_shortDate(booking.date)} · ${stadiumTime(booking.start)}–'
              '${stadiumTime(booking.end)}',
        ),
        _InfoRow(icon: Icons.payments_rounded, text: '${booking.price}'),
        if (booking.isPending) ...[
          SizedBox(height: 16 * scale),
          Row(
            children: [
              Expanded(
                child: ChunkyButton(
                  label: 'Decline',
                  icon: Icons.close_rounded,
                  backgroundColor: KickoffColors.red,
                  bottomColor: KickoffColors.redDark,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              SizedBox(width: 10 * scale),
              Expanded(
                child: ChunkyButton(
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ===========================================================================
// 6. Bookings inbox
// ===========================================================================

class BookingsInboxScreen extends StatefulWidget {
  const BookingsInboxScreen({required this.api, super.key});

  final StadiumApi api;

  @override
  State<BookingsInboxScreen> createState() => _BookingsInboxScreenState();
}

class _BookingsInboxScreenState extends State<BookingsInboxScreen> {
  BookingInbox? _inbox;
  String? _error;
  bool _loading = true;
  bool _savingAuto = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _inbox == null;
      _error = null;
    });
    try {
      final inbox = await widget.api.inbox();
      if (!mounted) return;
      setState(() {
        _inbox = inbox;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _setAuto(bool value) async {
    final inbox = _inbox;
    if (inbox == null || _savingAuto) return;
    setState(() {
      _savingAuto = true;
      _inbox = BookingInbox(
        autoConfirm: value,
        pending: inbox.pending,
        confirmed: inbox.confirmed,
      );
    });
    try {
      await widget.api.setAutoConfirm(value);
      if (mounted) {
        _toast(
          context,
          value
              ? 'New bookings will be confirmed automatically.'
              : 'You’ll approve each new booking.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _inbox = inbox);
      _toast(context, _message(error), error: true);
    } finally {
      if (mounted) setState(() => _savingAuto = false);
    }
  }

  Future<void> _decide(StadiumBooking booking, bool accept) async {
    setState(() => _busy.add(booking.id));
    try {
      await widget.api.decide(booking.id, accept: accept);
      await _load();
      if (mounted) {
        _toast(context, accept ? 'Booking accepted.' : 'Booking declined.');
      }
    } catch (error) {
      if (mounted) _toast(context, _message(error), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(booking.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final inbox = _inbox;
    return _Page(
      title: 'Bookings',
      icon: Icons.event_note_rounded,
      child: _loading
          ? const _Loading()
          : inbox == null
          ? _StatusView(
              icon: Icons.wifi_off_rounded,
              title: "Couldn't load bookings",
              message: _error ?? '',
              actionLabel: 'Try again',
              onAction: _load,
            )
          : RefreshIndicator(
              color: KickoffColors.ink,
              backgroundColor: KickoffColors.yellow,
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  4 * scale,
                  16 * scale,
                  24 * scale,
                ),
                children: [
                  _Panel(
                    child: Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          color: KickoffColors.yellow,
                          size: 26 * scale,
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-confirm',
                                style: _text(
                                  scale,
                                  16,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Accept new bookings without asking you',
                                style: _text(
                                  scale,
                                  13,
                                  color: KickoffColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _KickoffSwitch(
                          label: 'Auto-confirm',
                          value: inbox.autoConfirm,
                          onChanged: _setAuto,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16 * scale),
                  if (inbox.pending.isEmpty && inbox.confirmed.isEmpty)
                    const _StatusView(
                      icon: Icons.inbox_rounded,
                      title: 'No bookings yet',
                      message:
                          'When players reserve one of your free slots, '
                          'the request shows up here.',
                      compact: true,
                    ),
                  if (inbox.pending.isNotEmpty) ...[
                    _SectionLabel('Waiting for you · ${inbox.pending.length}'),
                    for (final booking in inbox.pending) ...[
                      _BookingCard(
                        booking: booking,
                        busy: _busy.contains(booking.id),
                        onDecline: () => _decide(booking, false),
                        onAccept: () => _decide(booking, true),
                      ),
                      SizedBox(height: 10 * scale),
                    ],
                    SizedBox(height: 6 * scale),
                  ],
                  if (inbox.confirmed.isNotEmpty) ...[
                    _SectionLabel('Confirmed'),
                    for (final booking in inbox.confirmed) ...[
                      _BookingCard(booking: booking),
                      SizedBox(height: 10 * scale),
                    ],
                  ],
                ],
              ),
            ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    this.busy = false,
    this.onDecline,
    this.onAccept,
  });

  final StadiumBooking booking;
  final bool busy;
  final VoidCallback? onDecline;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final pending = booking.isPending;
    return _ChunkyTile(
      color: pending ? KickoffColors.blue : KickoffColors.panel,
      edge: pending ? KickoffColors.blueDark : KickoffColors.panelDark,
      padding: EdgeInsets.fromLTRB(
        12 * scale,
        10 * scale,
        8 * scale,
        10 * scale,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58 * scale,
            child: Column(
              children: [
                Text(
                  stadiumTime(booking.start),
                  style: _text(scale, 18, weight: FontWeight.w600),
                ),
                Text(
                  _shortDate(booking.date),
                  style: _text(
                    scale,
                    12,
                    color: pending ? Colors.white : KickoffColors.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pitch ${booking.pitchName ?? '?'} · ${booking.pitchSize ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(scale, 15, weight: FontWeight.w600),
                ),
                Text(
                  '${booking.stadiumName ?? ''} · ${booking.hostName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text(
                    scale,
                    13,
                    color: pending ? Colors.white : KickoffColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (!pending)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8 * scale),
              child: Icon(
                Icons.check_rounded,
                color: KickoffColors.yellow,
                size: 24 * scale,
              ),
            )
          else if (busy)
            Padding(
              padding: EdgeInsets.all(14 * scale),
              child: SizedBox(
                width: 20 * scale,
                height: 20 * scale,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else ...[
            _CircleAction(
              icon: Icons.close_rounded,
              label: 'Decline booking',
              color: KickoffColors.red,
              foreground: Colors.white,
              onTap: onDecline,
            ),
            _CircleAction(
              icon: Icons.check_rounded,
              label: 'Accept booking',
              color: KickoffColors.yellow,
              foreground: KickoffColors.ink,
              onTap: onAccept,
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared building blocks
// ===========================================================================

TextStyle _text(
  double scale,
  double size, {
  Color color = Colors.white,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(color: color, fontSize: size * scale, fontWeight: weight);

ShapeBorder _sheetShape(BuildContext context) => RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(
    top: Radius.circular(22 * kickoffScale(context)),
  ),
);

void _toast(BuildContext context, String message, {bool error = false}) {
  final scale = kickoffScale(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        // Float above the chunky bottom button instead of covering it.
        margin: EdgeInsets.fromLTRB(16 * scale, 0, 16 * scale, 84 * scale),
        backgroundColor: error
            ? KickoffColors.redDark
            : KickoffColors.panelDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        content: Text(message, style: _text(scale, 15)),
      ),
    );
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.child,
    this.icon,
    this.actions = const [],
    this.bottom,
    this.header,
    this.onBack,
  });

  final String title;
  final IconData? icon;
  final List<Widget> actions;
  final Widget child;
  final Widget? bottom;
  final Widget? header;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Scaffold(
      backgroundColor: KickoffColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                4 * scale,
                4 * scale,
                8 * scale,
                4 * scale,
              ),
              child: Row(
                children: [
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  if (icon != null) ...[
                    Icon(icon, color: KickoffColors.yellow, size: 26 * scale),
                    SizedBox(width: 8 * scale),
                  ] else
                    SizedBox(width: 4 * scale),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _text(scale, 21, weight: FontWeight.w600),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            ?header,
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16 * scale,
                  8 * scale,
                  16 * scale,
                  12 * scale,
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class _ChunkyTile extends StatelessWidget {
  const _ChunkyTile({
    required this.color,
    required this.edge,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.radius = 18,
    this.edgeWidth = 4,
    this.semanticLabel,
  });

  final Color color;
  final Color edge;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double radius;
  final double edgeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final shape = BorderRadius.circular(radius * scale);
    final tile = Material(
      color: color,
      borderRadius: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 48 * scale),
          padding: padding,
          decoration: BoxDecoration(
            border: edgeWidth == 0
                ? null
                : Border(
                    bottom: BorderSide(color: edge, width: edgeWidth * scale),
                  ),
          ),
          child: child,
        ),
      ),
    );
    if (semanticLabel == null) return tile;
    return Semantics(button: onTap != null, label: semanticLabel, child: tile);
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({
    required this.color,
    this.icon,
    this.letter,
    this.foreground = Colors.white,
  });

  final Color color;
  final IconData? icon;
  final String? letter;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      width: 48 * scale,
      height: 48 * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14 * scale),
        border: Border(
          bottom: BorderSide(
            color: color == _C.green ? _C.greenDark : Colors.transparent,
            width: 3 * scale,
          ),
        ),
      ),
      child: letter != null
          ? Text(letter!, style: _text(scale, 20, weight: FontWeight.w600))
          : Icon(icon, color: foreground, size: 26 * scale),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({
    required this.icon,
    required this.text,
    required this.color,
    this.textColor = Colors.white,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16 * scale),
        SizedBox(width: 4 * scale),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(scale, 14, color: textColor),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 12 * scale,
          horizontal: 8 * scale,
        ),
        decoration: BoxDecoration(
          color: KickoffColors.panel,
          borderRadius: BorderRadius.circular(16 * scale),
        ),
        child: Column(
          children: [
            Icon(icon, color: KickoffColors.yellow, size: 24 * scale),
            SizedBox(height: 4 * scale),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: _text(scale, 24, weight: FontWeight.w600),
              ),
            ),
            Text(label, style: _text(scale, 13, color: KickoffColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.all(12 * scale),
      decoration: BoxDecoration(
        color: KickoffColors.panel,
        borderRadius: BorderRadius.circular(18 * scale),
      ),
      child: child,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.text,
    this.error = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final bool error;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12 * scale,
        vertical: 8 * scale,
      ),
      constraints: BoxConstraints(minHeight: 48 * scale),
      decoration: BoxDecoration(
        color: error ? KickoffColors.redDark : KickoffColors.panelDark,
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: error ? Colors.white : KickoffColors.yellow,
            size: 20 * scale,
          ),
          SizedBox(width: 8 * scale),
          Expanded(child: Text(text, style: _text(scale, 14))),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: Size(48 * scale, 48 * scale),
              ),
              child: Text(
                actionLabel!,
                style: _text(
                  scale,
                  14,
                  color: KickoffColors.yellow,
                  weight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: KickoffColors.yellow),
  );
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.refresh_rounded,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final IconData actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 24 * scale,
        vertical: 16 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80 * scale,
            height: 80 * scale,
            decoration: const BoxDecoration(
              color: KickoffColors.panel,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: KickoffColors.yellow, size: 38 * scale),
          ),
          SizedBox(height: 14 * scale),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _text(scale, 19, weight: FontWeight.w600),
          ),
          if (message.isNotEmpty) ...[
            SizedBox(height: 6 * scale),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _text(scale, 15, color: KickoffColors.muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 18 * scale),
            ChunkyButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
    if (compact) return content;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: content),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      label: 'Step ${step + 1} of $total',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) SizedBox(width: 6 * scale),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 7 * scale,
                decoration: BoxDecoration(
                  color: index <= step
                      ? KickoffColors.yellow
                      : KickoffColors.panel,
                  borderRadius: BorderRadius.circular(4 * scale),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _text(scale, 18, weight: FontWeight.w600)),
        if (subtitle != null)
          Text(subtitle!, style: _text(scale, 14, color: KickoffColors.muted)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale, left: 4 * scale),
      child: Text(
        text,
        style: _text(
          scale,
          14,
          color: KickoffColors.muted,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final fg = selected ? KickoffColors.ink : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        borderRadius: BorderRadius.circular(24 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24 * scale),
          child: Container(
            constraints: BoxConstraints(
              minHeight: 48 * scale,
              minWidth: 56 * scale,
            ),
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18 * scale, color: fg),
                  SizedBox(width: 6 * scale),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: _text(scale, 15, color: fg, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final fg = selected ? KickoffColors.ink : KickoffColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: _ChunkyTile(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        edge: selected ? KickoffColors.yellowDark : KickoffColors.panelDark,
        onTap: onTap,
        radius: 16,
        padding: EdgeInsets.symmetric(
          vertical: 10 * scale,
          horizontal: 2 * scale,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 24 * scale),
            SizedBox(height: 4 * scale),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: _text(scale, 13, color: fg, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.letter,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name ${selected ? 'open' : 'closed'}',
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: selected ? KickoffColors.yellow : KickoffColors.panel,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Center(
              child: Text(
                letter,
                style: _text(
                  scale,
                  16,
                  color: selected ? KickoffColors.ink : KickoffColors.muted,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      label: '$label at $value',
      excludeSemantics: true,
      child: Material(
        color: KickoffColors.field,
        borderRadius: BorderRadius.circular(28 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28 * scale),
          child: Container(
            constraints: BoxConstraints(minHeight: 56 * scale),
            padding: EdgeInsets.symmetric(horizontal: 14 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: KickoffColors.yellow,
                  size: 20 * scale,
                ),
                SizedBox(width: 8 * scale),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: _text(scale, 17, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.small = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    final size = (small ? 40 : 52) * scale;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28 * scale,
        child: SizedBox(
          width: 48 * scale,
          height: 48 * scale,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: enabled ? KickoffColors.yellow : KickoffColors.field,
                shape: BoxShape.circle,
                border: Border(
                  bottom: BorderSide(
                    color: enabled
                        ? KickoffColors.yellowDark
                        : Colors.transparent,
                    width: 3 * scale,
                  ),
                ),
              ),
              child: Icon(
                icon,
                color: enabled ? KickoffColors.ink : KickoffColors.dim,
                size: (small ? 20 : 26) * scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 26 * scale,
          child: SizedBox(
            width: 48 * scale,
            height: 48 * scale,
            child: Center(
              child: Container(
                width: 40 * scale,
                height: 40 * scale,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: foreground, size: 24 * scale),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({
    required this.letter,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? KickoffColors.yellow : KickoffColors.panel,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48 * scale,
            height: 48 * scale,
            child: Center(
              child: Text(
                letter,
                style: _text(
                  scale,
                  17,
                  color: selected ? KickoffColors.ink : Colors.white,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeButton extends StatelessWidget {
  const _BadgeButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RoundIconButton(
          icon: icon,
          label: count > 0 ? '$label, $count waiting' : label,
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: 4 * scale,
            top: 4 * scale,
            child: IgnorePointer(
              child: Container(
                constraints: BoxConstraints(minWidth: 20 * scale),
                height: 20 * scale,
                padding: EdgeInsets.symmetric(horizontal: 5 * scale),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: KickoffColors.red,
                  borderRadius: BorderRadius.circular(10 * scale),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: _text(scale, 12, weight: FontWeight.w600),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _KickoffSwitch extends StatelessWidget {
  const _KickoffSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KickoffColors.ink
            : KickoffColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? KickoffColors.yellow
            : KickoffColors.field,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

class _DashedAdd extends StatelessWidget {
  const _DashedAdd({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * scale),
        child: CustomPaint(
          painter: _DashedBorderPainter(radius: 18 * scale, scale: scale),
          child: SizedBox(
            height: 64 * scale,
            child: Center(
              child: Icon(
                Icons.add_rounded,
                color: KickoffColors.muted,
                size: 30 * scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius, required this.scale});

  final double radius;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KickoffColors.dim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(scale),
      );
    final dash = 7 * scale;
    final gap = 5 * scale;
    for (final metric in path.computeMetrics()) {
      for (
        var distance = 0.0;
        distance < metric.length;
        distance += dash + gap
      ) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.scale != scale;
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.children,
    this.maxHeightFactor = 0.85,
  });

  final String title;
  final List<Widget> children;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16 * scale,
            10 * scale,
            16 * scale,
            12 * scale,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40 * scale,
                  height: 5 * scale,
                  decoration: BoxDecoration(
                    color: KickoffColors.field,
                    borderRadius: BorderRadius.circular(3 * scale),
                  ),
                ),
              ),
              SizedBox(height: 14 * scale),
              Text(title, style: _text(scale, 19, weight: FontWeight.w600)),
              SizedBox(height: 14 * scale),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: _ChunkyTile(
        color: KickoffColors.panel,
        edge: KickoffColors.panel,
        edgeWidth: 0,
        radius: 16,
        onTap: onTap,
        semanticLabel: label,
        padding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 14 * scale,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: color == Colors.white ? KickoffColors.yellow : color,
              size: 22 * scale,
            ),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Text(
                label,
                style: _text(scale, 16, color: color, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: Size.fromHeight(48 * scale)),
      icon: Icon(icon, color: color, size: 20 * scale),
      label: Text(
        label,
        style: _text(scale, 15, color: color, weight: FontWeight.w600),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = kickoffScale(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      child: Row(
        children: [
          Icon(icon, color: KickoffColors.yellow, size: 20 * scale),
          SizedBox(width: 12 * scale),
          Expanded(child: Text(text, style: _text(scale, 16))),
        ],
      ),
    );
  }
}
