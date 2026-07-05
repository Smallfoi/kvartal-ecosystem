import 'package:flutter_test/flutter_test.dart';
import 'package:sport_store/providers/remote_content_provider.dart';

void main() {
  group('RemoteContentProvider', () {
    test('text() возвращает фолбэк, когда контента нет', () {
      final p = RemoteContentProvider(null); // api null → без загрузки
      expect(p.text('app.home.title', 'SPORT STORE'), 'SPORT STORE');
      expect(p.text('app.cat.tshirts', 'Футболки'), 'Футболки');
    });

    test('applyDraft задаёт значение; пустое — снимает (→ фолбэк)', () {
      final p = RemoteContentProvider(null);
      p.applyDraft('app.home.catTitle', 'РАЗДЕЛЫ');
      expect(p.text('app.home.catTitle', 'КАТЕГОРИИ'), 'РАЗДЕЛЫ');
      p.applyDraft('app.home.catTitle', ''); // пусто = вернуть фолбэк
      expect(p.text('app.home.catTitle', 'КАТЕГОРИИ'), 'КАТЕГОРИИ');
    });

    test('applyDraft уведомляет слушателей', () {
      final p = RemoteContentProvider(null);
      var notified = 0;
      p.addListener(() => notified++);
      p.applyDraft('app.x', 'значение');
      expect(notified, 1);
    });
  });
}
