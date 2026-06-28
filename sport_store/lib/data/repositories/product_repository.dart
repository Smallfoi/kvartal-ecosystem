import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/review.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../mock_data.dart';

/// Диапазон цен для фильтра.
class PriceRange {
  final double min;
  final double max;
  const PriceRange(this.min, this.max);
}

/// Контракт доступа к товарам и категориям.
///
/// Это «шов» для backend: экраны и провайдеры зависят только от этого
/// интерфейса. Сейчас используется [MockProductRepository], позже —
/// [ApiProductRepository] (переключается в `ApiConfig.useMock`).
abstract class ProductRepository {
  Future<List<Category>> getCategories();
  Future<List<Product>> getProducts();
  Future<List<Product>> getByCategory(String categoryId);
  Future<Product?> getById(String id);
  Future<List<Product>> getFeatured();
  Future<List<Product>> getNew();
  Future<List<Product>> search(String query);
  Future<List<String>> getBrands();
  Future<List<String>> getSizes();
  Future<PriceRange> getPriceRange();
  Future<List<Map<String, String>>> getBanners();

  /// Отзывы товара (+ можно ли оставить свой).
  Future<ProductReviews> getReviews(String productId);

  /// Оставить/обновить свой отзыв (только купившие — иначе бросает).
  Future<void> addReview(String productId,
      {required int rating, required String text, List<String> photos});

  /// Загрузить фото к отзыву → URL (/media/...).
  Future<String> uploadReviewPhoto(String filePath);
}

// ─── Mock-реализация (прототип, офлайн) ───────────────────────────────────────

class MockProductRepository implements ProductRepository {
  // Небольшая задержка имитирует сетевой запрос; для UI почти незаметна.
  static const _delay = Duration(milliseconds: 120);

  @override
  Future<List<Category>> getCategories() async {
    await Future.delayed(_delay);
    return MockData.categories;
  }

  @override
  Future<List<Product>> getProducts() async {
    await Future.delayed(_delay);
    return MockData.products;
  }

  @override
  Future<List<Product>> getByCategory(String categoryId) async {
    await Future.delayed(_delay);
    return MockData.getByCategory(categoryId);
  }

  @override
  Future<Product?> getById(String id) async {
    await Future.delayed(_delay);
    return MockData.getById(id);
  }

  @override
  Future<List<Product>> getFeatured() async {
    await Future.delayed(_delay);
    return MockData.getFeatured();
  }

  @override
  Future<List<Product>> getNew() async {
    await Future.delayed(_delay);
    return MockData.getNew();
  }

  @override
  Future<List<Product>> search(String query) async {
    await Future.delayed(_delay);
    return MockData.search(query);
  }

  @override
  Future<List<String>> getBrands() async => MockData.allBrands;

  @override
  Future<List<String>> getSizes() async => MockData.allSizes;

  @override
  Future<PriceRange> getPriceRange() async =>
      PriceRange(MockData.minPrice, MockData.maxPrice);

  @override
  Future<List<Map<String, String>>> getBanners() async {
    await Future.delayed(_delay);
    return MockData.banners;
  }

  @override
  Future<ProductReviews> getReviews(String productId) async =>
      const ProductReviews();

  @override
  Future<void> addReview(String productId,
      {required int rating,
      required String text,
      List<String> photos = const []}) async {}

  @override
  Future<String> uploadReviewPhoto(String filePath) async => '';
}

// ─── API-реализация (готова к подключению backend) ────────────────────────────
//
// Эндпоинты — пример; согласуются с backend/выгрузкой из 1С. Тело каждого
// метода уже реализовано через ApiClient — останется поднять API и переключить
// ApiConfig.useMock = false.

class ApiProductRepository implements ProductRepository {
  final ApiClient _client;
  ApiProductRepository(this._client);

  /// В превью-сборке (ApiConfig.preview) добавляем ?preview=1 — каталог отдаёт
  /// и черновики, чтобы видеть правки до публикации в админ-превью.
  Map<String, dynamic>? _q([Map<String, dynamic>? base]) {
    if (!ApiConfig.preview) return base;
    return {...?base, 'preview': '1'};
  }

  @override
  Future<List<Category>> getCategories() async {
    final data = await _client.get('/categories') as List;
    return data.map((j) => Category.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> getProducts() async {
    final data = await _client.get('/products', query: _q()) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> getByCategory(String categoryId) async {
    final data = await _client
        .get('/products', query: _q({'category': categoryId})) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Product?> getById(String id) async {
    final data = await _client.get('/products/$id', query: _q());
    if (data == null) return null;
    return Product.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Product>> getFeatured() async {
    final data =
        await _client.get('/products', query: _q({'featured': true})) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> getNew() async {
    final data = await _client.get('/products', query: _q({'new': true})) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> search(String query) async {
    final data =
        await _client.get('/products/search', query: _q({'q': query})) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<String>> getBrands() async {
    final data = await _client.get('/brands') as List;
    return data.map((e) => e.toString()).toList();
  }

  @override
  Future<List<String>> getSizes() async {
    final data = await _client.get('/sizes') as List;
    return data.map((e) => e.toString()).toList();
  }

  @override
  Future<PriceRange> getPriceRange() async {
    final data = await _client.get('/products/price-range') as Map;
    return PriceRange(
      (data['min'] as num).toDouble(),
      (data['max'] as num).toDouble(),
    );
  }

  @override
  Future<List<Map<String, String>>> getBanners() async {
    final data = await _client.get('/banners', query: _q()) as List;
    return data
        .map((j) => (j as Map).map((k, v) => MapEntry('$k', '$v')))
        .toList();
  }

  @override
  Future<ProductReviews> getReviews(String productId) async {
    final data = await _client.get('/products/$productId/reviews');
    return ProductReviews.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<void> addReview(String productId,
      {required int rating,
      required String text,
      List<String> photos = const []}) async {
    await _client.post(
      '/products/$productId/reviews',
      body: {'rating': rating, 'text': text, 'photos': photos},
    );
  }

  @override
  Future<String> uploadReviewPhoto(String filePath) async {
    final r = await _client.uploadImage('/reviews/photo', filePath);
    return (r is Map && r['url'] != null) ? r['url'].toString() : '';
  }
}
