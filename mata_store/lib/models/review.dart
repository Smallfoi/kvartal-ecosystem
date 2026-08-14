/// Отзыв на товар (общий бэкенд: GET/POST /v1/products/{id}/reviews).
class Review {
  final String id;
  final String userId;
  final String name;
  final int rating; // 1..5
  final String text;
  final String createdAt;
  final bool mine;
  final List<String> photos; // URL фото (/media/...), до 5

  const Review({
    required this.id,
    required this.userId,
    required this.name,
    required this.rating,
    required this.text,
    required this.createdAt,
    this.mine = false,
    this.photos = const [],
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id']?.toString() ?? '',
        userId: j['userId']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Покупатель',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        text: j['text']?.toString() ?? '',
        createdAt: j['createdAt']?.toString() ?? '',
        mine: j['mine'] == true,
        photos: (j['photos'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Сводка отзывов товара: средний рейтинг, число, список и права текущего юзера.
class ProductReviews {
  final double rating;
  final int reviewCount;
  final List<Review> reviews;
  final bool canReview; // купил → может оставить/изменить отзыв
  final bool hasMine;

  const ProductReviews({
    this.rating = 0,
    this.reviewCount = 0,
    this.reviews = const [],
    this.canReview = false,
    this.hasMine = false,
  });

  factory ProductReviews.fromJson(Map<String, dynamic> j) => ProductReviews(
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: (j['reviewCount'] as num?)?.toInt() ?? 0,
        reviews: (j['reviews'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Review.fromJson)
            .toList(),
        canReview: j['canReview'] == true,
        hasMine: j['hasMine'] == true,
      );
}
