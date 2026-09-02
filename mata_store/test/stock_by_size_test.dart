import 'package:flutter_test/flutter_test.dart';
import 'package:sport_store/models/product.dart';

/// Остаток по размерам приходит из 1С (D-62). Проверяем главное: размер без
/// остатка недоступен, а отсутствие разбивки НЕ должно прятать размеры —
/// иначе товар, заведённый руками, останется без единого размера.
void main() {
  Product build(Map<String, dynamic> extra) => Product.fromJson({
    'id': 'p1',
    'name': 'Кроссовки',
    'price': 11990,
    'sizes': ['40', '41', '42'],
    ...extra,
  });

  group('Product.stockBySize', () {
    test('разбирает остаток по размерам из ответа бэка', () {
      final p = build({
        'stockBySize': {'40': 3, '41': 0, '42': 7},
      });
      expect(p.stockBySize, {'40': 3, '41': 0, '42': 7});
    });

    test('размер с нулевым остатком недоступен', () {
      final p = build({
        'stockBySize': {'40': 3, '41': 0},
      });
      expect(p.hasSize('40'), isTrue);
      expect(p.hasSize('41'), isFalse);
    });

    test('без разбивки доступны все размеры', () {
      final p = build({});
      expect(p.stockBySize, isEmpty);
      for (final s in p.sizes) {
        expect(p.hasSize(s), isTrue, reason: 'размер $s не должен пропадать');
      }
    });

    test('размера нет в разбивке — считаем, что его нет на складе', () {
      final p = build({
        'stockBySize': {'40': 3},
      });
      expect(p.hasSize('42'), isFalse);
    });

    test('переживает мусор в ответе', () {
      final p = build({
        'stockBySize': {'40': null},
      });
      expect(p.hasSize('40'), isFalse);
    });
  });
}
