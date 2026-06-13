import '../../models/category.dart';
import '../../models/product.dart';
import '../api/api_client.dart';
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
}

// ─── API-реализация (готова к подключению backend) ────────────────────────────
//
// Эндпоинты — пример; согласуются с backend/выгрузкой из 1С. Тело каждого
// метода уже реализовано через ApiClient — останется поднять API и переключить
// ApiConfig.useMock = false.

class ApiProductRepository implements ProductRepository {
  final ApiClient _client;
  ApiProductRepository(this._client);

  @override
  Future<List<Category>> getCategories() async {
    final data = await _client.get('/categories') as List;
    return data.map((j) => Category.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> getProducts() async {
    final data = await _client.get('/products') as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> getByCategory(String categoryId) async {
    final data = await _client
        .get('/products', query: {'category': categoryId}) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<Product?> getById(String id) async {
    final data = await _client.get('/products/$id');
    if (data == null) return null;
    return Product.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<Product>> getFeatured() async {
    final data =
        await _client.get('/products', query: {'featured': true}) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> getNew() async {
    final data = await _client.get('/products', query: {'new': true}) as List;
    return data.map((j) => Product.fromJson(j as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<Product>> search(String query) async {
    final data =
        await _client.get('/products/search', query: {'q': query}) as List;
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
    final data = await _client.get('/banners') as List;
    return data
        .map((j) => (j as Map).map((k, v) => MapEntry('$k', '$v')))
        .toList();
  }
}
