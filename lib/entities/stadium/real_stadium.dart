/// One player's review of a stadium.
class StadiumReview {
  const StadiumReview({
    required this.userName,
    required this.stars,
    required this.comment,
    required this.mine,
  });

  final String userName;
  final int stars;
  final String comment;

  /// Written by the signed-in player.
  final bool mine;
}

class StadiumReviewSet {
  const StadiumReviewSet({
    required this.rating,
    required this.count,
    required this.canReview,
    required this.reviews,
  });

  factory StadiumReviewSet.fromJson(Map<String, dynamic> json) =>
      StadiumReviewSet(
        rating: (json['rating'] as num?)?.toDouble(),
        count: json['count'] as int? ?? 0,
        canReview: json['canReview'] as bool? ?? false,
        reviews: [
          for (final item in json['reviews'] as List<dynamic>? ?? const [])
            StadiumReview(
              userName: (item as Map<String, dynamic>)['userName'] as String,
              stars: item['stars'] as int,
              comment: item['comment'] as String? ?? '',
              mine: item['mine'] as bool? ?? false,
            ),
        ],
      );

  /// Average stars, null before the first review.
  final double? rating;
  final int count;

  /// The player booked this stadium, so they may write a review.
  final bool canReview;
  final List<StadiumReview> reviews;
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
    this.rating,
    this.reviewCount = 0,
  });

  factory RealStadium.fromJson(Map<String, dynamic> json) => RealStadium(
    id: json['id'] as int,
    name: json['name'] as String,
    address: json['address'] as String? ?? '',
    pricePerHour: json['pricePerHour'] as int? ?? 0,
    rating: (json['rating'] as num?)?.toDouble(),
    reviewCount: json['reviewCount'] as int? ?? 0,
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

  /// Average stars, null before the first review.
  final double? rating;
  final int reviewCount;

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
