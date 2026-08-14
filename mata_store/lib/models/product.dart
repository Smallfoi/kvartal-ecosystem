class Product {
  final String id;
  final String name;
  final String brand;
  final String categoryId;
  final double price;
  final double? oldPrice;
  final List<String> imageUrls;
  final String description;
  final List<String> sizes;
  final List<String> colors;
  final bool isNew;
  final bool isFeatured;
  final double rating;
  final int reviewCount;
  final bool inStock;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.categoryId,
    required this.price,
    this.oldPrice,
    required this.imageUrls,
    required this.description,
    required this.sizes,
    required this.colors,
    this.isNew = false,
    this.isFeatured = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.inStock = true,
  });

  bool get isOnSale => oldPrice != null && oldPrice! > price;

  /// Первое фото или '' (безопасно при пустом списке — напр. данные из API).
  String get firstImage => imageUrls.isNotEmpty ? imageUrls.first : '';

  int get discountPercent {
    if (!isOnSale) return 0;
    return (((oldPrice! - price) / oldPrice!) * 100).round();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'categoryId': categoryId,
        'price': price,
        'oldPrice': oldPrice,
        'imageUrls': imageUrls,
        'description': description,
        'sizes': sizes,
        'colors': colors,
        'isNew': isNew,
        'isFeatured': isFeatured,
        'rating': rating,
        'reviewCount': reviewCount,
        'inStock': inStock,
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'].toString(),
        name: j['name'] as String,
        brand: j['brand'] as String? ?? '',
        categoryId: j['categoryId'] as String? ?? '',
        price: (j['price'] as num).toDouble(),
        oldPrice: j['oldPrice'] == null ? null : (j['oldPrice'] as num).toDouble(),
        imageUrls: (j['imageUrls'] as List? ?? const []).map((e) => e.toString()).toList(),
        description: j['description'] as String? ?? '',
        sizes: (j['sizes'] as List? ?? const []).map((e) => e.toString()).toList(),
        colors: (j['colors'] as List? ?? const []).map((e) => e.toString()).toList(),
        isNew: j['isNew'] as bool? ?? false,
        isFeatured: j['isFeatured'] as bool? ?? false,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: j['reviewCount'] as int? ?? 0,
        inStock: j['inStock'] as bool? ?? true,
      );
}
