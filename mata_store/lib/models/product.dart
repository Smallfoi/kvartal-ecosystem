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

  /// Остаток по размерам из 1С: {'41': 0, '42': 7}. Пусто — разбивки нет, и тогда
  /// доступны все размеры (товар заведён руками либо 1С прислала общий остаток).
  final Map<String, int> stockBySize;

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
    this.stockBySize = const {},
  });

  bool get isOnSale => oldPrice != null && oldPrice! > price;

  /// Можно ли купить этот размер. Нет разбивки — считаем, что можно: лучше
  /// показать размер и упереться в отказ при заказе, чем спрятать имеющийся.
  bool hasSize(String size) =>
      stockBySize.isEmpty || (stockBySize[size] ?? 0) > 0;

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
        'stockBySize': stockBySize,
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
        stockBySize: ((j['stockBySize'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        ),
      );
}
