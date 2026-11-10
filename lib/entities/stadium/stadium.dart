const stadiumPitchSizes = ['5v5', '7v7', '11v11'];

const stadiumSurfaces = <String, String>{
  'turf': 'Turf',
  'grass': 'Grass',
  'indoor': 'Indoor',
};

const stadiumFeatures = <String, String>{
  'lights': 'Lights',
  'showers': 'Showers',
  'parking': 'Parking',
  'cafe': 'Café',
};

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

  String get surfaceLabel => stadiumSurfaces[surface] ?? surface;

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

String stadiumDay(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String stadiumTime(int minutes) {
  final value = minutes % (24 * 60);
  return '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';
}
